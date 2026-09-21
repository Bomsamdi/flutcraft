import '../inventory/inventory.dart';
import '../inventory/slot_container.dart';
import '../items/item_type.dart';

/// Przepis rzemieślniczy.
///
/// [pattern] opisuje układ na siatce; spacja to pusty slot, każdy inny
/// znak odsyła do [key]. Przepis bezkształtowy ([shapeless]) ignoruje
/// układ i patrzy tylko na zestaw składników.
class Recipe {
  const Recipe.shaped({
    required this.pattern,
    required this.key,
    required this.output,
    required this.outputCount,
  }) : shapeless = false,
       ingredients = const [];

  const Recipe.shapeless({
    required this.ingredients,
    required this.output,
    required this.outputCount,
  }) : shapeless = true,
       pattern = const [],
       key = const {};

  final List<String> pattern;
  final Map<String, ItemType> key;
  final List<ItemType> ingredients;
  final bool shapeless;
  final ItemType output;
  final int outputCount;

  /// Szerokość wzoru (0 dla przepisów bezkształtowych).
  int get width => pattern.isEmpty
      ? 0
      : pattern.map((row) => row.length).reduce((a, b) => a > b ? a : b);

  int get height => pattern.length;

  ItemType? at(int row, int col) {
    // Ujemne indeksy pojawiają się, gdy wzór jest przesuwany po siatce.
    if (row < 0 || row >= pattern.length) return null;
    final line = pattern[row];
    if (col < 0 || col >= line.length) return null;
    final symbol = line[col];
    return symbol == ' ' ? null : key[symbol];
  }
}

/// Wszystkie przepisy prototypu.
///
/// Odwzorowują oryginał: kłoda daje deski, deski patyki, a narzędzia
/// powstają z materiału na górze i patyków jako trzonka.
const List<Recipe> kRecipes = [
  Recipe.shapeless(
    ingredients: [ItemType.log],
    output: ItemType.planks,
    outputCount: 4,
  ),
  Recipe.shaped(
    pattern: ['P', 'P'],
    key: {'P': ItemType.planks},
    output: ItemType.stick,
    outputCount: 4,
  ),
  Recipe.shaped(
    pattern: ['PP', 'PP'],
    key: {'P': ItemType.planks},
    output: ItemType.craftingTable,
    outputCount: 1,
  ),
  Recipe.shaped(
    pattern: ['CCC', 'C C', 'CCC'],
    key: {'C': ItemType.cobblestone},
    output: ItemType.furnace,
    outputCount: 1,
  ),

  // --- kilofy ---
  Recipe.shaped(
    pattern: ['PPP', ' S ', ' S '],
    key: {'P': ItemType.planks, 'S': ItemType.stick},
    output: ItemType.woodenPickaxe,
    outputCount: 1,
  ),
  Recipe.shaped(
    pattern: ['CCC', ' S ', ' S '],
    key: {'C': ItemType.cobblestone, 'S': ItemType.stick},
    output: ItemType.stonePickaxe,
    outputCount: 1,
  ),
  Recipe.shaped(
    pattern: ['III', ' S ', ' S '],
    key: {'I': ItemType.ironIngot, 'S': ItemType.stick},
    output: ItemType.ironPickaxe,
    outputCount: 1,
  ),

  // --- miecze ---
  Recipe.shaped(
    pattern: ['P', 'P', 'S'],
    key: {'P': ItemType.planks, 'S': ItemType.stick},
    output: ItemType.woodenSword,
    outputCount: 1,
  ),
  Recipe.shaped(
    pattern: ['C', 'C', 'S'],
    key: {'C': ItemType.cobblestone, 'S': ItemType.stick},
    output: ItemType.stoneSword,
    outputCount: 1,
  ),
  Recipe.shaped(
    pattern: ['I', 'I', 'S'],
    key: {'I': ItemType.ironIngot, 'S': ItemType.stick},
    output: ItemType.ironSword,
    outputCount: 1,
  ),

  // --- drobiazgi ---
  // Cegły zdobywa się wytapiając piasek, więc nie ma dla nich przepisu.
  Recipe.shaped(
    pattern: ['I', 'S', 'F'],
    key: {
      'I': ItemType.ironIngot,
      'S': ItemType.stick,
      'F': ItemType.string,
    },
    output: ItemType.arrow,
    outputCount: 4,
  ),
];

