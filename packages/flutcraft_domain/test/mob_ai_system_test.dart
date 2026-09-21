import 'dart:math';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

class SilentContext implements MobTickContext {
  SilentContext(this.player);

  @override
  final Player player;

  @override
  void spawnArrow(Vector3 from, Vector3 direction) {}

  @override
  void explode(Vector3 at, double radius, int maxDamage) {}
}

GameState flatState({int size = 96}) {
  final world = VoxelWorld(sizeX: size, sizeY: 24, sizeZ: size);
  for (var z = 0; z < size; z++) {
    for (var x = 0; x < size; x++) {
      world.setRaw(x, 0, z, BlockType.bedrock);
      world.setRaw(x, 1, z, BlockType.stone);
    }
  }
  return GameState(
    world: world,
    player: Player(world: world, spawn: Vector3(48.5, 2, 48.5)),
    inventory: Inventory(),
  );
}

void main() {
  group('MobAiSystem', () {
    late GameState state;
    late MobAiSystem system;
    late SilentContext context;

    setUp(() {
      state = flatState();
      context = SilentContext(state.player);
      system = MobAiSystem(
        spawner: MobSpawner(world: state.world, seed: 3),
        random: Random(3),
      );
    });

    test('po upływie interwału dokłada potwora', () {
      expect(state.mobs, isEmpty);
      system.update(state, MobSpawner.interval, context);
      expect(state.mobs, hasLength(1));
    });

    test('martwy potwór znika i zostawia łup', () {
      final mob = Mob(
        kind: MobKind.skeleton,
        world: state.world,
        spawn: Vector3(48.5, 2, 46.5),
      )..health = 0;
      state.mobs.add(mob);

      final events = system.update(state, 1 / 60, context);

      expect(state.mobs, isNot(contains(mob)));
      expect(events.whereType<MobKilled>(), hasLength(1));
      expect(state.inventory.countOf(ItemType.bone), greaterThan(0));
    });

    test('zdarzenie niesie gatunek i łup', () {
      state.mobs.add(
        Mob(
          kind: MobKind.spider,
          world: state.world,
          spawn: Vector3(48.5, 2, 46.5),
        )..health = 0,
      );

      final killed =
          system.update(state, 1 / 60, context).whereType<MobKilled>().single;

      expect(killed.kind, MobKind.spider);
      expect(killed.loot.map((d) => d.type), contains(ItemType.string));
    });

    test('żywe potwory zostają', () {
      state.mobs.add(
        Mob(
          kind: MobKind.zombie,
          world: state.world,
          spawn: Vector3(48.5, 2, 46.5),
        ),
      );
      system.update(state, 1 / 60, context);
      expect(state.mobs, hasLength(1));
    });

    test('despawnAll czyści świat', () {
      state.mobs.addAll([
        Mob(kind: MobKind.zombie, world: state.world, spawn: Vector3(48.5, 2, 46)),
        Mob(kind: MobKind.spider, world: state.world, spawn: Vector3(48.5, 2, 45)),
      ]);
      system.despawnAll(state);
      expect(state.mobs, isEmpty);
    });
  });

  group('ProjectileSystem', () {
    const system = ProjectileSystem();

    test('strzała wbita w ziemię znika', () {
      final state = flatState();
      state.arrows.add(
        Arrow(
          world: state.world,
          spawn: Vector3(48.5, 4, 48.5),
          direction: Vector3(0, -1, 0),
        ),
      );

      for (var i = 0; i < 120 && state.arrows.isNotEmpty; i++) {
        system.update(state, 1 / 60);
      }
      expect(state.arrows, isEmpty);
    });

    test('strzała trafiająca gracza rani go i znika', () {
      final state = flatState();
      state.arrows.add(
        Arrow(
          world: state.world,
          spawn: Vector3(48.5, 3.0, 51.0),
          direction: Vector3(0, 0, -1),
        ),
      );

      for (var i = 0; i < 60 && state.arrows.isNotEmpty; i++) {
        system.update(state, 1 / 60);
      }
      expect(state.arrows, isEmpty);
      expect(state.player.health, lessThan(Player.maxHealth));
    });

    test('clear usuwa wszystkie strzały', () {
      final state = flatState();
      state.arrows.add(
        Arrow(
          world: state.world,
          spawn: Vector3(48.5, 4, 48.5),
          direction: Vector3(1, 0, 0),
        ),
      );
      system.clear(state);
      expect(state.arrows, isEmpty);
    });
  });

  group('FurnaceSystem', () {
    const system = FurnaceSystem();

    test('rozpalony piec zmienia blok na świecący', () {
      final state = flatState(size: 16);
      state.world.setBlock(8, 2, 8, BlockType.furnace);
      state.furnaces.open(const BlockPos(8, 2, 8))
        ..input = const ItemStack(ItemType.rawIron)
        ..fuel = const ItemStack(ItemType.coal);

      system.update(state, 0.1);

      expect(state.world.blockAt(8, 2, 8), BlockType.furnaceLit);
    });

    test('wygaszony piec wraca do zwykłego bloku', () {
      final state = flatState(size: 16);
      state.world.setBlock(8, 2, 8, BlockType.furnace);
      state.furnaces.open(const BlockPos(8, 2, 8))
        ..input = const ItemStack(ItemType.rawIron)
        ..fuel = const ItemStack(ItemType.coal);

      for (var i = 0; i < 200; i++) {
        system.update(state, 0.1);
      }
      expect(state.world.blockAt(8, 2, 8), BlockType.furnace);
    });

    test('bez pieców nic nie robi', () {
      final state = flatState(size: 16);
      expect(() => system.update(state, 0.1), returnsNormally);
    });
  });
}
