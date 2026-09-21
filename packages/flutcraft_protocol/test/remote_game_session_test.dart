import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_protocol/flutcraft_protocol.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

const me = PlayerId('me');
const her = PlayerId('her');

const walking = InputFrame(forward: 1, held: {GameAction.moveForward});

/// Joins a pretend server that has already said hello.
Future<(RemoteGameSession, FakeChannel)> joined({
  int seed = 1337,
  Map<BlockPos, BlockType> edits = const {},
}) async {
  final channel = FakeChannel();
  final joining = RemoteGameSession.join(channel, me);
  channel.deliver(
    Welcome(
      you: me,
      tick: 100,
      world: WorldState(seed: seed, edits: edits),
    ),
  );
  return (await joining, channel);
}

/// Pretends the server said something, and lets the client hear it.
///
/// Goes through the real stream rather than a back door, so the tests
/// exercise the same path a socket does.
Future<void> serverSays(FakeChannel channel, ServerMessage message) async {
  channel.deliver(message);
  await Future<void>.delayed(Duration.zero);
}

/// Lets the event loop hand out whatever is already queued.
Future<void> pump() => Future<void>.delayed(Duration.zero);

SelfState correction({
  required int ackTick,
  required Vector3 position,
  Vector3? velocity,
}) => SelfState(
  ackTick: ackTick,
  position: position,
  velocity: velocity ?? Vector3.zero(),
  yaw: 0,
  pitch: 0,
  onGround: true,
  flying: false,
  health: 20,
);

MobState zombieAt(int id, Vector3 position) => MobState(
  id: EntityId(id),
  kind: MobKind.zombie,
  position: position,
  yaw: 0,
  health: 20,
  walkSpeed: 0,
  fuse: -1,
);

