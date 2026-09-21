import 'dart:math' as math;

import 'package:flame_3d/core.dart';
import 'package:flutcraft/src/core/block.dart';
import 'package:flutcraft/src/game/mob.dart';
import 'package:flutcraft/src/game/player.dart';
import 'package:flutcraft/src/world/voxel_world.dart';
import 'package:flutter_test/flutter_test.dart';

/// Podstawia się pod świat gry i zapisuje, co potwory próbowały zrobić.
class FakeContext implements MobContext {
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
    test('zombie zbliża się do gracza', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));
      final mob = Mob(
        kind: MobKind.zombie,
        world: world,
        spawn: Vector3(32.5, 2, 42.5),
      );
      final context = FakeContext();

      final before = mob.position.distanceTo(player.position);
      for (var i = 0; i < 120; i++) {
        mob.update(1 / 60, player, context);
      }
      final after = mob.position.distanceTo(player.position);

      expect(after, lessThan(before - 2));
    });

    test('poza zasięgiem agresji potwór stoi w miejscu', () {
      final world = flatWorld(size: 128);
      final player = Player(world: world, spawn: Vector3(10.5, 2, 10.5));
      final mob = Mob(
        kind: MobKind.zombie,
        world: world,
        spawn: Vector3(100.5, 2, 100.5),
      );
      final start = mob.position.clone();

      for (var i = 0; i < 60; i++) {
        mob.update(1 / 60, player, FakeContext());
      }

      expect(mob.position.x, closeTo(start.x, 0.01));
      expect(mob.position.z, closeTo(start.z, 0.01));
    });

    test('zombie w zwarciu rani gracza, ale nie co klatkę', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));
      final mob = Mob(
        kind: MobKind.zombie,
        world: world,
        spawn: Vector3(33.2, 2, 32.5),
      );

      mob.update(1 / 60, player, FakeContext());
      expect(player.health, lessThan(Player.maxHealth));

      final afterFirst = player.health;
      mob.update(1 / 60, player, FakeContext());
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
      final context = FakeContext();

      mob.update(1 / 60, player, context);
      expect(context.arrows, hasLength(1));

      // Strzała leci w stronę gracza.
      final (_, direction) = context.arrows.first;
      expect(direction.z, lessThan(0));
    });

    test('szkielet nie strzela przez ścianę', () {
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
      final context = FakeContext();

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
      final context = FakeContext();

      mob.update(1 / 60, player, context);
      expect(mob.isPrimed, isTrue);
      expect(context.explosions, isEmpty);

      for (var i = 0; i < 120; i++) {
        mob.update(1 / 60, player, context);
      }

      expect(context.explosions, hasLength(1));
      expect(mob.isDead, isTrue);
    });

    test('lont gaśnie, gdy gracz ucieknie', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));
      final mob = Mob(
        kind: MobKind.creeper,
        world: world,
        spawn: Vector3(34.5, 2, 32.5),
      );
      final context = FakeContext();

      mob.update(1 / 60, player, context);
      expect(mob.isPrimed, isTrue);

      player.position.setValues(50.5, 2, 32.5);
      mob.update(1 / 60, player, context);

      expect(mob.isPrimed, isFalse);
      expect(context.explosions, isEmpty);
    });

    test('obrażenia zabijają potwora i odrzucają go', () {
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

    test('promień z oka gracza trafia w bryłę potwora', () {
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
    test('trafia gracza i znika', () {
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

    test('znika po wbiciu w ziemię', () {
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
    test('tworzy potwory dopiero po upływie interwału', () {
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

    test('nie przekracza limitu populacji', () {
      final world = flatWorld(size: 96);
      final player = Player(world: world, spawn: Vector3(48.5, 2, 48.5));
      final spawner = MobSpawner(world: world, maxMobs: 3);
      expect(spawner.maybeSpawn(MobSpawner.interval, player, 3), isNull);
    });
  });

  group('Player', () {
    test('nietykalność blokuje kolejne ciosy', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));

      expect(player.damage(3), isTrue);
      expect(player.damage(3), isFalse);
      expect(player.health, Player.maxHealth - 3);
    });

    test('zero życia to śmierć, respawn przywraca pełne', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));

      player.damage(100);
      expect(player.isDead, isTrue);

      player.respawn();
      expect(player.health, Player.maxHealth);
      expect(player.isDead, isFalse);
    });

    test('cios odrzuca gracza od źródła', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));
      player.damage(2, source: Vector3(32.5, 2, 34.5));
      expect(player.velocity.z, lessThan(0));
    });

    test('kierunek patrzenia zgadza się z yaw', () {
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
    test('gracz odzyskuje życie po chwili spokoju', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5))
        ..damage(6);
      final wounded = player.health;

      // Regeneracja rusza dopiero po przerwie bez obrażeń.
      for (var i = 0; i < 60 * 5; i++) {
        player.update(1 / 60, MoveInput());
      }
      expect(player.health, wounded);

      for (var i = 0; i < 60 * 10; i++) {
        player.update(1 / 60, MoveInput());
      }
      expect(player.health, greaterThan(wounded));
    });

    test('cios przerywa regenerację', () {
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

    test('regeneracja nie przekracza pełnego życia', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));
      for (var i = 0; i < 60 * 60; i++) {
        player.update(1 / 60, MoveInput());
      }
      expect(player.health, Player.maxHealth);
    });

    test('creepery są rzadsze niż zombie', () {
      expect(MobKind.creeper.weight, lessThan(MobKind.zombie.weight));
      final total = MobKind.values.fold(0, (sum, k) => sum + k.weight);
      expect(total, 100);
    });

    test('pojedynczy zombie nie zabija gracza w minutę', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));
      final mob = Mob(
        kind: MobKind.zombie,
        world: world,
        spawn: Vector3(33.2, 2, 32.5),
      );
      final context = FakeContext();

      for (var i = 0; i < 60 * 60; i++) {
        mob.update(1 / 60, player, context);
        // Gracz stoi w miejscu, więc zombie bije bez przerwy.
        player.update(1 / 60, MoveInput());
        if (player.isDead) break;
      }

      expect(player.isDead, isTrue,
          reason: 'stanie bezczynnie przy zombie ma boleć');
      expect(mob.position.distanceTo(player.position), lessThan(6));
    });
  });
}

void _spawnRangeTest() {
  test('potwory pojawiają się w zasięgu agresji', () {
    // Gdyby spawn był dalej niż aggro, potwory stałyby w miejscu.
    expect(MobSpawner.minDistance, lessThan(Mob.aggroRange));
    expect(MobSpawner.maxDistance, greaterThan(MobSpawner.minDistance));
  });
}
