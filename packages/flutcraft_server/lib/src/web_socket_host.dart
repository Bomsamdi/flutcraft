import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_protocol/flutcraft_protocol.dart';

import 'accounts.dart';
import 'client_link.dart';
import 'game_host.dart';
import 'outbound_queue.dart';

/// The only part of the server that knows what a socket is.
///
/// Everything else takes a [ClientLink]; this turns one into a WebSocket.
class WebSocketLink implements ClientLink {
  WebSocketLink(this.socket, this.codec, {OutboundQueue? queue})
    : queue = queue ?? OutboundQueue();

  final WebSocket socket;
  final MessageCodec codec;
  final OutboundQueue queue;

  bool _closed = false;

  @override
  void send(ServerMessage message) {
    if (_closed) return;
    queue.add(message);

    if (queue.overflowed) {
      // Six kilobytes a second is not something to fall behind on; a client
      // that has, is gone rather than quietly eating the server's memory.
      socket.add(codec.encodeServer(const Kick(KickReason.tooSlow)));
      close();
      return;
    }

    for (final pending in queue.drain()) {
      socket.add(codec.encodeServer(pending));
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(socket.close());
  }
}

/// Runs a [GameHost] over WebSockets.
class WebSocketHost {
  WebSocketHost(
    this.host, {
    AccountStore? accounts,
    this.codec = const JsonMessageCodec(),
  }) : accounts = accounts ?? AccountStore.inMemory();

  final GameHost host;

  /// Who is allowed in.
  ///
  /// It lives here and not in [GameHost] on purpose: the game knows about
  /// players, not about passwords. Everything below this line is a world with
  /// people in it, and it would run exactly the same if the way in were a
  /// guest list on the door.
  final AccountStore accounts;

  final MessageCodec codec;

  /// How often a silent connection is prodded.
  ///
  /// Without this a dead TCP connection keeps a participant in the world for
  /// ever, and every zombie in it goes on chasing a ghost.
  static const Duration heartbeat = Duration(seconds: 10);

  HttpServer? _server;
  Timer? _ticker;

  /// The port actually bound. Useful when asking for port 0 in a test.
  int get port => _server?.port ?? 0;

  /// Binds, and starts running the world.
  Future<void> start({Object address = '127.0.0.1', int port = 8787}) async {
    final server = await HttpServer.bind(address, port);
    _server = server;

    var last = DateTime.now();
    _ticker = Timer.periodic(const Duration(milliseconds: 8), (_) {
      final now = DateTime.now();
      final dt = now.difference(last).inMicroseconds / 1e6;
      last = now;
      host.advance(dt);
    });

    unawaited(_accept(server));
  }

  Future<void> _accept(HttpServer server) async {
    await for (final request in server) {
      unawaited(_handle(request));
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    socket.pingInterval = heartbeat;

    PlayerId? who;
    var admitting = false;
    late final StreamSubscription<Object?> connection;
    connection = socket.listen(
      (raw) {
        final message = codec.decodeClient(_bytes(raw));
        if (who == null) {
          if (admitting) return;
          admitting = true;
          // Checking a secret is slow on purpose and happens elsewhere, so
          // the answer arrives later. Pausing holds everything this client
          // sends in the meantime rather than letting it reach a world it
          // has not been admitted to yet; the buffer empties on resume.
          connection.pause();
          _admit(socket, message).then((id) {
            who = id;
            admitting = false;
            connection.resume();
          });
          return;
        }
        final id = who;
        if (id != null) host.receive(id, message);
      },
      onDone: () {
        final id = who;
        if (id != null) host.leave(id);
      },
      onError: (Object _) {
        final id = who;
        if (id != null) host.leave(id);
      },
      cancelOnError: true,
    );
  }

  /// Decides whether a connection gets to play, and lets it in if it does.
  ///
  /// Returns who the connection is, or null when it was refused — and a
  /// refusal closes the socket. Nothing before this point is allowed to touch
  /// the world: a client that has not signed in can send a thousand messages
  /// and every one of them lands here.
  Future<PlayerId?> _admit(WebSocket socket, ClientMessage message) async {
    void refuse(KickReason reason) {
      socket.add(codec.encodeServer(Kick(reason)));
      unawaited(socket.close());
    }

    switch (message) {
      case SignUp(:final name, :final secret):
        final problem = await accounts.register(name, secret);
        if (problem != null) {
          refuse(problem);
          return null;
        }
      case SignIn(:final name, :final secret):
        if (await accounts.verify(name, secret) == null) {
          refuse(KickReason.badCredentials);
          return null;
        }
      default:
        // Input before a sign-in is either a confused client or somebody
        // trying the world without asking. Neither gets a tick.
        refuse(KickReason.notSignedIn);
        return null;
    }

    final name = switch (message) {
      SignUp(:final name) => name,
      SignIn(:final name) => name,
      _ => '',
    };
    final id = PlayerId(name);
    host.join(id, WebSocketLink(socket, codec));
    return id;
  }

  /// A frame arrives as bytes or as text, depending on how the other end
  /// sent it; the codec only reads bytes.
  Uint8List _bytes(Object? raw) => switch (raw) {
    final Uint8List bytes => bytes,
    final List<int> bytes => Uint8List.fromList(bytes),
    _ => utf8.encode(raw! as String),
  };

  /// Stops ticking and closes the port.
  Future<void> stop() async {
    _ticker?.cancel();
    await _server?.close(force: true);
    _server = null;
  }
}
