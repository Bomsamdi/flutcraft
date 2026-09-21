import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';

/// Fills the grid from a pattern; a dot is an empty cell.
CraftingGrid gridOf(List<String> rows, Map<String, ItemType> key) {
  final grid = CraftingGrid(rows.length);
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < rows[r].length; c++) {
      final symbol = rows[r][c];
      if (symbol == '.') continue;
      grid[r * grid.size + c] = ItemStack(key[symbol]!);
    }
  }
  return grid;
}

void main() {
  group('Inventory', () {
    test('tops up an existing stack before taking a new slot', () {
      final inv = Inventory()..add(ItemType.planks, 10);
      inv.add(ItemType.planks, 5);
      expect(inv[0]!.count, 15);
      expect(inv[1], isNull);
    });

    test('rozbija nadmiar na kolejne sloty', () {
      final inv = Inventory();
      final left = inv.add(ItemType.dirt, 70);
      expect(left, 0);
      expect(inv[0]!.count, 64);
      expect(inv[1]!.count, 6);
    });

    test('zwraca nadmiar, gdy zabraknie miejsca', () {
      final inv = Inventory(hotbarSize: 1, backpackSize: 0);
      final left = inv.add(ItemType.dirt, 100);
      expect(left, 36);
      expect(inv[0]!.count, 64);
    });

    test('tools do not stack', () {
      final inv = Inventory()..add(ItemType.ironPickaxe, 2);
      expect(inv[0]!.count, 1);
      expect(inv[1]!.count, 1);
    });

    test('takeFrom empties the slot completely', () {
      final inv = Inventory()..add(ItemType.coal, 3);
      expect(inv.takeFrom(0, 5), 3);
      expect(inv[0], isNull);
    });

    test('countOf sumuje po wszystkich slotach', () {
      final inv = Inventory()..add(ItemType.stick, 70);
      expect(inv.countOf(ItemType.stick), 70);
    });
  });

  group('Shaped recipes', () {
    test('a log gives planks from any cell', () {
      final grid = CraftingGrid(2);
      grid[3] = ItemStack(ItemType.log);
      final recipe = matchRecipe(grid);
      expect(recipe?.output, ItemType.planks);
      expect(recipe?.outputCount, 4);
    });

    test('two planks stacked give sticks', () {
      final grid = gridOf(['P.', 'P.'], {'P': ItemType.planks});
      expect(matchRecipe(grid)?.output, ItemType.stick);
    });

    test('the planks have to be in the same column', () {
      final grid = gridOf(['P.', '.P'], {'P': ItemType.planks});
      expect(matchRecipe(grid), isNull);
    });

    test('2x2 planks make a crafting table', () {
      final grid = gridOf(['PP', 'PP'], {'P': ItemType.planks});
      expect(matchRecipe(grid)?.output, ItemType.craftingTable);
    });

    test('kamienny kilof wymaga siatki 3x3', () {
      final small = gridOf(
        ['CC', 'S.'],
        {'C': ItemType.cobblestone, 'S': ItemType.stick},
      );
      expect(matchRecipe(small), isNull);

      final big = gridOf(
        ['CCC', '.S.', '.S.'],
        {'C': ItemType.cobblestone, 'S': ItemType.stick},
      );
      expect(matchRecipe(big)?.output, ItemType.stonePickaxe);
    });

    test('a sword works in an offset corner of the 3x3 grid', () {
      final shifted = gridOf(
        ['..I', '..I', '..S'],
        {'I': ItemType.ironIngot, 'S': ItemType.stick},
      );
      expect(matchRecipe(shifted)?.output, ItemType.ironSword);
    });

    test('a ring of cobble is a furnace, a full square is not', () {
      final ring = gridOf(['CCC', 'C.C', 'CCC'], {'C': ItemType.cobblestone});
      expect(matchRecipe(ring)?.output, ItemType.furnace);

      final full = gridOf(['CCC', 'CCC', 'CCC'], {'C': ItemType.cobblestone});
      expect(matchRecipe(full), isNull);
    });

    test('consumeGrid takes one item from every filled cell', () {
      final grid = CraftingGrid(2);
      grid[0] = ItemStack(ItemType.planks, 3);
      grid[1] = ItemStack(ItemType.planks, 1);
      consumeGrid(grid);
      expect(grid[0]!.count, 2);
      expect(grid[1], isNull);
    });
  });

  group('Piec', () {
    test('smelts raw iron into ingots, burning fuel', () {
      // Three items at 4 s each is 12 s of smelting; two coal burn for 16 s.
      final furnace = FurnaceState()
        ..input = ItemStack(ItemType.rawIron, 3)
        ..fuel = ItemStack(ItemType.coal, 2);

      for (var i = 0; i < 400; i++) {
        furnace.tick(0.05);
      }

      expect(furnace.output?.type, ItemType.ironIngot);
      expect(furnace.output!.count, 3);
      expect(furnace.input, isNull);
      expect(furnace.fuel, isNull);
    });

    test('one portion of coal covers two smelts', () {
      final furnace = FurnaceState()
        ..input = ItemStack(ItemType.rawIron, 4)
        ..fuel = ItemStack(ItemType.coal, 1);

      for (var i = 0; i < 400; i++) {
        furnace.tick(0.05);
      }

      // Eight seconds of burning is exactly two 4-second cycles.
      expect(furnace.output!.count, 2);
      expect(furnace.input!.count, 2);
      expect(furnace.isLit, isFalse);
    });

    test('without fuel nothing happens', () {
      final furnace = FurnaceState()..input = ItemStack(ItemType.rawIron, 1);
      for (var i = 0; i < 100; i++) {
        furnace.tick(0.05);
      }
      expect(furnace.output, isNull);
      expect(furnace.input!.count, 1);
      expect(furnace.isLit, isFalse);
    });

    test('przedmiot bez przepisu nie zapala pieca', () {
      final furnace = FurnaceState()
        ..input = ItemStack(ItemType.bone, 1)
        ..fuel = ItemStack(ItemType.coal, 1);
      for (var i = 0; i < 40; i++) {
        furnace.tick(0.05);
      }
      expect(furnace.output, isNull);
      expect(furnace.fuel!.count, 1);
    });

    test('the contents come back when the furnace is broken', () {
      final furnace = FurnaceState()
        ..input = ItemStack(ItemType.rawIron, 2)
        ..output = ItemStack(ItemType.ironIngot, 1);
      expect(furnace.contents().length, 2);
    });
  });

  _slotTransferTests();
  _splitTests();

  group('ItemType', () {
    test('blocks know their item and the other way round', () {
      expect(ItemType.cobblestone.isBlock, isTrue);
      expect(ItemType.stick.isBlock, isFalse);
      expect(ItemType.forBlock(ItemType.furnace.block!), ItemType.furnace);
    });

    test('pickaxes rise in tier and in damage', () {
      expect(ItemType.woodenPickaxe.tier, lessThan(ItemType.ironPickaxe.tier));
      expect(ItemType.woodenSword.damage, lessThan(ItemType.ironSword.damage));
    });

    test('only coal burns in a furnace', () {
      expect(ItemType.coal.isFuel, isTrue);
      expect(ItemType.ironIngot.isFuel, isFalse);
    });
  });
}

