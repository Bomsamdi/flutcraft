import '../inventory/inventory.dart';
import '../inventory/slot_container.dart';
import '../items/item_type.dart';

/// A crafting recipe.
///
/// [pattern] is the layout on the grid: a space is an empty slot, any other
/// character looks up [key]. A [shapeless] recipe ignores the layout and
/// only looks at which ingredients are present.
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

  /// Width of the pattern; 0 for shapeless recipes.
  int get width => pattern.isEmpty
      ? 0
      : pattern.map((row) => row.length).reduce((a, b) => a > b ? a : b);

  int get height => pattern.length;

  ItemType? at(int row, int col) {
    // Negative indices turn up while the pattern is slid across the grid.
    if (row < 0 || row >= pattern.length) return null;
    final line = pattern[row];
    if (col < 0 || col >= line.length) return null;
    final symbol = line[col];
    return symbol == ' ' ? null : key[symbol];
  }
}

/// Wszystkie przepisy prototypu.
///
/// They follow the original: a log gives planks, planks give sticks, and a
/// tool is its material on top with sticks for a handle.
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
  // Bricks come out of a furnace, so there is no recipe for them.
  Recipe.shaped(
    pattern: ['I', 'S', 'F'],
    key: {'I': ItemType.ironIngot, 'S': ItemType.stick, 'F': ItemType.string},
    output: ItemType.arrow,
    outputCount: 4,
  ),
];

/// Siatka craftingu o dowolnym rozmiarze (2x2 w ekwipunku, 3x3 przy stole).
final class CraftingGrid extends SlotContainer {
  CraftingGrid(this.size) : super(size * size);

  /// Side of the grid: 2 in the inventory, 3 at a table.
  final int size;
}

/// Finds the recipe that matches what is on the grid.
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

/// Shaped matching slides the pattern across the grid, so a pickaxe laid
/// out in the bottom-right corner of a 3x3 works too.
bool _matchesShaped(Recipe recipe, CraftingGrid grid) {
  if (recipe.width > grid.size || recipe.height > grid.size) return false;

  for (var offsetRow = 0; offsetRow <= grid.size - recipe.height; offsetRow++) {
    for (
      var offsetCol = 0;
      offsetCol <= grid.size - recipe.width;
      offsetCol++
    ) {
      if (_matchesAt(recipe, grid, offsetRow, offsetCol)) return true;
    }
  }
  return false;
}

bool _matchesAt(
  Recipe recipe,
  CraftingGrid grid,
  int offsetRow,
  int offsetCol,
) {
  for (var row = 0; row < grid.size; row++) {
    for (var col = 0; col < grid.size; col++) {
      final expected = recipe.at(row - offsetRow, col - offsetCol);
      final actual = grid[row * grid.size + col]?.type;
      if (expected != actual) return false;
    }
  }
  return true;
}

/// Takes one item from every occupied slot of the grid.
void consumeGrid(CraftingGrid grid) {
  for (var i = 0; i < grid.length; i++) {
    final stack = grid[i];
    if (stack == null) continue;
    grid[i] = stack.plus(-1);
  }
}

/// What smelts into what.
ItemType? smeltResult(ItemType input) => switch (input) {
  ItemType.rawIron => ItemType.ironIngot,
  ItemType.ironOre => ItemType.ironIngot,
  ItemType.sand => ItemType.brick,
  ItemType.log => ItemType.coal,
  _ => null,
};

/// Whether the recipe needs a crafting table — it does not fit in 2x2.
extension RecipeRequirements on Recipe {
  bool get needsTable => width > 2 || height > 2;

  /// How many of each ingredient one go at the recipe consumes.
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

/// Whether the inventory holds everything the recipe needs.
bool canCraft(Recipe recipe, Inventory inventory) {
  for (final MapEntry(key: type, value: needed) in recipe.cost.entries) {
    if (inventory.countOf(type) < needed) return false;
  }
  return true;
}

/// What is missing, and how much of it, to make the recipe.
Map<ItemType, int> missingFor(Recipe recipe, Iterable<ItemStack?> slots) {
  final have = <ItemType, int>{};
  for (final stack in slots) {
    if (stack != null) have[stack.type] = (have[stack.type] ?? 0) + stack.count;
  }

  return {
    for (final MapEntry(key: type, value: needed) in recipe.cost.entries)
      if (needed > (have[type] ?? 0)) type: needed - (have[type] ?? 0),
  };
}

/// Items a furnace accepts, in the order the recipe book lists them.
const List<ItemType> kSmeltable = [
  ItemType.rawIron,
  ItemType.ironOre,
  ItemType.sand,
  ItemType.log,
];
