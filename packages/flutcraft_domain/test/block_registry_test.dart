import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';

void main() {
  group('BlockRegistry', () {
    const registry = BlockRegistry.standard;

    test('stół otwiera crafting, piec otwiera piec', () {
      expect(
        registry.interactionFor(BlockType.craftingTable),
        isA<OpenCraftingTable>(),
      );
      expect(registry.interactionFor(BlockType.furnace), isA<OpenFurnace>());
    });

    test('oba warianty pieca prowadzą do tego samego ekranu', () {
      expect(registry.interactionFor(BlockType.furnaceLit), isA<OpenFurnace>());
    });

    test('zwykłe bloki nic nie robią', () {
      for (final block in [BlockType.stone, BlockType.dirt, BlockType.log]) {
        expect(registry.isInteractive(block), isFalse, reason: block.name);
        expect(registry.interactionFor(block), isNull);
      }
    });

    test('pusty rejestr nie ma żadnych interakcji', () {
      const empty = BlockRegistry({});
      expect(empty.isInteractive(BlockType.furnace), isFalse);
    });

    test('wyczerpujący switch po interakcji', () {
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
    test('piec wskazuje na swój zapalony wariant i z powrotem', () {
      expect(BlockType.furnace.litVariant, BlockType.furnaceLit);
      expect(BlockType.furnaceLit.unlitVariant, BlockType.furnace);
    });

    test('zapalony piec nie ma dalszego wariantu zapalonego', () {
      expect(BlockType.furnaceLit.litVariant, isNull);
      expect(BlockType.furnace.unlitVariant, isNull);
    });

    test('tylko piec ma dwa stany palenia', () {
      final withVariants = BlockType.values
          .where((b) => b.hasLitVariant)
          .toSet();
      expect(withVariants, {BlockType.furnace, BlockType.furnaceLit});
    });

    test('zwykłe bloki nie mają wariantów', () {
      expect(BlockType.stone.litVariant, isNull);
      expect(BlockType.stone.unlitVariant, isNull);
      expect(BlockType.stone.hasLitVariant, isFalse);
    });
  });
}
