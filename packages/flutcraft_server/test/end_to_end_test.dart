import 'dart:async';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_protocol/flutcraft_protocol.dart';
import 'package:flutcraft_server/flutcraft_server.dart';
import 'package:test/test.dart';

import 'socket_channel.dart';

/// Somebody signing up as they arrive.
///
/// The server has an empty account store, so every test player is new. That
/// this is the same call a real client makes is the point: the handshake is
/// not stubbed out for the tests.
Credentials newcomer(String name) =>
    Credentials.registering(name: name, secret: 'open sesame');

void main() {
  late GameHost host;
  late WebSocketHost server;

  setUp(() async {
    host = GameHost.newWorld(seed: 4242);
    server = WebSocketHost(host, accounts: AccountStore.inMemory(rounds: 500));
    await server.start(port: 0);
  });

  tearDown(() => server.stop());

  test('a client joins a real server and gets its world', () async {
    final session = await RemoteGameSession.join(
      await SocketChannel.connect(server.port),
      newcomer('alice'),
    );
    addTearDown(session.close);

    expect(session.state.world.seed, 4242);
    expect(session.viewerId, const PlayerId('alice'));
  });

  test('two clients see each other, each through its own session', () async {
    final alice = await RemoteGameSession.join(
      await SocketChannel.connect(server.port),
      newcomer('alice'),
    );
    final bob = await RemoteGameSession.join(
      await SocketChannel.connect(server.port),
      newcomer('bob'),
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

  test('the server knows which way a player is looking', () async {
    final alice = await RemoteGameSession.join(
      await SocketChannel.connect(server.port),
      newcomer('alice'),
    );
    addTearDown(alice.close);

    // Half a turn, spread over rendered frames the way a mouse delivers it.
    // A frame is worth one or more simulation steps, each of which the client
    // sends; how many of those the server sees together is up to the network.
    final frames = Timer.periodic(const Duration(milliseconds: 16), (_) {
      alice.tick(1 / 60, const InputFrame(lookYaw: 0.05));
    });
    addTearDown(frames.cancel);

    await eventually(() => alice.viewer.player.yaw > 3);
    frames.cancel();
    final turnedTo = alice.viewer.player.yaw;

    // Nothing corrects a client about where it is looking — that would fight
    // the mouse — so any turn the server misses is missed for good, and
    // everybody else draws this player facing somewhere she never looked.
    final agreed = await eventually(() {
      final asServerSees = host.state.participants[const PlayerId('alice')];
      return asServerSees != null &&
          (asServerSees.player.yaw - turnedTo).abs() < 0.05;
    });

    expect(
      agreed,
      isTrue,
      reason:
          'she turned to $turnedTo, the server has '
          '${host.state.participants[const PlayerId('alice')]?.player.yaw}',
    );
  });

  test('the server aims where the crosshair is, not a block away', () async {
    final alice = await RemoteGameSession.join(
      await SocketChannel.connect(server.port),
      newcomer('alice'),
    );
    addTearDown(alice.close);

    BlockPos? blockOf(AimResult aim) => aim is BlockTarget ? aim.hit.pos : null;

    // The last few blocks the player's own screen showed under the
    // crosshair. A claim still has to travel, so the server is allowed to be
    // a little behind — it is not allowed to be somewhere else entirely.
    final recent = <BlockPos>[];
    var strayed = 0;
    final examples = <String>[];

    final frames = Timer.periodic(const Duration(milliseconds: 16), (_) {
      alice.tick(1 / 60, const InputFrame(lookYaw: 0.02, lookPitch: -0.01));
      final mine = blockOf(alice.viewer.aim);
      if (mine != null) {
        recent.add(mine);
        if (recent.length > 2) recent.removeAt(0);
      }
      final theirs = blockOf(
        host.state.participants[const PlayerId('alice')]!.aim,
      );
      if (theirs != null && recent.isNotEmpty && !recent.contains(theirs)) {
        strayed++;
        if (examples.length < 3) examples.add('server $theirs, screen $recent');
      }
    });
    addTearDown(frames.cancel);

    await Future<void>.delayed(const Duration(seconds: 2));
    frames.cancel();

    // Looking along the ground, a fraction of a degree moves the far end of
    // the ray by whole blocks, so a server working its own aim out from a
    // view one tick old lands somewhere the player never pointed. Mining
    // only finishes after dwelling on one block, so what broke was reliably
    // the block beside the one under the crosshair.
    expect(strayed, 0, reason: examples.join('; '));
  });

  test('a prediction survives the round trip it agrees with', () async {
    final alice = await RemoteGameSession.join(
      await SocketChannel.connect(server.port),
      newcomer('alice'),
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
      newcomer('alice'),
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
