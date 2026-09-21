import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_protocol/flutcraft_protocol.dart';

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
  WebSocketHost(this.host, {this.codec = const JsonMessageCodec()});

  final GameHost host;
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
    socket.listen(
      (raw) {
        final message = codec.decodeClient(_bytes(raw));
        if (message is Hello) {
          who = message.player;
          host.join(message.player, WebSocketLink(socket, codec));
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
