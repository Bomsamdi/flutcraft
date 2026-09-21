import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';

Recipe recipeFor(ItemType output) =>
    kRecipes.firstWhere((r) => r.output == output);

void main() {
  group('Koszt przepisu', () {
    test('kilof to trzy materiały i dwa patyki', () {
      expect(recipeFor(ItemType.stonePickaxe).cost, {
        ItemType.cobblestone: 3,
        ItemType.stick: 2,
      });
    });

    test('piec to osiem bruku, bo środek zostaje pusty', () {
      expect(recipeFor(ItemType.furnace).cost, {ItemType.cobblestone: 8});
    });

    test('przepis bezkształtowy też liczy składniki', () {
      expect(recipeFor(ItemType.planks).cost, {ItemType.log: 1});
    });

    test('patyki potrzebują dwóch desek', () {
      expect(recipeFor(ItemType.stick).cost, {ItemType.planks: 2});
    });
  });

  group('needsTable', () {
    test('stół i patyki mieszczą się w ekwipunku', () {
      expect(recipeFor(ItemType.craftingTable).needsTable, isFalse);
      expect(recipeFor(ItemType.stick).needsTable, isFalse);
      expect(recipeFor(ItemType.planks).needsTable, isFalse);
    });

    test('narzędzia i piec wymagają stołu', () {
      expect(recipeFor(ItemType.woodenPickaxe).needsTable, isTrue);
      expect(recipeFor(ItemType.furnace).needsTable, isTrue);
      expect(recipeFor(ItemType.ironSword).needsTable, isTrue);
    });

    test('miecz drewniany mieści się w słupku 3 pól, więc potrzebuje stołu', () {
      // Wzór ma trzy wiersze, a siatka w ekwipunku ma tylko dwa.
      expect(recipeFor(ItemType.woodenSword).height, 3);
      expect(recipeFor(ItemType.woodenSword).needsTable, isTrue);
    });
  });

  group('canCraft', () {
    test('widzi, że składników brakuje', () {
      final inventory = Inventory()..add(ItemType.cobblestone, 2);
      expect(canCraft(recipeFor(ItemType.stonePickaxe), inventory), isFalse);
    });

    test('dokładnie tyle ile trzeba wystarczy', () {
      final inventory = Inventory()
        ..add(ItemType.cobblestone, 3)
        ..add(ItemType.stick, 2);
      expect(canCraft(recipeFor(ItemType.stonePickaxe), inventory), isTrue);
    });

    test('jeden składnik mniej blokuje przepis', () {
      final inventory = Inventory()
        ..add(ItemType.cobblestone, 3)
        ..add(ItemType.stick, 1);
      expect(canCraft(recipeFor(ItemType.stonePickaxe), inventory), isFalse);
    });

    test('składniki rozbite na kilka stosów też się liczą', () {
      final inventory = Inventory()..add(ItemType.cobblestone, 70);
      expect(inventory.countOf(ItemType.cobblestone), 70);
      expect(canCraft(recipeFor(ItemType.furnace), inventory), isTrue);
    });

    test('pusty ekwipunek nie pozwala na nic poza niczym', () {
      final inventory = Inventory();
      for (final recipe in kRecipes) {
        expect(canCraft(recipe, inventory), isFalse, reason: recipe.output.name);
      }
    });
  });

  _noSelfLoopTest();
  _missingTests();

  group('Spójność księgi', () {
    test('każdy przepis ma dodatni wynik i niepusty koszt', () {
      for (final recipe in kRecipes) {
        expect(recipe.outputCount, greaterThan(0), reason: recipe.output.name);
        expect(recipe.cost, isNotEmpty, reason: recipe.output.name);
      }
    });

    test('wszystkie wypisane wytopy faktycznie coś dają', () {
      for (final input in kSmeltable) {
        expect(smeltResult(input), isNotNull, reason: input.name);
      }
    });

    test('każdy przepis da się rzeczywiście złożyć na siatce', () {
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
          reason: 'przepis na ${recipe.output.name} nie dopasował się',
        );
      }
    });
  });
}

void _noSelfLoopTest() {
  test('żaden przepis nie robi przedmiotu z niego samego', () {
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
    test('pusta mapa gdy wszystko jest', () {
      final inventory = Inventory()
        ..add(ItemType.cobblestone, 3)
        ..add(ItemType.stick, 2);
      expect(missingFor(recipeFor(ItemType.stonePickaxe), inventory), isEmpty);
    });

    test('podaje brakującą różnicę, nie całe zapotrzebowanie', () {
      final inventory = Inventory()
        ..add(ItemType.cobblestone, 2)
        ..add(ItemType.stick, 2);
      expect(missingFor(recipeFor(ItemType.stonePickaxe), inventory), {
        ItemType.cobblestone: 1,
      });
    });

    test('wypisuje kilka braków naraz', () {
      expect(missingFor(recipeFor(ItemType.stonePickaxe), Inventory()), {
        ItemType.cobblestone: 3,
        ItemType.stick: 2,
      });
    });

    test('nadmiar nie pojawia się na liście braków', () {
      final inventory = Inventory()..add(ItemType.log, 64);
      expect(missingFor(recipeFor(ItemType.planks), inventory), isEmpty);
    });
  });
}
