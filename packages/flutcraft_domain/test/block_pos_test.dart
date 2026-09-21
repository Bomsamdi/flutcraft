import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('BlockPos', () {
    test('equal coordinates mean equal keys', () {
      expect(const BlockPos(1, 2, 3), const BlockPos(1, 2, 3));
      expect(const BlockPos(1, 2, 3).hashCode, const BlockPos(1, 2, 3).hashCode);
    });

    test('order of coordinates matters', () {
      expect(const BlockPos(1, 2, 3), isNot(const BlockPos(3, 2, 1)));
    });

    test('works as a map key', () {
      final map = <BlockPos, String>{const BlockPos(4, 5, 6): 'furnace'};
      expect(map[const BlockPos(4, 5, 6)], 'furnace');
      expect(map[const BlockPos(4, 5, 7)], isNull);
    });

    test('negative coordinates stay distinct', () {
      expect(const BlockPos(-1, 0, 0), isNot(const BlockPos(1, 0, 0)));
      expect(const BlockPos(0, -1, 0), isNot(const BlockPos(0, 1, 0)));
    });

    test('from a point, fractional coordinates round down', () {
      expect(BlockPos.of(Vector3(4.9, 5.1, -0.2)), const BlockPos(4, 5, -1));
    });

    test('centre sits half a block from the corner', () {
      final centre = const BlockPos(2, 3, 4).center;
      expect(centre.x, 2.5);
      expect(centre.y, 3.5);
      expect(centre.z, 4.5);
    });

    test('offset moves by the given deltas', () {
      expect(const BlockPos(1, 1, 1).offset(0, -1, 2), const BlockPos(1, 0, 3));
    });
  });

  group('FurnaceRegistry', () {
    test('open returns the same furnace for the same position', () {
      final registry = FurnaceRegistry();
      final first = registry.open(const BlockPos(1, 2, 3));
      first.fuel = ItemStack(ItemType.coal, 2);

      final again = registry.open(const BlockPos(1, 2, 3));
      expect(identical(first, again), isTrue);
      expect(again.fuel?.count, 2);
      expect(registry.length, 1);
    });

    test('neighbouring furnaces stay separate', () {
      final registry = FurnaceRegistry()
        ..open(const BlockPos(1, 2, 3))
        ..open(const BlockPos(1, 2, 4));
      expect(registry.length, 2);
    });

    test('remove returns contents so the player can get them back', () {
      final registry = FurnaceRegistry();
      registry.open(const BlockPos(0, 0, 0)).input =
          ItemStack(ItemType.rawIron, 3);

      final removed = registry.remove(const BlockPos(0, 0, 0));
      expect(removed?.input?.count, 3);
      expect(registry.isEmpty, isTrue);
    });

    test('tick reports only furnaces whose lit state flipped', () {
      final registry = FurnaceRegistry();
      final lighting = registry.open(const BlockPos(1, 0, 0))
        ..input = ItemStack(ItemType.rawIron)
        ..fuel = ItemStack(ItemType.coal);
      registry.open(const BlockPos(2, 0, 0)); // idle, stays unlit

      expect(registry.tick(0.1), [const BlockPos(1, 0, 0)]);
      expect(lighting.isLit, isTrue);

      // Already lit: no further change to report.
      expect(registry.tick(0.1), isEmpty);
    });

    test('a furnace that burns out is reported once', () {
      final registry = FurnaceRegistry();
      registry.open(const BlockPos(5, 5, 5))
        ..input = ItemStack(ItemType.rawIron, 1)
        ..fuel = ItemStack(ItemType.coal, 1);

      expect(registry.tick(0.1), isNotEmpty);
      // Coal burns for 8 s; step past it in one go.
      for (var i = 0; i < 100; i++) {
        registry.tick(0.1);
      }
      final flips = <BlockPos>[];
      for (var i = 0; i < 10; i++) {
        flips.addAll(registry.tick(0.1));
      }
      expect(flips, isEmpty, reason: 'burnt-out furnace should stay unlit');
      expect(registry[const BlockPos(5, 5, 5)]!.isLit, isFalse);
    });
  });
}