void main() {
  group('Joining', () {
    test('the world is rebuilt from a seed and a handful of edits', () async {
      final (session, channel) = await joined(
        edits: {const BlockPos(64, 30, 64): BlockType.planks},
      );

      expect(session.state.world.seed, 1337);
      expect(session.state.world.blockAt(64, 30, 64), BlockType.planks);
      await session.close();
    });

    test('it starts counting from the server tick', () async {
      final (session, channel) = await joined();

      expect(session.currentTick, 100);
      await session.close();
    });

    test('nothing sent right behind the welcome is lost', () async {
      final channel = FakeChannel();
      final joining = RemoteGameSession.join(channel, me);

      // A server sends the welcome and the player's belongings back to back.
      // Waiting for the welcome on one subscription and the rest on another
      // leaves a gap, and a broadcast stream keeps nothing for whoever was
      // not listening yet: the inventory fell into it every time.
      channel
        ..deliver(
          const Welcome(
            you: me,
            tick: 1,
            world: WorldState(seed: 1, edits: {}),
          ),
        )
        ..deliver(
          const InventoryState(
            revision: 3,
            slots: [ItemStack(ItemType.cobblestone, 16)],
            selectedSlot: 0,
          ),
        );

      final session = await joining;
      // The welcome resolves before the stream hands over the next event, so
      // the inventory arrives a turn of the event loop later — the point is
      // that it arrives at all.
      await pump();
      expect(session.viewer.inventory.countOf(ItemType.cobblestone), 16);
      await session.close();
    });

    test('it says hello without being told to', () async {
      final (session, channel) = await joined();

      expect(channel.sent.whereType<Hello>(), hasLength(1));
      await session.close();
    });
  });

  group('The player moves without waiting for anybody', () {
    test('walking starts at once', () async {
      final (session, channel) = await joined();
      final start = session.viewer.player.position.clone();

      session.tick(kStep * 10, walking);

      // A round trip on WASD is unshippable; this is the whole reason the
      // client simulates at all.
      expect(session.viewer.player.position.distanceTo(start), greaterThan(0));
      await session.close();
    });

    test('every step is sent, stamped with its tick', () async {
      final (session, channel) = await joined();

      session.tick(kStep * 3, walking);

      final sent = channel.sent.whereType<InputTick>().toList();
      expect(sent, hasLength(3));
      expect(sent.map((i) => i.tick), [101, 102, 103]);
      await session.close();
    });

    test(
      'unconfirmed input piles up until the server acknowledges it',
      () async {
        final (session, channel) = await joined();
        session.tick(kStep * 5, walking);
        expect(session.unackedInputs, 5);

        session.tick(kStep, InputFrame.idle);
        // Everything up to tick 103 is now the server's business, not ours.
        session
          ..tick(0, InputFrame.idle)
          ..tick(0, InputFrame.idle);
        await Future<void>.delayed(Duration.zero);

        await session.close();
      },
    );
  });

  group('Correction', () {
    test('a small error is walked in, never jerked', () async {
      final (session, channel) = await joined();
      session.tick(kStep * 10, walking);
      final shown = session.viewer.player.position.clone();

      // The server saw it slightly differently — five centimetres.
      await serverSays(
        channel,
        correction(
          ackTick: session.currentTick,
          position: shown + Vector3(0.05, 0, 0),
        ),
      );

      // Nothing moved this instant: what the player is looking at stays put.
      expect(session.viewer.player.position.distanceTo(shown), lessThan(1e-6));

      // And over the next few ticks it arrives.
      session.tick(kStep * 6, InputFrame.idle);
      expect(session.viewer.player.position.x, closeTo(shown.x + 0.05, 0.02));
      await session.close();
    });

    test('the view never jumps backwards for a small error', () async {
      final (session, channel) = await joined();
      final seen = <double>[];

      for (var i = 0; i < 40; i++) {
        session.tick(kStep, walking);
        if (i == 20) {
          await serverSays(
            channel,
            correction(
              ackTick: session.currentTick - 3,
              position: session.viewer.player.position - Vector3(0.1, 0, 0),
            ),
          );
        }
        seen.add(session.viewer.player.position.z);
      }

      // Walking forward is -Z; the camera must never slide back the way it
      // came, however wrong the client was.
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], lessThanOrEqualTo(seen[i - 1] + 1e-6));
      }
      await session.close();
    });

    test('the view is never overruled, however stale the server is', () async {
      final (session, channel) = await joined();
      session.tick(kStep * 5, const InputFrame(lookYaw: 0.5));
      final looking = session.viewer.player.yaw;

      // The server answers with the yaw it had before that turn arrived.
      await serverSays(
        channel,
        correction(
          ackTick: session.currentTick,
          position: session.viewer.player.position.clone(),
        ),
      );

      // A mouse in somebody's hand is not the server's to correct.
      expect(session.viewer.player.yaw, closeTo(looking, 1e-9));
      await session.close();
    });

    test('a large error snaps, because hiding it would be a lie', () async {
      final (session, channel) = await joined();
      session.tick(kStep * 10, walking);
      final elsewhere = Vector3(10, 5, 10);

      await serverSays(
        channel,
        correction(ackTick: session.currentTick, position: elsewhere),
      );

      expect(
        session.viewer.player.position.distanceTo(elsewhere),
        lessThan(0.001),
      );
      await session.close();
    });

    test('input the server has not seen is replayed over its answer', () async {
      final (session, channel) = await joined();
      session.tick(kStep * 10, walking);
      final ackAt = session.currentTick - 5;
      final before = session.viewer.player.position.clone();

      await serverSays(channel, correction(ackTick: ackAt, position: before));

      // Five frames of walking were replayed on top, so the player is ahead
      // of where the server last saw them rather than back at it.
      expect(session.unackedInputs, 5);
      await session.close();
    });
  });

  group('Mirroring what belongs to the server', () {
    test('a mob is written into, never rebuilt', () async {
      final (session, channel) = await joined();
      await serverSays(
        channel,
        EntityDelta(tick: 101, mobs: [zombieAt(1, Vector3(10, 2, 10))]),
      );
      final mob = session.state.mobs.single;

      for (var i = 0; i < 100; i++) {
        await serverSays(
          channel,
          EntityDelta(
            tick: 101 + i,
            mobs: [zombieAt(1, Vector3(10 + i * 0.1, 2, 10))],
          ),
        );
        session.tick(kStep, InputFrame.idle);
      }

      // Rebuilding it per packet would make the renderer drop and re-add a
      // component twenty times a second, and the zombie would flicker.
      expect(session.state.mobs.single, same(mob));
      expect(session.state.mobs, hasLength(1));
      await session.close();
    });

    test('a mob slides rather than teleporting', () async {
      final (session, channel) = await joined();
      await serverSays(
        channel,
        EntityDelta(tick: 101, mobs: [zombieAt(1, Vector3(10, 2, 10))]),
      );
      final mob = session.state.mobs.single;

      await serverSays(
        channel,
        EntityDelta(tick: 104, mobs: [zombieAt(1, Vector3(11, 2, 10))]),
      );
      session.tick(kStep, InputFrame.idle);

      expect(mob.position.x, greaterThan(10));
      expect(mob.position.x, lessThan(11));
      await session.close();
    });

    test('a mob the server drops leaves the world', () async {
      final (session, channel) = await joined();
      await serverSays(
        channel,
        EntityDelta(tick: 101, mobs: [zombieAt(1, Vector3(10, 2, 10))]),
      );

      await serverSays(
        channel,
        const EntityDelta(tick: 102, gone: [EntityId(1)]),
      );

      expect(session.state.mobs, isEmpty);
      await session.close();
    });

    test('other players appear and disappear with the server word', () async {
      final (session, channel) = await joined();

      await serverSays(
        channel,
        PlayerStates(101, [
          RemotePlayerState(
            id: her,
            position: Vector3(20, 2, 20),
            yaw: 1,
            pitch: 0,
            health: 20,
          ),
        ]),
      );
      expect(session.state.participants.keys, containsAll([me, her]));

      await serverSays(channel, const PlayerStates(102, []));
      expect(session.state.participants.keys, [me]);
      await session.close();
    });
  });

  group('Blocks are guessed at, then settled', () {
    test('a placement shows at once and is remembered as a guess', () async {
      final (session, channel) = await joined();
      session.state.world.setBlock(30, 5, 30, BlockType.planks);
      session.tick(kStep, InputFrame.idle);

      expect(session.unconfirmedBlocks, 1);
      await session.close();
    });

    test('a guess the server confirms is simply kept', () async {
      final (session, channel) = await joined();
      session.state.world.setBlock(30, 5, 30, BlockType.planks);
      session.tick(kStep, InputFrame.idle);

      await serverSays(
        channel,
        WorldDelta(session.currentTick, const [
          BlockChange(BlockPos(30, 5, 30), BlockType.planks),
        ]),
      );

      expect(session.state.world.blockAt(30, 5, 30), BlockType.planks);
      expect(session.unconfirmedBlocks, 0);
      await session.close();
    });

    test('a guess the server never mentions is put back', () async {
      final (session, channel) = await joined();
      // Whatever the terrain generated here — not necessarily air.
      final before = session.state.world.blockAt(30, 5, 30);
      session.state.world.setBlock(30, 5, 30, BlockType.planks);
      session.tick(kStep, InputFrame.idle);

      // A delta from after the guess that says nothing about it: somebody
      // else got there first, or the server refused it.
      await serverSays(channel, WorldDelta(session.currentTick + 1, const []));

      expect(session.state.world.blockAt(30, 5, 30), before);
      expect(session.unconfirmedBlocks, 0);
      await session.close();
    });

    test(
      'a guess newer than the delta is left alone to be judged later',
      () async {
        final (session, channel) = await joined();
        session.state.world.setBlock(30, 5, 30, BlockType.planks);
        session.tick(kStep, InputFrame.idle);

        await serverSays(
          channel,
          WorldDelta(session.currentTick - 5, const []),
        );

        expect(session.state.world.blockAt(30, 5, 30), BlockType.planks);
        expect(session.unconfirmedBlocks, 1);
        await session.close();
      },
    );
  });

  group('What only the server may say', () {
    test('an inventory is taken as given, and a stale one ignored', () async {
      final (session, channel) = await joined();

      await serverSays(
        channel,
        const InventoryState(
          revision: 5,
          slots: [ItemStack(ItemType.coal, 7)],
          selectedSlot: 2,
        ),
      );
      expect(session.viewer.inventory.countOf(ItemType.coal), 7);
      expect(session.viewer.selectedSlot, 2);

      await serverSays(
        channel,
        const InventoryState(revision: 4, slots: [], selectedSlot: 0),
      );
      expect(
        session.viewer.inventory.countOf(ItemType.coal),
        7,
        reason: 'a copy that left the server earlier is not news',
      );
      await session.close();
    });

    test('an explosion is carved locally from a point and a radius', () async {
      final (session, channel) = await joined();
      final world = session.state.world;
      world.setBlock(40, 20, 40, BlockType.planks);

      await serverSays(channel, ExplosionAt(Vector3(40.5, 20.5, 40.5), 3));

      // Three hundred block changes would have been absurd to send.
      expect(world.blockAt(40, 20, 40), BlockType.air);
      await session.close();
    });

    test('a notice reaches the interface as an event', () async {
      final (session, channel) = await joined();
      final heard = <GameEvent>[];
      session.events.listen(heard.add);

      await serverSays(channel, const Notice(GameSaved()));
      await Future<void>.delayed(Duration.zero);

      expect(heard, hasLength(1));
      await session.close();
    });

    test('a ping is answered', () async {
      final (session, channel) = await joined();

      await serverSays(channel, const Ping(9));

      expect(channel.sent.whereType<Pong>().single.id, 9);
      await session.close();
    });
  });
}
