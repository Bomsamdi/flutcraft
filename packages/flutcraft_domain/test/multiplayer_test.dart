import 'dart:math';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

const alice = PlayerId('alice');
const bob = PlayerId('bob');

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

Participant playerAt(PlayerId id, VoxelWorld world, double x, double z) =>
    Participant(
      id: id,
      player: Player(world: world, spawn: Vector3(x, 2, z)),
    );

void main() {
  late VoxelWorld world;
  late GameState state;
  late GameLoop loop;

  setUp(() {
    world = flatWorld();
    state = GameState(
      world: world,
      players: [
        playerAt(alice, world, 20.5, 20.5),
        playerAt(bob, world, 40.5, 40.5),
      ],
    );
    loop = GameLoop(
      state: state,
      spawner: MobSpawner(world: world, seed: 1, maxMobs: 0),
      random: Random(1),
    );
  });

  Participant of(PlayerId id) => state.participants[id]!;

  group('Two players, one world', () {
    test('each carries their own inventory', () {
      of(alice).inventory.add(ItemType.planks, 8);

      expect(of(alice).inventory.countOf(ItemType.planks), 8);
      expect(of(bob).inventory.countOf(ItemType.planks), 0);
    });

    test('a command names who sent it', () {
      loop.dispatch(alice, const SelectHotbarSlot(3));

      expect(of(alice).selectedSlot, 3);
      expect(of(bob).selectedSlot, 0, reason: 'bob touched nothing');
    });

    test('one player opening a screen does not freeze the other', () {
      loop.dispatch(alice, const OpenRoute(UiRoute.inventory));
      final bobStart = of(bob).player.position.clone();

      for (var i = 0; i < 30; i++) {
        loop.tick(1 / 60, {
          bob: const InputFrame(forward: 1, held: {GameAction.moveForward}),
        });
      }

      expect(of(bob).player.position.distanceTo(bobStart), greaterThan(0.5));
      expect(of(alice).route, UiRoute.inventory);
    });

    test('the world keeps running while one player is in a menu', () {
      loop.dispatch(alice, const OpenRoute(UiRoute.inventory));
      // Far enough from Bob to have somewhere to walk, close enough to care.
      state.mobs.add(
        Mob(kind: MobKind.zombie, world: world, spawn: Vector3(45.5, 2, 45.5)),
      );
      final mobStart = state.mobs.first.position.clone();

      for (var i = 0; i < 60; i++) {
        loop.tick(1 / 60, const {});
      }

      // The zombie is hunting Bob, who never opened anything.
      expect(state.mobs.first.position.distanceTo(mobStart), greaterThan(0.5));
    });

    test('everyone in a menu does stop the world', () {
      loop
        ..dispatch(alice, const OpenRoute(UiRoute.inventory))
        ..dispatch(bob, const OpenRoute(UiRoute.inventory));
      state.mobs.add(
        Mob(kind: MobKind.zombie, world: world, spawn: Vector3(45.5, 2, 45.5)),
      );
      final mobStart = state.mobs.first.position.clone();

      for (var i = 0; i < 60; i++) {
        loop.tick(1 / 60, const {});
      }

      expect(state.mobs.first.position.distanceTo(mobStart), lessThan(1e-6));
    });

    test('a block one player breaks is gone for both', () {
      world.setBlock(20, 3, 20, BlockType.planks);
      final hit = world.raycast(
        Vector3(20.5, 3.5, 22),
        Vector3(0, 0, -1)..normalize(),
        6,
      )!;

      MiningSystem(random: Random(1)).breakBlockAt(state, of(alice), hit);

      expect(world.blockAt(20, 3, 20), BlockType.air);
      expect(of(alice).inventory.countOf(ItemType.planks), 1);
      expect(
        of(bob).inventory.countOf(ItemType.planks),
        0,
        reason: 'the drops went to whoever swung',
      );
    });

    test('a mob chases whoever is nearest, and switches when that changes', () {
      final mob = Mob(
        kind: MobKind.zombie,
        world: world,
        spawn: Vector3(22, 2, 22),
      );
      state.mobs.add(mob);

      expect(state.nearestLivingTo(mob.position)?.id, alice);

      // Alice walks off; Bob is now the closer target.
      of(alice).player.position.setValues(60.5, 2, 60.5);
      expect(state.nearestLivingTo(mob.position)?.id, bob);
    });

    test('a dead player is not chased', () {
      of(alice).player.damage(Player.maxHealth);
      final point = Vector3(21, 2, 21);

      expect(state.nearestLivingTo(point)?.id, bob);
    });

    test('an explosion hurts everyone standing in it', () {
      of(bob).player.position.setValues(21.5, 2, 20.5);
      const ExplosionSystem().explode(state, Vector3(21, 2, 20.5), 3, 20);

      expect(of(alice).player.health, lessThan(Player.maxHealth));
      expect(of(bob).player.health, lessThan(Player.maxHealth));
    });

    test('players cannot stand inside each other', () {
      of(bob).player.position.setFrom(of(alice).player.position);

      const EntitySeparationSystem().update(state);

      final apart = of(
        alice,
      ).player.position.distanceTo(of(bob).player.position);
      expect(apart, greaterThan(0.5));
    });

    test('each player gets their own snapshot', () {
      of(alice).inventory.add(ItemType.coal, 5);
      loop.dispatch(bob, const OpenRoute(UiRoute.inventory));

      final forAlice = GameSnapshot.forPlayer(state, of(alice));
      final forBob = GameSnapshot.forPlayer(state, of(bob));

      expect(forAlice.hotbar.first?.count, 5);
      expect(forBob.hotbar.first, isNull);
      expect(forAlice.route, UiRoute.none);
      expect(forBob.route, UiRoute.inventory);
      expect(
        forAlice.mobCount,
        forBob.mobCount,
        reason: 'the world looks the same to both',
      );
    });

    test('a swing by one does not put the other on cooldown', () {
      final mob = Mob(
        kind: MobKind.zombie,
        world: world,
        spawn: Vector3(21, 2, 20.5),
      );
      state.mobs.add(mob);
      final mining = MiningSystem(random: Random(1));

      of(alice).aim = MobTarget(mob, 1);
      of(bob).aim = MobTarget(mob, 1);
      mining.update(state, of(alice), 1 / 60, active: true);
      final afterAlice = mob.health;
      mining.update(state, of(bob), 1 / 60, active: true);

      // The swing timer used to be a field on the system, shared by everyone.
      expect(mob.health, lessThan(afterAlice));
    });
  });

  group('Spawning does not scale with the crowd', () {
    test('a second player does not double the spawn rate', () {
      int mobsAfter(int players, {required double seconds}) {
        final world = flatWorld();
        final state = GameState(
          world: world,
          players: [
            for (var i = 0; i < players; i++)
              playerAt(PlayerId('p$i'), world, 20.5 + i * 4, 20.5),
          ],
        );
        final loop = GameLoop(
          state: state,
          spawner: MobSpawner(world: world, seed: 7),
          random: Random(7),
        );
        for (var i = 0; i < seconds * 60; i++) {
          loop.tick(1 / 60, const {});
        }
        return state.mobs.length;
      }

      // Long enough for a couple of spawn windows, short of the cap.
      const seconds = 14.0;
      final solo = mobsAfter(1, seconds: seconds);
      final crowd = mobsAfter(4, seconds: seconds);

      expect(solo, greaterThan(0), reason: 'something should have spawned');
      expect(
        crowd,
        solo,
        reason: 'the spawner has one clock, however many people share it',
      );
    });
  });

  group('Joining and leaving', () {
    test('a player can join a world that is already running', () {
      for (var i = 0; i < 60; i++) {
        loop.tick(1 / 60, const {});
      }

      state.join(playerAt(const PlayerId('carol'), world, 30.5, 30.5));
      loop.tick(1 / 60, const {});

      expect(state.participants, hasLength(3));
    });

    test('leaving hands back what they were carrying', () {
      of(bob).inventory.add(ItemType.ironIngot, 3);

      final gone = state.leave(bob);

      expect(gone?.inventory.countOf(ItemType.ironIngot), 3);
      expect(state.participants, hasLength(1));
    });

    test('a command from someone who left is ignored, not fatal', () {
      state.leave(bob);

      expect(
        () => loop.dispatch(bob, const SelectHotbarSlot(2)),
        returnsNormally,
      );
      expect(loop.dispatch(bob, const SelectHotbarSlot(2)), isEmpty);
    });
  });
}
