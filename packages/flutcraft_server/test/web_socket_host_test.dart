import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_protocol/flutcraft_protocol.dart';
import 'package:flutcraft_server/flutcraft_server.dart';
import 'package:test/test.dart';

const codec = JsonMessageCodec();

/// A frame arrives as bytes or as text; the codec only reads bytes.
Uint8List bytesOf(Object? raw) => switch (raw) {
  final Uint8List bytes => bytes,
  final List<int> bytes => Uint8List.fromList(bytes),
  _ => utf8.encode(raw! as String),
};

/// A client made of a real socket, so the test exercises the whole path.
class TestClient {
  TestClient(this.socket, this.received);

  static Future<TestClient> connect(int port, PlayerId who) async {
    final socket = await WebSocket.connect('ws://127.0.0.1:$port');
    final received = <ServerMessage>[];
    socket.listen((raw) {
      received.add(codec.decodeServer(bytesOf(raw)));
    });
    socket.add(codec.encodeClient(SignUp(who.value, 'open sesame')));
    return TestClient(socket, received);
  }

  static Uint8List _bytes(Object? raw) => bytesOf(raw);
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
    // A real cost factor would put a second and a half on every sign-in
    // in this file. What is under test here is the handshake, not the hash.
    server = WebSocketHost(host, accounts: AccountStore.inMemory(rounds: 500));
    // Port 0 asks the operating system for a free one, so the test does not
    // fight anything else on the machine.
    await server.start(port: 0);
  });

  tearDown(() => server.stop());

  group('The door', () {
    /// Connects without signing up, so the test can choose what to say first.
    Future<TestClient> knock() async {
      final socket = await WebSocket.connect('ws://127.0.0.1:${server.port}');
      final received = <ServerMessage>[];
      socket.listen((raw) => received.add(codec.decodeServer(bytesOf(raw))));
      return TestClient(socket, received);
    }

    test('the wrong secret does not get in', () async {
      final alice = await TestClient.connect(
        server.port,
        const PlayerId('alice'),
      );
      await eventually(() => alice.last<Welcome>() != null);
      await alice.close();

      final impostor = await knock();
      impostor.send(const SignIn('alice', 'not open sesame'));

      await eventually(() => impostor.last<Kick>() != null);
      expect(impostor.last<Kick>()!.reason, KickReason.badCredentials);
      expect(impostor.last<Welcome>(), isNull);
      await impostor.close();
    });

    test('input before a sign-in never reaches the world', () async {
      final stranger = await knock();

      stranger.send(
        const InputTick(
          1,
          InputFrame(forward: 1, held: {GameAction.moveForward}),
        ),
      );

      await eventually(() => stranger.last<Kick>() != null);
      expect(stranger.last<Kick>()!.reason, KickReason.notSignedIn);
      expect(host.players, isEmpty);
      await stranger.close();
    });

    test('a name somebody registered cannot be registered again', () async {
      final alice = await TestClient.connect(
        server.port,
        const PlayerId('alice'),
      );
      await eventually(() => alice.last<Welcome>() != null);

      final impostor = await knock();
      impostor.send(const SignUp('alice', 'my own secret'));

      await eventually(() => impostor.last<Kick>() != null);
      expect(impostor.last<Kick>()!.reason, KickReason.nameTaken);
      await alice.close();
      await impostor.close();
    });

    test('what a client sends while being checked is not lost', () async {
      // Checking a secret takes long enough that a client sends its first
      // frames before the answer comes back. Dropped, the player would
      // stand still for a moment on every sign-in.
      final alice = await knock();
      alice.send(const SignUp('alice', 'open sesame'));
      alice.send(const Command(ToggleFlight()));

      await eventually(
        () =>
            host.state.participants[const PlayerId('alice')]?.player.flying ??
            false,
      );

      expect(
        host.state.participants[const PlayerId('alice')]!.player.flying,
        isTrue,
      );
      await alice.close();
    });
  });

  test('a client is welcomed with the world it joined', () async {
    final alice = await TestClient.connect(
      server.port,
      const PlayerId('alice'),
    );

    await eventually(() => alice.last<Welcome>() != null);

    expect(alice.last<Welcome>()!.world.seed, 7);
    await alice.close();
  });

  test('two clients in one world see each other move', () async {
    final alice = await TestClient.connect(
      server.port,
      const PlayerId('alice'),
    );
    final bob = await TestClient.connect(server.port, const PlayerId('bob'));
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
          .where((p) => p.id == const PlayerId('alice'))
          .firstOrNull;
      return her != null && her.position.length > 0.5;
    });
    walking.cancel();

    expect(moved, isTrue, reason: 'Bob never saw Alice move');
    await alice.close();
    await bob.close();
  });

  test('a disconnect takes the player out of the world', () async {
    final alice = await TestClient.connect(
      server.port,
      const PlayerId('alice'),
    );
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
    final alice = await TestClient.connect(
      server.port,
      const PlayerId('alice'),
    );
    await eventually(() => host.players.isNotEmpty);

    alice.send(const Command(ToggleFlight()));

    expect(
      await eventually(
        () =>
            host.state.participants[const PlayerId('alice')]?.player.flying ??
            false,
      ),
      isTrue,
    );
    await alice.close();
  });
}
