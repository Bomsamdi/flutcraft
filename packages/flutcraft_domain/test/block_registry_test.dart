import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';

void main() {
  group('BlockRegistry', () {
    const registry = BlockRegistry.standard;

    test('a table opens crafting, a furnace opens the furnace', () {
      expect(
        registry.interactionFor(BlockType.craftingTable),
        isA<OpenCraftingTable>(),
      );
      expect(registry.interactionFor(BlockType.furnace), isA<OpenFurnace>());
    });

    test('both furnace variants lead to the same screen', () {
      expect(registry.interactionFor(BlockType.furnaceLit), isA<OpenFurnace>());
    });

    test('ordinary blocks do nothing', () {
      for (final block in [BlockType.stone, BlockType.dirt, BlockType.log]) {
        expect(registry.isInteractive(block), isFalse, reason: block.name);
        expect(registry.interactionFor(block), isNull);
      }
    });

    test('an empty registry has no interactions at all', () {
      const empty = BlockRegistry({});
      expect(empty.isInteractive(BlockType.furnace), isFalse);
    });

    test('an exhaustive switch over the interactions', () {
      String describe(BlockInteraction i) => switch (i) {
        OpenCraftingTable() => 'crafting',
        OpenFurnace() => 'furnace',
      };
      expect(
        describe(registry.interactionFor(BlockType.craftingTable)!),
        'crafting',
      );
      expect(describe(registry.interactionFor(BlockType.furnace)!), 'furnace');
    });
  });

  group('Warianty pieca opisane danymi', () {
    test('a furnace points at its lit variant and back', () {
      expect(BlockType.furnace.litVariant, BlockType.furnaceLit);
      expect(BlockType.furnaceLit.unlitVariant, BlockType.furnace);
    });

    test('a lit furnace has no further lit variant', () {
      expect(BlockType.furnaceLit.litVariant, isNull);
      expect(BlockType.furnace.unlitVariant, isNull);
    });

    test('only the furnace has two burning states', () {
      final withVariants = BlockType.values
          .where((b) => b.hasLitVariant)
          .toSet();
      expect(withVariants, {BlockType.furnace, BlockType.furnaceLit});
    });

    test('ordinary blocks have no variants', () {
      expect(BlockType.stone.litVariant, isNull);
      expect(BlockType.stone.unlitVariant, isNull);
      expect(BlockType.stone.hasLitVariant, isFalse);
    });
  });
}
