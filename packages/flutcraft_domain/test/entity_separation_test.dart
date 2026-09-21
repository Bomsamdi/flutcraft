import 'dart:math';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

const separation = EntitySeparationSystem();

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

GameState gameOn(VoxelWorld world, {Vector3? spawn}) => GameState.solo(
  world: world,
  player: Player(world: world, spawn: spawn ?? Vector3(32.5, 2, 32.5)),
  inventory: Inventory(),
);

Mob zombieAt(VoxelWorld world, double x, double z, {double y = 2}) =>
    Mob(kind: MobKind.zombie, world: world, spawn: Vector3(x, y, z));

/// Positions are 32-bit vectors, so a gap of exactly zero is not something
/// arithmetic on world coordinates can promise.
const tolerance = 1e-4;

/// Horizontal gap between the two bodies, ignoring height.
double gapBetween(VoxelBody a, VoxelBody b) {
  final dx = (a.position.x - b.position.x).abs();
  final dz = (a.position.z - b.position.z).abs();
  return max(dx, dz) - (a.halfWidth + b.halfWidth);
}

void main() {
  late VoxelWorld world;
  late GameState state;

  setUp(() {
    world = flatWorld();
    state = gameOn(world);
  });

  group('A mob cannot stand inside the player', () {
    test('an overlapping mob is pushed out', () {
      final mob = zombieAt(world, 32.6, 32.5);
      state.mobs.add(mob);

      separation.update(state);

      expect(gapBetween(mob, state.solo.player), greaterThan(-tolerance));
    });

    test('the mob gives way more than the player does', () {
      final mob = zombieAt(world, 32.7, 32.5);
      state.mobs.add(mob);
      final playerBefore = state.solo.player.position.clone();
      final mobBefore = mob.position.clone();

      separation.update(state);

      final playerMoved = state.solo.player.position.distanceTo(playerBefore);
      final mobMoved = mob.position.distanceTo(mobBefore);
      expect(mobMoved, greaterThan(playerMoved));
      expect(playerMoved, greaterThan(0), reason: 'a shove is still felt');
    });

    test('bodies that merely touch are left alone', () {
      final mob = zombieAt(world, 32.5 + 0.6, 32.5);
      state.mobs.add(mob);
      final before = mob.position.clone();

      separation.update(state);

      expect(mob.position.distanceTo(before), lessThan(1e-6));
    });

    test('a mob across the room is not touched', () {
      final mob = zombieAt(world, 40, 32.5);
      state.mobs.add(mob);
      final before = mob.position.clone();

      separation.update(state);

      expect(mob.position, before);
    });

    test('two bodies on exactly the same spot still come apart', () {
      final mob = zombieAt(world, 32.5, 32.5);
      state.mobs.add(mob);

      separation.update(state);

      expect(gapBetween(mob, state.solo.player), greaterThan(-tolerance));
    });

    test('a dead mob is not pushed about', () {
      final mob = zombieAt(world, 32.6, 32.5)..health = 0;
      state.mobs.add(mob);
      final before = mob.position.clone();

      separation.update(state);

      expect(mob.position, before);
    });
  });

  group('Height matters', () {
    test('a mob standing on the roof above is left where it is', () {
      // Directly overhead: it overlaps on both horizontal axes, and pushing
      // it sideways up there would be nonsense.
      final mob = zombieAt(world, 32.5, 32.5, y: 6);
      state.mobs.add(mob);
      final before = mob.position.clone();

      separation.update(state);

      expect(mob.position, before);
    });

    test('a mob at the player\'s feet still counts as overlapping', () {
      final mob = zombieAt(world, 32.6, 32.5, y: 2.5);
      state.mobs.add(mob);

      separation.update(state);

      expect(gapBetween(mob, state.solo.player), greaterThan(-tolerance));
    });
  });

  group('Mobs untangle each other', () {
    test('two mobs on one spot separate', () {
      final first = zombieAt(world, 20.5, 20.5);
      final second = zombieAt(world, 20.6, 20.5);
      state.mobs.addAll([first, second]);

      separation.update(state);

      expect(gapBetween(first, second), greaterThan(-tolerance));
    });

    test('mobs share the correction evenly, unlike with the player', () {
      final first = zombieAt(world, 20.5, 20.5);
      final second = zombieAt(world, 20.7, 20.5);
      state.mobs.addAll([first, second]);
      final firstBefore = first.position.clone();
      final secondBefore = second.position.clone();

      separation.update(state);

      expect(
        first.position.distanceTo(firstBefore),
        closeTo(second.position.distanceTo(secondBefore), 1e-9),
      );
    });

    test('a crowd does not end up stacked on one square', () {
      for (var i = 0; i < 4; i++) {
        state.mobs.add(zombieAt(world, 20.5 + i * 0.05, 20.5));
      }

      // One pass separates each pair; a few settle the pile.
      for (var i = 0; i < 8; i++) {
        separation.update(state);
      }

      // Pairs are resolved one after another, so a body can be nudged back a
      // fraction by a later pair. What matters is that four zombies end up in
      // a line rather than in one square — millimetres of contact are not
      // what makes a fight unfair.
      const settled = -0.005;
      for (var i = 0; i < state.mobs.length; i++) {
        for (var j = i + 1; j < state.mobs.length; j++) {
          expect(
            gapBetween(state.mobs[i], state.mobs[j]),
            greaterThan(settled),
            reason: 'mobs $i and $j are still inside each other',
          );
        }
      }

      // Spread out, not piled up: four 0.6-wide bodies need 1.8 of room.
      final xs = state.mobs.map((mob) => mob.position.x).toList()..sort();
      expect(xs.last - xs.first, greaterThan(1.7));
    });

    test('a settled crowd stops moving instead of jittering', () {
      for (var i = 0; i < 4; i++) {
        state.mobs.add(zombieAt(world, 20.5 + i * 0.05, 20.5));
      }
      for (var i = 0; i < 40; i++) {
        separation.update(state);
      }

      final settled = [for (final mob in state.mobs) mob.position.clone()];
      for (var i = 0; i < 10; i++) {
        separation.update(state);
      }

      for (var i = 0; i < state.mobs.length; i++) {
        expect(
          state.mobs[i].position.distanceTo(settled[i]),
          lessThan(0.01),
          reason: 'the pile is still shuffling',
        );
      }
    });
  });

  _combatFeel();

  group('Separation keeps out of the physics', () {
    test('a push does not make a mob think a wall is in the way', () {
      final mob = zombieAt(world, 32.6, 32.5);
      state.mobs.add(mob);

      separation.update(state);

      // The flag means "something solid stopped me", and mobs jump when they
      // see it. Being nudged by a neighbour is not a reason to jump.
      expect(mob.blockedHorizontally, isFalse);
    });

    test('a push does not lift anyone off the ground', () {
      final mob = zombieAt(world, 32.6, 32.5);
      state.mobs.add(mob);
      mob.onGround = true;
      state.solo.player.onGround = true;

      separation.update(state);

      expect(mob.onGround, isTrue);
      expect(state.solo.player.onGround, isTrue);
      expect(mob.position.y, closeTo(2, 1e-6));
    });
  });

  group('Walls win', () {
    test('a push does not shove anyone into stone', () {
      // Player in a corner, mob walking in from the open side.
      world.setBlock(31, 2, 32, BlockType.stone);
      final state = gameOn(world, spawn: Vector3(32.5, 2, 32.5));
      final mob = zombieAt(world, 32.7, 32.5);
      state.mobs.add(mob);

      for (var i = 0; i < 10; i++) {
        separation.update(state);
      }

      expect(
        state.solo.player.collides(),
        isFalse,
        reason: 'the player was pushed into the wall',
      );
      expect(mob.collides(), isFalse);
    });
  });
}

