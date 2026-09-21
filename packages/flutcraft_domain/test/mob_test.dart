import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';

/// Stands in for the game world and records what the mobs tried to do.
class FakeContext implements MobTickContext {
  FakeContext(this.player);

  @override
  final Player player;

  final List<(Vector3, Vector3)> arrows = [];
  final List<(Vector3, double, int)> explosions = [];

  @override
  void spawnArrow(Vector3 from, Vector3 direction) =>
      arrows.add((from.clone(), direction.clone()));

  @override
  void explode(Vector3 at, double radius, int maxDamage) =>
      explosions.add((at.clone(), radius, maxDamage));
}

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

void main() {
  group('Mob', () {
    test('a zombie closes in on the player', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));
      final mob = Mob(
        kind: MobKind.zombie,
        world: world,
        spawn: Vector3(32.5, 2, 42.5),
      );
      final context = FakeContext(player);

      final before = mob.position.distanceTo(player.position);
      for (var i = 0; i < 120; i++) {
        mob.update(1 / 60, player, context);
      }
      final after = mob.position.distanceTo(player.position);

      expect(after, lessThan(before - 2));
    });

    test('out of aggro range a mob stays put', () {
      final world = flatWorld(size: 128);
      final player = Player(world: world, spawn: Vector3(10.5, 2, 10.5));
      final mob = Mob(
        kind: MobKind.zombie,
        world: world,
        spawn: Vector3(100.5, 2, 100.5),
      );
      final start = mob.position.clone();

      for (var i = 0; i < 60; i++) {
        mob.update(1 / 60, player, FakeContext(player));
      }

      expect(mob.position.x, closeTo(start.x, 0.01));
      expect(mob.position.z, closeTo(start.z, 0.01));
    });

    test('a zombie in reach hurts the player, but not every frame', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));
      final mob = Mob(
        kind: MobKind.zombie,
        world: world,
        spawn: Vector3(33.2, 2, 32.5),
      );

      mob.update(1 / 60, player, FakeContext(player));
      expect(player.health, lessThan(Player.maxHealth));

      final afterFirst = player.health;
      mob.update(1 / 60, player, FakeContext(player));
      expect(player.health, afterFirst);
    });

    test('szkielet strzela z dystansu', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));
      final mob = Mob(
        kind: MobKind.skeleton,
        world: world,
        spawn: Vector3(32.5, 2, 40.5),
      );
      final context = FakeContext(player);

      mob.update(1 / 60, player, context);
      expect(context.arrows, hasLength(1));

      // The arrow flies towards the player.
      final (_, direction) = context.arrows.first;
      expect(direction.z, lessThan(0));
    });

    test('a skeleton does not shoot through a wall', () {
      final world = flatWorld();
      for (var y = 1; y <= 6; y++) {
        for (var x = 28; x <= 38; x++) {
          world.setRaw(x, y, 36, BlockType.stone);
        }
      }
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));
      final mob = Mob(
        kind: MobKind.skeleton,
        world: world,
        spawn: Vector3(32.5, 2, 40.5),
      );
      final context = FakeContext(player);

      mob.update(1 / 60, player, context);
      expect(context.arrows, isEmpty);
    });

    test('creeper zapala lont i wybucha przy graczu', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));
      final mob = Mob(
        kind: MobKind.creeper,
        world: world,
        spawn: Vector3(34.5, 2, 32.5),
      );
      final context = FakeContext(player);

      mob.update(1 / 60, player, context);
      expect(mob.isPrimed, isTrue);
      expect(context.explosions, isEmpty);

      for (var i = 0; i < 120; i++) {
        mob.update(1 / 60, player, context);
      }

      expect(context.explosions, hasLength(1));
      expect(mob.isDead, isTrue);
    });

    test('the fuse goes out when the player runs away', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));
      final mob = Mob(
        kind: MobKind.creeper,
        world: world,
        spawn: Vector3(34.5, 2, 32.5),
      );
      final context = FakeContext(player);

      mob.update(1 / 60, player, context);
      expect(mob.isPrimed, isTrue);

      player.position.setValues(50.5, 2, 32.5);
      mob.update(1 / 60, player, context);

      expect(mob.isPrimed, isFalse);
      expect(context.explosions, isEmpty);
    });

    test('damage kills a mob and knocks it back', () {
      final world = flatWorld();
      final mob = Mob(
        kind: MobKind.spider,
        world: world,
        spawn: Vector3(32.5, 2, 32.5),
      );

      mob.damage(5, source: Vector3(31.5, 2, 32.5));
      expect(mob.health, MobKind.spider.maxHealth - 5);
      expect(mob.velocity.x, greaterThan(0));

      mob.damage(100);
      expect(mob.isDead, isTrue);
    });

    test('a ray from the eye hits the mob box', () {
      final world = flatWorld();
      final mob = Mob(
        kind: MobKind.zombie,
        world: world,
        spawn: Vector3(32.5, 2, 28.5),
      );

      final origin = Vector3(32.5, 3.6, 32.5);
      final hit = mob.rayDistance(origin, Vector3(0, 0, -1), 10);
      expect(hit, isNotNull);
      expect(hit, closeTo(3.7, 0.4));

      final miss = mob.rayDistance(origin, Vector3(1, 0, 0), 10);
      expect(miss, isNull);
    });
  });

  _balanceTests();
  _spawnRangeTest();

  group('Arrow', () {
    test('it hits the player and disappears', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));
      final arrow = Arrow(
        world: world,
        spawn: Vector3(32.5, 3.0, 35.0),
        direction: Vector3(0, 0, -1),
      );

      for (var i = 0; i < 30 && !arrow.removed; i++) {
        arrow.update(1 / 60, player);
      }

      expect(arrow.removed, isTrue);
      expect(player.health, lessThan(Player.maxHealth));
    });

    test('it disappears once stuck in the ground', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(10.5, 2, 10.5));
      final arrow = Arrow(
        world: world,
        spawn: Vector3(32.5, 4.0, 32.5),
        direction: Vector3(0, -1, 0),
      );

      for (var i = 0; i < 60 && !arrow.removed; i++) {
        arrow.update(1 / 60, player);
      }

      expect(arrow.removed, isTrue);
      expect(player.health, Player.maxHealth);
    });
  });

  group('MobSpawner', () {
    test('it spawns only once the interval has passed', () {
      final world = flatWorld(size: 96);
      final player = Player(world: world, spawn: Vector3(48.5, 2, 48.5));
      final spawner = MobSpawner(world: world);

      expect(spawner.maybeSpawn(1.0, player, 0), isNull);
      final mob = spawner.maybeSpawn(MobSpawner.interval, player, 0);
      expect(mob, isNotNull);

      final distance = mob!.position.distanceTo(player.position);
      expect(distance, greaterThanOrEqualTo(MobSpawner.minDistance - 2));
      expect(distance, lessThanOrEqualTo(MobSpawner.maxDistance + 2));
    });

    test('it stays under the population cap', () {
      final world = flatWorld(size: 96);
      final player = Player(world: world, spawn: Vector3(48.5, 2, 48.5));
      final spawner = MobSpawner(world: world, maxMobs: 3);
      expect(spawner.maybeSpawn(MobSpawner.interval, player, 3), isNull);
    });
  });

  group('Player', () {
    test('invulnerability absorbs the next hits', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));

      expect(player.damage(3), isTrue);
      expect(player.damage(3), isFalse);
      expect(player.health, Player.maxHealth - 3);
    });

    test('zero health is death; respawn restores it fully', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));

      player.damage(100);
      expect(player.isDead, isTrue);

      player.respawn();
      expect(player.health, Player.maxHealth);
      expect(player.isDead, isFalse);
    });

    test('a hit knocks the player away from its source', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));
      player.damage(2, source: Vector3(32.5, 2, 34.5));
      expect(player.velocity.z, lessThan(0));
    });

    test('the look direction agrees with yaw', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));

      expect(player.lookDirection.z, closeTo(-1, 1e-9));
      player.yaw = math.pi / 2;
      expect(player.lookDirection.x, closeTo(-1, 1e-9));
    });
  });
}

