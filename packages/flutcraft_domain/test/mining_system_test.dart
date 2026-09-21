import 'dart:math';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

GameState stateWith({ItemType? held}) {
  final world = VoxelWorld(sizeX: 16, sizeY: 16, sizeZ: 16);
  for (var z = 0; z < 16; z++) {
    for (var x = 0; x < 16; x++) {
      world.setRaw(x, 0, z, BlockType.bedrock);
      world.setRaw(x, 1, z, BlockType.stone);
    }
  }
  final inventory = Inventory();
  if (held != null) inventory.add(held);
  return GameState.solo(
    world: world,
    player: Player(world: world, spawn: Vector3(8.5, 2, 8.5)),
    inventory: inventory,
  );
}

RayHit hitAt(GameState state, int x, int y, int z) => RayHit(
  x: x,
  y: y,
  z: z,
  block: state.world.blockAt(x, y, z),
  nx: 0,
  ny: 1,
  nz: 0,
  distance: 2,
);

/// A whole swing, the way a loop that rules the world runs one.
///
/// A client calls [MiningSystem.accumulate] alone and stops there; this is
/// the half that only a server is allowed to carry out, added back.
List<GameEvent> swing(
  MiningSystem system,
  GameState state, {
  required bool active,
  double dt = 1 / 60,
}) {
  final it = state.solo;
  switch (system.accumulate(it, dt, active: active)) {
    case SwingContinues():
      return const [];
    case MobStruck(:final mob):
      system.strike(it, mob);
      return const [];
    case BlockGivesWay(:final hit):
      return system.breakBlockAt(state, it, hit);
  }
}

void main() {
  group('breakTime', () {
    test('the right tool digs faster than a bare hand', () {
      final bare = MiningSystem.breakTime(BlockType.stone, null);
      final wooden = MiningSystem.breakTime(
        BlockType.stone,
        ItemType.woodenPickaxe,
      );
      expect(wooden, lessThan(bare));
    });

    test('a higher tier digs faster', () {
      final wooden = MiningSystem.breakTime(
        BlockType.stone,
        ItemType.woodenPickaxe,
      );
      final iron = MiningSystem.breakTime(
        BlockType.stone,
        ItemType.ironPickaxe,
      );
      expect(iron, lessThan(wooden));
    });

    test('the wrong tool does not help', () {
      final bare = MiningSystem.breakTime(BlockType.stone, null);
      final sword = MiningSystem.breakTime(BlockType.stone, ItemType.ironSword);
      expect(sword, bare);
    });

    test('a harder block takes longer', () {
      expect(
        MiningSystem.breakTime(BlockType.dirt, null),
        lessThan(MiningSystem.breakTime(BlockType.stone, null)),
      );
    });

    test('even the best tool has a floor', () {
      expect(
        MiningSystem.breakTime(BlockType.leaves, ItemType.ironPickaxe),
        greaterThanOrEqualTo(0.08),
      );
    });
  });

  group('MiningSystem', () {
    late MiningSystem system;

    setUp(() => system = MiningSystem(random: Random(1)));

    test('letting go of the button resets progress', () {
      final state = stateWith();
      state.solo
        ..aim = BlockTarget(hitAt(stateWith(), 8, 1, 8))
        ..breakProgress = 0.7;
      swing(system, state, active: false);
      expect(state.solo.breakProgress, 0);
    });

    test('mining progresses and eventually removes the block', () {
      final state = stateWith(held: ItemType.woodenPickaxe);
      state.solo.aim = BlockTarget(hitAt(state, 8, 1, 8));

      var events = <GameEvent>[];
      for (var i = 0; i < 300 && state.world.isSolid(8, 1, 8); i++) {
        events = swing(system, state, active: true);
      }

      expect(state.world.blockAt(8, 1, 8), BlockType.air);
      expect(events.whereType<BlockBroken>(), hasLength(1));
    });

    test(
      'stone punched by hand breaks with no drop and reports a weak tool',
      () {
        final state = stateWith();
        state.solo.aim = BlockTarget(hitAt(state, 8, 1, 8));

        var events = <GameEvent>[];
        for (var i = 0; i < 600 && state.world.isSolid(8, 1, 8); i++) {
          events = swing(system, state, active: true);
        }

        expect(state.world.blockAt(8, 1, 8), BlockType.air);
        expect(events.whereType<ToolTooWeak>(), hasLength(1));
        expect(state.solo.inventory.isEmpty, isTrue);
      },
    );

    test('drop trafia do ekwipunku', () {
      final state = stateWith(held: ItemType.stonePickaxe);
      state.solo.aim = BlockTarget(hitAt(state, 8, 1, 8));
      for (var i = 0; i < 300 && state.world.isSolid(8, 1, 8); i++) {
        swing(system, state, active: true);
      }
      expect(state.solo.inventory.countOf(ItemType.cobblestone), 1);
    });

    test('a hit on a mob respects the cooldown', () {
      final state = stateWith(held: ItemType.ironSword);
      final mob = Mob(
        kind: MobKind.zombie,
        world: state.world,
        spawn: Vector3(8.5, 2, 6.5),
      );
      state.solo.aim = MobTarget(mob, 2);

      swing(system, state, active: true);
      final afterFirst = mob.health;
      expect(afterFirst, lessThan(MobKind.zombie.maxHealth));

      swing(system, state, active: true);
      expect(
        mob.health,
        afterFirst,
        reason: 'the cooldown blocked the second hit',
      );

      for (var i = 0; i < 40; i++) {
        swing(system, state, active: true);
      }
      expect(mob.health, lessThan(afterFirst));
    });

    test('a better weapon deals more damage', () {
      double damageWith(ItemType? weapon) {
        final state = stateWith(held: weapon);
        final mob = Mob(
          kind: MobKind.zombie,
          world: state.world,
          spawn: Vector3(8.5, 2, 6.5),
        );
        state.solo.aim = MobTarget(mob, 2);
        swing(MiningSystem(random: Random(1)), state, active: true);
        return MobKind.zombie.maxHealth - mob.health;
      }

      expect(
        damageWith(ItemType.ironSword),
        greaterThan(damageWith(ItemType.woodenPickaxe)),
      );
      expect(damageWith(ItemType.woodenPickaxe), greaterThan(damageWith(null)));
    });

    test('aiming at nothing does nothing', () {
      final state = stateWith();
      expect(swing(system, state, active: true), isEmpty);
    });

    test('bedrock cannot be broken', () {
      final state = stateWith(held: ItemType.ironPickaxe);
      state.solo.aim = BlockTarget(hitAt(state, 8, 0, 8));
      for (var i = 0; i < 600; i++) {
        swing(system, state, active: true);
      }
      expect(state.world.blockAt(8, 0, 8), BlockType.bedrock);
    });

    test('zbicie pieca usuwa go z rejestru', () {
      final state = stateWith(held: ItemType.stonePickaxe);
      state.world.setBlock(8, 1, 8, BlockType.furnace);
      state.furnaces.open(const BlockPos(8, 1, 8));
      state.solo.aim = BlockTarget(hitAt(state, 8, 1, 8));

      for (var i = 0; i < 600 && state.world.isSolid(8, 1, 8); i++) {
        swing(system, state, active: true);
      }
      expect(state.furnaces.isEmpty, isTrue);
    });
  });
}
