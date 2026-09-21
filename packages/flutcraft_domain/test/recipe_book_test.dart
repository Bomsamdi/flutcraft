import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';

Recipe recipeFor(ItemType output) =>
    kRecipes.firstWhere((r) => r.output == output);

void main() {
  group('Koszt przepisu', () {
    test('a pickaxe is three of the material and two sticks', () {
      expect(recipeFor(ItemType.stonePickaxe).cost, {
        ItemType.cobblestone: 3,
        ItemType.stick: 2,
      });
    });

    test('a furnace is eight cobble, since the middle stays empty', () {
      expect(recipeFor(ItemType.furnace).cost, {ItemType.cobblestone: 8});
    });

    test('a shapeless recipe counts its ingredients too', () {
      expect(recipeFor(ItemType.planks).cost, {ItemType.log: 1});
    });

    test('sticks need two planks', () {
      expect(recipeFor(ItemType.stick).cost, {ItemType.planks: 2});
    });
  });

  group('needsTable', () {
    test('table and sticks fit in the inventory grid', () {
      expect(recipeFor(ItemType.craftingTable).needsTable, isFalse);
      expect(recipeFor(ItemType.stick).needsTable, isFalse);
      expect(recipeFor(ItemType.planks).needsTable, isFalse);
    });

    test('tools and the furnace need a table', () {
      expect(recipeFor(ItemType.woodenPickaxe).needsTable, isTrue);
      expect(recipeFor(ItemType.furnace).needsTable, isTrue);
      expect(recipeFor(ItemType.ironSword).needsTable, isTrue);
    });

    test('a wooden sword is three cells tall, so it needs a table', () {
      // The pattern has three rows; the inventory grid has two.
      expect(recipeFor(ItemType.woodenSword).height, 3);
      expect(recipeFor(ItemType.woodenSword).needsTable, isTrue);
    });
  });

  group('canCraft', () {
    test('it sees when ingredients are missing', () {
      final inventory = Inventory()..add(ItemType.cobblestone, 2);
      expect(canCraft(recipeFor(ItemType.stonePickaxe), inventory), isFalse);
    });

    test('exactly enough is enough', () {
      final inventory = Inventory()
        ..add(ItemType.cobblestone, 3)
        ..add(ItemType.stick, 2);
      expect(canCraft(recipeFor(ItemType.stonePickaxe), inventory), isTrue);
    });

    test('one ingredient short blocks the recipe', () {
      final inventory = Inventory()
        ..add(ItemType.cobblestone, 3)
        ..add(ItemType.stick, 1);
      expect(canCraft(recipeFor(ItemType.stonePickaxe), inventory), isFalse);
    });

    test('ingredients spread over several stacks still count', () {
      final inventory = Inventory()..add(ItemType.cobblestone, 70);
      expect(inventory.countOf(ItemType.cobblestone), 70);
      expect(canCraft(recipeFor(ItemType.furnace), inventory), isTrue);
    });

    test('an empty inventory allows nothing at all', () {
      final inventory = Inventory();
      for (final recipe in kRecipes) {
        expect(
          canCraft(recipe, inventory),
          isFalse,
          reason: recipe.output.name,
        );
      }
    });
  });

  _noSelfLoopTest();
  _missingTests();

  group('The book is consistent', () {
    test('every recipe has a positive output and a non-empty cost', () {
      for (final recipe in kRecipes) {
        expect(recipe.outputCount, greaterThan(0), reason: recipe.output.name);
        expect(recipe.cost, isNotEmpty, reason: recipe.output.name);
      }
    });

    test('every listed smelt actually produces something', () {
      for (final input in kSmeltable) {
        expect(smeltResult(input), isNotNull, reason: input.name);
      }
    });

    test('every recipe can really be laid out on a grid', () {
      for (final recipe in kRecipes) {
        final size = recipe.needsTable ? 3 : 2;
        final grid = CraftingGrid(size);

        if (recipe.shapeless) {
          for (final (i, item) in recipe.ingredients.indexed) {
            grid[i] = ItemStack(item);
          }
        } else {
          for (var row = 0; row < recipe.height; row++) {
            for (var col = 0; col < recipe.width; col++) {
              final item = recipe.at(row, col);
              if (item != null) grid[row * size + col] = ItemStack(item);
            }
          }
        }

        expect(
          matchRecipe(grid)?.output,
          recipe.output,
          reason: 'the recipe for ${recipe.output.name} did not match',
        );
      }
    });
  });
}

void _noSelfLoopTest() {
  test('no recipe makes an item out of itself', () {
    for (final recipe in kRecipes) {
      expect(
        recipe.cost.containsKey(recipe.output),
        isFalse,
        reason: '${recipe.output.name} powstaje sam z siebie',
      );
    }
  });
}

void _missingTests() {
  group('missingFor', () {
    test('an empty map when everything is there', () {
      final inventory = Inventory()
        ..add(ItemType.cobblestone, 3)
        ..add(ItemType.stick, 2);
      expect(
        missingFor(recipeFor(ItemType.stonePickaxe), inventory.slots),
        isEmpty,
      );
    });

    test('it reports the shortfall, not the whole requirement', () {
      final inventory = Inventory()
        ..add(ItemType.cobblestone, 2)
        ..add(ItemType.stick, 2);
      expect(missingFor(recipeFor(ItemType.stonePickaxe), inventory.slots), {
        ItemType.cobblestone: 1,
      });
    });

    test('it lists several shortfalls at once', () {
      expect(missingFor(recipeFor(ItemType.stonePickaxe), Inventory().slots), {
        ItemType.cobblestone: 3,
        ItemType.stick: 2,
      });
    });

    test('a surplus does not show up as missing', () {
      final inventory = Inventory()..add(ItemType.log, 64);
      expect(missingFor(recipeFor(ItemType.planks), inventory.slots), isEmpty);
    });
  });
}