/// Siatka craftingu o dowolnym rozmiarze (2x2 w ekwipunku, 3x3 przy stole).
final class CraftingGrid extends SlotContainer {
  CraftingGrid(this.size) : super(size * size);

  /// Długość boku siatki: 2 w ekwipunku, 3 przy stole.
  final int size;
}

/// Znajduje przepis pasujący do zawartości siatki.
Recipe? matchRecipe(CraftingGrid grid) {
  for (final recipe in kRecipes) {
    if (recipe.shapeless) {
      if (_matchesShapeless(recipe, grid)) return recipe;
    } else if (_matchesShaped(recipe, grid)) {
      return recipe;
    }
  }
  return null;
}

bool _matchesShapeless(Recipe recipe, CraftingGrid grid) {
  final present = <ItemType>[];
  for (final stack in grid.slots) {
    if (stack != null) present.add(stack.type);
  }
  if (present.length != recipe.ingredients.length) return false;

  final needed = [...recipe.ingredients];
  for (final type in present) {
    if (!needed.remove(type)) return false;
  }
  return needed.isEmpty;
}

/// Dopasowanie kształtowe z przesuwaniem wzoru po siatce - dzięki temu
/// kilof zrobiony w prawym dolnym rogu 3x3 też zadziała.
bool _matchesShaped(Recipe recipe, CraftingGrid grid) {
  if (recipe.width > grid.size || recipe.height > grid.size) return false;

  for (var offsetRow = 0; offsetRow <= grid.size - recipe.height; offsetRow++) {
    for (var offsetCol = 0; offsetCol <= grid.size - recipe.width; offsetCol++) {
      if (_matchesAt(recipe, grid, offsetRow, offsetCol)) return true;
    }
  }
  return false;
}

bool _matchesAt(Recipe recipe, CraftingGrid grid, int offsetRow, int offsetCol) {
  for (var row = 0; row < grid.size; row++) {
    for (var col = 0; col < grid.size; col++) {
      final expected = recipe.at(row - offsetRow, col - offsetCol);
      final actual = grid[row * grid.size + col]?.type;
      if (expected != actual) return false;
    }
  }
  return true;
}

/// Zdejmuje po jednej sztuce z każdego zajętego slotu siatki.
void consumeGrid(CraftingGrid grid) {
  for (var i = 0; i < grid.length; i++) {
    final stack = grid[i];
    if (stack == null) continue;
    grid[i] = stack.plus(-1);
  }
}

/// Co wytapia się z czego w piecu.
ItemType? smeltResult(ItemType input) => switch (input) {
  ItemType.rawIron => ItemType.ironIngot,
  ItemType.ironOre => ItemType.ironIngot,
  ItemType.sand => ItemType.brick,
  ItemType.log => ItemType.coal,
  _ => null,
};

/// Czy przepis wymaga stołu rzemieślniczego (nie mieści się w 2x2).
extension RecipeRequirements on Recipe {
  bool get needsTable => width > 2 || height > 2;

  /// Ile sztuk każdego składnika zjada jedno wykonanie przepisu.
  Map<ItemType, int> get cost {
    final result = <ItemType, int>{};
    void add(ItemType type) =>
        result.update(type, (n) => n + 1, ifAbsent: () => 1);

    if (shapeless) {
      ingredients.forEach(add);
      return result;
    }
    for (var row = 0; row < height; row++) {
      for (var col = 0; col < width; col++) {
        final item = at(row, col);
        if (item != null) add(item);
      }
    }
    return result;
  }
}

/// Czy gracz ma w ekwipunku wszystkie składniki przepisu.
bool canCraft(Recipe recipe, Inventory inventory) {
  for (final MapEntry(key: type, value: needed) in recipe.cost.entries) {
    if (inventory.countOf(type) < needed) return false;
  }
  return true;
}

/// Czego i ile brakuje w ekwipunku, żeby wykonać przepis.
Map<ItemType, int> missingFor(Recipe recipe, Inventory inventory) {
  final missing = <ItemType, int>{};
  for (final MapEntry(key: type, value: needed) in recipe.cost.entries) {
    final have = inventory.countOf(type);
    if (have < needed) missing[type] = needed - have;
  }
  return missing;
}

/// Przedmioty, które da się wytopić w piecu - kolejność jak w księdze.
const List<ItemType> kSmeltable = [
  ItemType.rawIron,
  ItemType.ironOre,
  ItemType.sand,
  ItemType.log,
];