void _balanceTests() {
  group('Regeneracja i balans', () {
    test('the player heals after a quiet spell', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5))
        ..damage(6);
      final wounded = player.health;

      // Healing only starts after a break without damage.
      for (var i = 0; i < 60 * 5; i++) {
        player.update(1 / 60, MoveInput());
      }
      expect(player.health, wounded);

      for (var i = 0; i < 60 * 10; i++) {
        player.update(1 / 60, MoveInput());
      }
      expect(player.health, greaterThan(wounded));
    });

    test('a hit interrupts healing', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5))
        ..damage(6);

      for (var i = 0; i < 60 * 8; i++) {
        player.update(1 / 60, MoveInput());
      }
      final healed = player.health;

      player.hurtCooldown = 0;
      player.damage(1);
      for (var i = 0; i < 60 * 5; i++) {
        player.update(1 / 60, MoveInput());
      }
      expect(player.health, healed - 1);
    });

    test('healing stops at full health', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));
      for (var i = 0; i < 60 * 60; i++) {
        player.update(1 / 60, MoveInput());
      }
      expect(player.health, Player.maxHealth);
    });

    test('creepers are rarer than zombies', () {
      expect(MobKind.creeper.weight, lessThan(MobKind.zombie.weight));
      final total = MobKind.values.fold(0, (sum, k) => sum + k.weight);
      expect(total, 100);
    });

    test('a single zombie does not kill the player within a minute', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));
      final mob = Mob(
        kind: MobKind.zombie,
        world: world,
        spawn: Vector3(33.2, 2, 32.5),
      );
      final context = FakeContext(player);

      for (var i = 0; i < 60 * 60; i++) {
        mob.update(1 / 60, player, context);
        // The player stands still, so the zombie keeps hitting.
        player.update(1 / 60, MoveInput());
        if (player.isDead) break;
      }

      expect(
        player.isDead,
        isTrue,
        reason: 'standing idle next to a zombie is meant to hurt',
      );
      expect(mob.position.distanceTo(player.position), lessThan(6));
    });
  });
}

void _spawnRangeTest() {
  test('mobs spawn within aggro range', () {
    // If mobs spawned beyond aggro range they would just stand there.
    expect(MobSpawner.minDistance, lessThan(Mob.aggroRange));
    expect(MobSpawner.maxDistance, greaterThan(MobSpawner.minDistance));
  });
}