void _slotTransferTests() {
  group('Moving items between slots', () {
    test('an empty hand picks the slot up', () {
      final result = transferSlot(ItemStack(ItemType.coal, 5), null);
      expect(result.slot, isNull);
      expect(result.cursor!.type, ItemType.coal);
      expect(result.cursor!.count, 5);
    });

    test('a full hand puts it down in an empty slot', () {
      final result = transferSlot(null, ItemStack(ItemType.coal, 5));
      expect(result.slot!.count, 5);
      expect(result.cursor, isNull);
    });

    test('the same item merges', () {
      final result = transferSlot(
        ItemStack(ItemType.dirt, 60),
        ItemStack(ItemType.dirt, 10),
      );
      expect(result.slot!.count, 64);
      // Six items did not fit and stay on the cursor.
      expect(result.cursor!.count, 6);
    });

    test('different items trade places', () {
      final result = transferSlot(
        ItemStack(ItemType.dirt, 3),
        ItemStack(ItemType.coal, 7),
      );
      expect(result.slot!.type, ItemType.coal);
      expect(result.cursor!.type, ItemType.dirt);
    });

    test('the result slot can only be taken from', () {
      final put = takeOutput(null, ItemStack(ItemType.coal, 5));
      expect(put.slot, isNull, reason: 'nothing may be put in');
      expect(put.cursor!.count, 5);

      final take = takeOutput(ItemStack(ItemType.ironIngot, 2), null);
      expect(take.slot, isNull);
      expect(take.cursor!.count, 2);
    });

    test('the result merges with the same item on the cursor', () {
      final result = takeOutput(
        ItemStack(ItemType.ironIngot, 3),
        ItemStack(ItemType.ironIngot, 1),
      );
      expect(result.cursor!.count, 4);
      expect(result.slot, isNull);
    });

    test('cursorAccepts pilnuje limitu stosu', () {
      expect(cursorAccepts(null, ItemType.planks, 4), isTrue);
      expect(
        cursorAccepts(ItemStack(ItemType.planks, 62), ItemType.planks, 4),
        isFalse,
      );
      expect(
        cursorAccepts(ItemStack(ItemType.coal, 1), ItemType.planks, 4),
        isFalse,
      );
    });
  });
}

