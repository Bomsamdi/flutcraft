import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_protocol/flutcraft_protocol.dart';
import 'package:flutcraft_server/flutcraft_server.dart';
import 'package:test/test.dart';

/// A real socket behind the client's channel.
///
/// This adapter is the only thing between `RemoteGameSession` and the wire,
/// and the app's own is the same twenty lines. Keeping it here as well means
/// the end-to-end test exercises the whole path without the app in it.
class SocketChannel implements MessageChannel {
  SocketChannel(this.socket, {this.codec = const JsonMessageCodec()}) {
    socket.listen(
      (raw) => _incoming.add(codec.decodeServer(_bytes(raw))),
      onDone: _incoming.close,
    );
  }

  static Future<SocketChannel> connect(int port) async =>
      SocketChannel(await WebSocket.connect('ws://127.0.0.1:$port'));

  static Uint8List _bytes(Object? raw) => switch (raw) {
    final Uint8List bytes => bytes,
    final List<int> bytes => Uint8List.fromList(bytes),
    _ => utf8.encode(raw! as String),
  };

  final WebSocket socket;
  final MessageCodec codec;
  final _incoming = StreamController<ServerMessage>.broadcast();

  @override
  Stream<ServerMessage> get incoming => _incoming.stream;

  @override
  void send(ClientMessage message) => socket.add(codec.encodeClient(message));

  @override
  Future<void> close() async {
    await socket.close();
    if (!_incoming.isClosed) await _incoming.close();
  }
}

Future<bool> eventually(bool Function() until, {int tries = 300}) async {
  for (var i = 0; i < tries; i++) {
    if (until()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return until();
}

void main() {
  late GameHost host;
  late WebSocketHost server;

  setUp(() async {
    host = GameHost.newWorld(seed: 4242);
    server = WebSocketHost(host);
    await server.start(port: 0);
  });

  tearDown(() => server.stop());

  test('a client joins a real server and gets its world', () async {
    final session = await RemoteGameSession.join(
      await SocketChannel.connect(server.port),
      const PlayerId('alice'),
    );
    addTearDown(session.close);

    expect(session.state.world.seed, 4242);
    expect(session.viewerId, const PlayerId('alice'));
  });

  test('two clients see each other, each through its own session', () async {
    final alice = await RemoteGameSession.join(
      await SocketChannel.connect(server.port),
      const PlayerId('alice'),
    );
    final bob = await RemoteGameSession.join(
      await SocketChannel.connect(server.port),
      const PlayerId('bob'),
    );
    addTearDown(alice.close);
    addTearDown(bob.close);

    // Alice walks, driving her session exactly as the engine would.
    final frames = Timer.periodic(const Duration(milliseconds: 16), (_) {
      alice.tick(
        1 / 60,
        const InputFrame(forward: 1, held: {GameAction.moveForward}),
      );
      bob.tick(1 / 60, InputFrame.idle);
    });
    addTearDown(frames.cancel);

    final sawHer = await eventually(() {
      final her = bob.state.participants[const PlayerId('alice')];
      return her != null && her.player.position.length > 0.5;
    });

    expect(sawHer, isTrue, reason: "Bob's world never showed Alice moving");
  });

  test('a prediction survives the round trip it agrees with', () async {
    final alice = await RemoteGameSession.join(
      await SocketChannel.connect(server.port),
      const PlayerId('alice'),
    );
    addTearDown(alice.close);

    // Stand somewhere known and put a block down through the real server.
    final where = alice.viewer.player.position;
    final at = BlockPos(where.x.floor(), where.y.floor() + 3, where.z.floor());
    host.state.world.setBlock(at.x, at.y, at.z, BlockType.planks);

    final arrived = await eventually(
      () => alice.state.world.blockAt(at.x, at.y, at.z) == BlockType.planks,
    );

    expect(arrived, isTrue);
  });

  test('the client stays close to where the server thinks it is', () async {
    final alice = await RemoteGameSession.join(
      await SocketChannel.connect(server.port),
      const PlayerId('alice'),
    );
    addTearDown(alice.close);

    final frames = Timer.periodic(const Duration(milliseconds: 16), (_) {
      alice.tick(
        1 / 60,
        const InputFrame(forward: 1, held: {GameAction.moveForward}),
      );
    });
    addTearDown(frames.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final asTheServerSees = host.state.participants[const PlayerId('alice')]!;
    final gap = alice.viewer.player.position.distanceTo(
      asTheServerSees.player.position,
    );

    // Prediction plus correction, over a loopback connection: the two should
    // be within a step of each other, not drifting apart.
    expect(gap, lessThan(0.5), reason: 'client and server disagree by $gap');
  });
}
