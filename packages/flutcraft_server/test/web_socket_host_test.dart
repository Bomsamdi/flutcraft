import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_protocol/flutcraft_protocol.dart';
import 'package:flutcraft_server/flutcraft_server.dart';
import 'package:test/test.dart';

const codec = JsonMessageCodec();

/// A client made of a real socket, so the test exercises the whole path.
class TestClient {
  TestClient(this.socket, this.received);

  static Future<TestClient> connect(int port, PlayerId who) async {
    final socket = await WebSocket.connect('ws://127.0.0.1:$port');
    final received = <ServerMessage>[];
    socket.listen((raw) {
      received.add(codec.decodeServer(_bytes(raw)));
    });
    socket.add(codec.encodeClient(Hello(who)));
    return TestClient(socket, received);
  }

  static Uint8List _bytes(Object? raw) => switch (raw) {
    final Uint8List bytes => bytes,
    final List<int> bytes => Uint8List.fromList(bytes),
    _ => utf8.encode(raw! as String),
  };

  final WebSocket socket;
  final List<ServerMessage> received;

  void send(ClientMessage message) => socket.add(codec.encodeClient(message));

  T? last<T extends ServerMessage>() => received.whereType<T>().lastOrNull;

  Future<void> close() => socket.close();
}

/// Waits until [until] holds, or gives up. Real sockets are asynchronous, so
/// a test either waits for a condition or is flaky.
Future<bool> eventually(bool Function() until, {int tries = 200}) async {
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
    host = GameHost.newWorld(seed: 7);
    server = WebSocketHost(host);
    // Port 0 asks the operating system for a free one, so the test does not
    // fight anything else on the machine.
    await server.start(port: 0);
  });

  tearDown(() => server.stop());

  test('a client is welcomed with the world it joined', () async {
    final alice = await TestClient.connect(server.port, const PlayerId('a'));

    await eventually(() => alice.last<Welcome>() != null);

    expect(alice.last<Welcome>()!.world.seed, 7);
    await alice.close();
  });

  test('two clients in one world see each other move', () async {
    final alice = await TestClient.connect(server.port, const PlayerId('a'));
    final bob = await TestClient.connect(server.port, const PlayerId('b'));
    await eventually(() => bob.last<Welcome>() != null);

    // Alice walks for a while, a frame at a time, as a real client does.
    final walking = Timer.periodic(const Duration(milliseconds: 16), (t) {
      alice.send(
        InputTick(
          t.tick,
          const InputFrame(forward: 1, held: {GameAction.moveForward}),
        ),
      );
    });

    final moved = await eventually(() {
      final states = bob.last<PlayerStates>();
      final her = states?.players
          .where((p) => p.id == const PlayerId('a'))
          .firstOrNull;
      return her != null && her.position.length > 0.5;
    });
    walking.cancel();

    expect(moved, isTrue, reason: 'Bob never saw Alice move');
    await alice.close();
    await bob.close();
  });

  test('a disconnect takes the player out of the world', () async {
    final alice = await TestClient.connect(server.port, const PlayerId('a'));
    await eventually(() => host.players.isNotEmpty);

    await alice.close();

    expect(await eventually(() => host.players.isEmpty), isTrue);
  });

  test('the world keeps running with nobody connected', () async {
    final before = host.tick;

    expect(
      await eventually(() => host.tick > before + 30),
      isTrue,
      reason: 'the loop stopped when the last client left',
    );
  });

  test('a command sent over the wire reaches the simulation', () async {
    final alice = await TestClient.connect(server.port, const PlayerId('a'));
    await eventually(() => host.players.isNotEmpty);

    alice.send(const Command(ToggleFlight()));

    expect(
      await eventually(
        () =>
            host.state.participants[const PlayerId('a')]?.player.flying ??
            false,
      ),
      isTrue,
    );
    await alice.close();
  });
}
