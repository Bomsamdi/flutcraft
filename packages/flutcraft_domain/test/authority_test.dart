import 'dart:math';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

const me = PlayerId('me');

VoxelWorld flatWorld({int size = 64}) {
  final world = VoxelWorld(sizeX: size, sizeY: 24, sizeZ: size);
  for (var z = 0; z < size; z++) {
    for (var x = 0; x < size; x++) {
      world.setRaw(x, 0, z, BlockType.bedrock);
      world.setRaw(x, 1, z, BlockType.stone);
    }
  }
  return world;
}

GameState worldWithOne(VoxelWorld world) => GameState(
  world: world,
  players: [
    Participant(
      id: me,
      player: Player(world: world, spawn: Vector3(32.5, 2, 32.5)),
    ),
  ],
);

void main() {
  late VoxelWorld world;
  late GameState state;
  late RecordingSaveSink sink;

  setUp(() {
    world = flatWorld();
    state = worldWithOne(world);
    sink = RecordingSaveSink();
  });

  GameLoop server() => GameLoop.authoritative(
    state: state,
    world: WorldSystems(
      spawner: MobSpawner(world: world, seed: 1),
      random: Random(1),
      saveSink: sink,
      autosaveInterval: 1,
    ),
    random: Random(1),
  );

  GameLoop client() => GameLoop.predicting(state: state, random: Random(1));

  Mob zombieNearby() {
    final mob = Mob(
      kind: MobKind.zombie,
      world: world,
      spawn: Vector3(36, 2, 32.5),
    );
    state.spawn(mob);
    return mob;
  }

  void play(GameLoop loop, {double seconds = 10}) {
    for (var i = 0; i < seconds * kTicksPerSecond; i++) {
      loop.tick(kStep, const {});
    }
  }

  group('A predicting loop leaves the world alone', () {
    test('it spawns nothing', () {
      play(client());

      expect(state.mobs, isEmpty);
    });

    test('it does not move a mob it was handed', () {
      final mob = zombieNearby();
      final start = mob.position.clone();

      play(client());

      // The server owns where the zombie is. A client with an opinion about
      // it would show the same zombie in two places.
      expect(mob.position, start);
    });

    test('it never writes a block', () {
      zombieNearby();

      play(client());
      world.drainChanges();

      expect(world.edits, isEmpty);
    });

    test('it never saves', () {
      play(client());

      expect(sink.saves, isEmpty);
    });

    test('an explosion asked for from outside does nothing', () {
      final loop = client();

      loop.explode(Vector3(32.5, 2, 32.5), 4, 20);
      play(loop, seconds: 1);

      expect(world.edits, isEmpty);
      expect(state.solo.player.health, Player.maxHealth);
    });

    test('it says plainly that it does not rule', () {
      expect(client().isAuthoritative, isFalse);
      expect(server().isAuthoritative, isTrue);
    });
  });

  group('An authoritative loop does all four', () {
    test('it spawns, moves, writes and saves', () {
      final mob = zombieNearby();
      final start = mob.position.clone();

      play(server());

      expect(mob.position, isNot(start), reason: 'the zombie went hunting');
      expect(sink.saves, isNotEmpty, reason: 'ten seconds is past the minute');
    });

    test('a creeper leaves a crater', () {
      state.spawn(
        Mob(kind: MobKind.creeper, world: world, spawn: Vector3(34, 2, 32.5)),
      );

      play(server(), seconds: 4);

      expect(world.edits, isNotEmpty);
    });
  });

  group('What a client may still work out for itself', () {
    test('it moves the player it is playing', () {
      final loop = client();
      final start = state.solo.player.position.clone();

      for (var i = 0; i < kTicksPerSecond; i++) {
        loop.tick(kStep, const {
          me: InputFrame(forward: 1, held: {GameAction.moveForward}),
        });
      }

      // Waiting a round trip for WASD is unshippable, so this half is the
      // client's regardless of who rules the world.
      expect(state.solo.player.position.distanceTo(start), greaterThan(1));
    });

    test('it aims, so the crosshair does not wait for a server', () {
      world.setBlock(32, 3, 30, BlockType.planks);
      world.drainChanges();
      final loop = client();
      state.solo.player
        ..position.setValues(32.5, 2, 32.5)
        ..yaw = 0;

      loop.tick(kStep, const {});

      expect(state.solo.aim, isA<BlockTarget>());
    });

    test('a progress bar fills, but the block does not break', () {
      world.setBlock(32, 2, 30, BlockType.planks);
      world.drainChanges();
      final loop = client();
      state.solo.player
        ..position.setValues(32.5, 2, 32.5)
        ..yaw = 0;

      for (var i = 0; i < kTicksPerSecond * 5; i++) {
        loop.tick(kStep, const {
          me: InputFrame(held: {GameAction.primary}),
        });
      }

      // Progress is this player's own business; what it comes to is not.
      expect(world.blockAt(32, 2, 30), BlockType.planks);
      expect(state.solo.inventory.countOf(ItemType.planks), 0);
    });

    test('a swing at a mob hurts nobody', () {
      final mob = zombieNearby();
      final loop = client();
      state.solo.aim = MobTarget(mob, 1);

      for (var i = 0; i < kTicksPerSecond; i++) {
        loop.tick(kStep, const {
          me: InputFrame(held: {GameAction.primary}),
        });
      }

      expect(mob.health, MobKind.zombie.maxHealth);
    });

    test('opening a screen is instant, because waiting for one is not', () {
      final loop = client();

      loop.dispatch(me, const OpenRoute(UiRoute.inventory));

      expect(state.solo.route, UiRoute.inventory);
    });
  });
}