/// The whole point, played out: a zombie walking at someone standing still.
void _combatFeel() {
  group('Fighting a zombie that walked up to you', () {
    late VoxelWorld world;
    late GameLoop loop;
    late Mob zombie;

    setUp(() {
      world = flatWorld();
      final state = gameOn(world);
      zombie = zombieAt(world, 38, 32.5);
      state.mobs.add(zombie);
      loop = GameLoop(
        state: state,
        spawner: MobSpawner(world: world, seed: 1, maxMobs: 0),
        random: Random(1),
      );
    });

    void play(double seconds) {
      for (var i = 0; i < seconds * 60; i++) {
        loop.tickSolo(1 / 60, InputFrame.idle);
      }
    }

    test('it never gets inside the player', () {
      var closest = double.infinity;
      for (var i = 0; i < 60 * 6; i++) {
        loop.tickSolo(1 / 60, InputFrame.idle);
        closest = min(closest, gapBetween(zombie, loop.state.solo.player));
      }

      // It used to walk straight through, which is what made it so hard to
      // hit: the thing attacking you was inside your own head.
      expect(closest, greaterThan(-0.005));
    });

    test('it does still come close enough to be worth swinging at', () {
      play(6);

      expect(gapBetween(zombie, loop.state.solo.player), lessThan(0.4));
    });

    test('it still lands hits from where it stops', () {
      play(6);

      expect(loop.state.solo.player.health, lessThan(Player.maxHealth));
    });

    test('it does not bulldoze a player who stands their ground', () {
      final start = loop.state.solo.player.position.clone();

      play(6);

      // A shove is fine; being pushed across the room is not.
      expect(loop.state.solo.player.position.distanceTo(start), lessThan(1.0));
    });

    test('it comes to rest instead of shuddering against you', () {
      play(6);
      final settled = zombie.position.clone();

      play(1);

      expect(zombie.position.distanceTo(settled), lessThan(0.15));
    });
  });
}