void _splitTests() {
  group('Dzielenie stosu', () {
    test('an empty hand takes half an even stack', () {
      final result = splitSlot(ItemStack(ItemType.planks, 8), null);
      expect(result.slot!.count, 4);
      expect(result.cursor!.count, 4);
    });

    test('an odd stack splits with the extra on the cursor', () {
      final result = splitSlot(ItemStack(ItemType.planks, 7), null);
      expect(result.cursor!.count, 4);
      expect(result.slot!.count, 3);
    });

    test('a single item moves to the cursor whole', () {
      final result = splitSlot(ItemStack(ItemType.coal, 1), null);
      expect(result.slot, isNull);
      expect(result.cursor!.count, 1);
    });

    test('an empty slot and an empty hand do nothing', () {
      final result = splitSlot(null, null);
      expect(result.slot, isNull);
      expect(result.cursor, isNull);
    });

    test('a full hand puts one item into an empty slot', () {
      final result = splitSlot(null, ItemStack(ItemType.dirt, 5));
      expect(result.slot!.count, 1);
      expect(result.cursor!.count, 4);
    });

    test('the last item empties the cursor', () {
      final result = splitSlot(null, ItemStack(ItemType.dirt, 1));
      expect(result.slot!.count, 1);
      expect(result.cursor, isNull);
    });

    test('items go one at a time onto a stack of the same type', () {
      final result = splitSlot(
        ItemStack(ItemType.dirt, 3),
        ItemStack(ItemType.dirt, 5),
      );
      expect(result.slot!.count, 4);
      expect(result.cursor!.count, 4);
    });

    test('a different item in the slot blocks adding', () {
      final result = splitSlot(
        ItemStack(ItemType.coal, 3),
        ItemStack(ItemType.dirt, 5),
      );
      expect(result.slot!.count, 3);
      expect(result.cursor!.count, 5);
    });

    test('a full stack cannot be overfilled', () {
      final result = splitSlot(
        ItemStack(ItemType.dirt, 64),
        ItemStack(ItemType.dirt, 5),
      );
      expect(result.slot!.count, 64);
      expect(result.cursor!.count, 5);
    });

    test('powtarzane dzielenie rozbija stos na coraz mniejsze porcje', () {
      // Spread eight planks across four separate slots.
      var source = ItemStack(ItemType.planks, 8);
      final placed = <int>[];
      ItemStack? cursor;

      for (var i = 0; i < 4; i++) {
        final taken = splitSlot(source, cursor);
        source = taken.slot ?? ItemStack(ItemType.planks, 0);
        cursor = taken.cursor;

        // Put one item into a new, empty slot.
        final put = splitSlot(null, cursor);
        placed.add(put.slot!.count);
        cursor = put.cursor;

        // The rest goes back to the source stack.
        final back = transferSlot(source, cursor);
        source = back.slot ?? ItemStack(ItemType.planks, 0);
        cursor = back.cursor;
      }

      expect(placed, [1, 1, 1, 1]);
      expect(source.count, 4);
    });
  });
}
