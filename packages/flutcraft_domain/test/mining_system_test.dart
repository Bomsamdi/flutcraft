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
  return GameState(
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

void main() {
  group('breakTime', () {
    test('pasujące narzędzie kopie szybciej niż ręka', () {
      final bare = MiningSystem.breakTime(BlockType.stone, null);
      final wooden =
          MiningSystem.breakTime(BlockType.stone, ItemType.woodenPickaxe);
      expect(wooden, lessThan(bare));
    });

    test('lepszy poziom narzędzia kopie szybciej', () {
      final wooden =
          MiningSystem.breakTime(BlockType.stone, ItemType.woodenPickaxe);
      final iron =
          MiningSystem.breakTime(BlockType.stone, ItemType.ironPickaxe);
      expect(iron, lessThan(wooden));
    });

    test('niepasujące narzędzie nie pomaga', () {
      final bare = MiningSystem.breakTime(BlockType.stone, null);
      final sword =
          MiningSystem.breakTime(BlockType.stone, ItemType.ironSword);
      expect(sword, bare);
    });

    test('twardszy blok trwa dłużej', () {
      expect(
        MiningSystem.breakTime(BlockType.dirt, null),
        lessThan(MiningSystem.breakTime(BlockType.stone, null)),
      );
    });

    test('nawet najlepsze narzędzie ma dolny próg', () {
      expect(
        MiningSystem.breakTime(BlockType.leaves, ItemType.ironPickaxe),
        greaterThanOrEqualTo(0.08),
      );
    });
  });

  group('MiningSystem', () {
    late MiningSystem system;

    setUp(() => system = MiningSystem(random: Random(1)));

    test('bez trzymania przycisku postęp wraca do zera', () {
      final state = stateWith()
        ..aim = BlockTarget(hitAt(stateWith(), 8, 1, 8))
        ..breakProgress = 0.7;
      system.update(state, 1 / 60, active: false);
      expect(state.breakProgress, 0);
    });

    test('kopanie postępuje i w końcu usuwa blok', () {
      final state = stateWith(held: ItemType.woodenPickaxe);
      state.aim = BlockTarget(hitAt(state, 8, 1, 8));

      var events = <GameEvent>[];
      for (var i = 0; i < 300 && state.world.isSolid(8, 1, 8); i++) {
        events = system.update(state, 1 / 60, active: true);
      }

      expect(state.world.blockAt(8, 1, 8), BlockType.air);
      expect(events.whereType<BlockBroken>(), hasLength(1));
    });

    test('kamień bity ręką znika bez dropu i zgłasza słabe narzędzie', () {
      final state = stateWith();
      state.aim = BlockTarget(hitAt(state, 8, 1, 8));

      var events = <GameEvent>[];
      for (var i = 0; i < 600 && state.world.isSolid(8, 1, 8); i++) {
        events = system.update(state, 1 / 60, active: true);
      }

      expect(state.world.blockAt(8, 1, 8), BlockType.air);
      expect(events.whereType<ToolTooWeak>(), hasLength(1));
      expect(state.inventory.isEmpty, isTrue);
    });

    test('drop trafia do ekwipunku', () {
      final state = stateWith(held: ItemType.stonePickaxe);
      state.aim = BlockTarget(hitAt(state, 8, 1, 8));
      for (var i = 0; i < 300 && state.world.isSolid(8, 1, 8); i++) {
        system.update(state, 1 / 60, active: true);
      }
      expect(state.inventory.countOf(ItemType.cobblestone), 1);
    });

    test('cios w potwora respektuje cooldown', () {
      final state = stateWith(held: ItemType.ironSword);
      final mob = Mob(
        kind: MobKind.zombie,
        world: state.world,
        spawn: Vector3(8.5, 2, 6.5),
      );
      state.aim = MobTarget(mob, 2);

      system.update(state, 1 / 60, active: true);
      final afterFirst = mob.health;
      expect(afterFirst, lessThan(MobKind.zombie.maxHealth));

      system.update(state, 1 / 60, active: true);
      expect(mob.health, afterFirst, reason: 'drugi cios blokuje cooldown');

      for (var i = 0; i < 40; i++) {
        system.update(state, 1 / 60, active: true);
      }
      expect(mob.health, lessThan(afterFirst));
    });

    test('lepsza broń zadaje więcej obrażeń', () {
      double damageWith(ItemType? weapon) {
        final state = stateWith(held: weapon);
        final mob = Mob(
          kind: MobKind.zombie,
          world: state.world,
          spawn: Vector3(8.5, 2, 6.5),
        );
        state.aim = MobTarget(mob, 2);
        MiningSystem(random: Random(1)).update(state, 1 / 60, active: true);
        return MobKind.zombie.maxHealth - mob.health;
      }

      expect(damageWith(ItemType.ironSword),
          greaterThan(damageWith(ItemType.woodenPickaxe)));
      expect(damageWith(ItemType.woodenPickaxe), greaterThan(damageWith(null)));
    });

    test('celowanie w nic nie robi nic', () {
      final state = stateWith();
      expect(system.update(state, 1 / 60, active: true), isEmpty);
    });

    test('bedrock nie daje się zbić', () {
      final state = stateWith(held: ItemType.ironPickaxe);
      state.aim = BlockTarget(hitAt(state, 8, 0, 8));
      for (var i = 0; i < 600; i++) {
        system.update(state, 1 / 60, active: true);
      }
      expect(state.world.blockAt(8, 0, 8), BlockType.bedrock);
    });

    test('zbicie pieca usuwa go z rejestru', () {
      final state = stateWith(held: ItemType.stonePickaxe);
      state.world.setBlock(8, 1, 8, BlockType.furnace);
      state.furnaces.open(const BlockPos(8, 1, 8));
      state.aim = BlockTarget(hitAt(state, 8, 1, 8));

      for (var i = 0; i < 600 && state.world.isSolid(8, 1, 8); i++) {
        system.update(state, 1 / 60, active: true);
      }
      expect(state.furnaces.isEmpty, isTrue);
    });
  });
}
