import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';

/// Wypełnia siatkę według wzoru; kropka to pole puste.
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
    test('dokłada do istniejącego stosu zanim zajmie nowy slot', () {
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

    test('narzędzia nie stakują się', () {
      final inv = Inventory()..add(ItemType.ironPickaxe, 2);
      expect(inv[0]!.count, 1);
      expect(inv[1]!.count, 1);
    });

    test('takeFrom opróżnia slot do końca', () {
      final inv = Inventory()..add(ItemType.coal, 3);
      expect(inv.takeFrom(0, 5), 3);
      expect(inv[0], isNull);
    });

    test('countOf sumuje po wszystkich slotach', () {
      final inv = Inventory()..add(ItemType.stick, 70);
      expect(inv.countOf(ItemType.stick), 70);
    });
  });

  group('Przepisy kształtowe', () {
    test('kłoda daje deski niezależnie od pola', () {
      final grid = CraftingGrid(2);
      grid[3] = ItemStack(ItemType.log);
      final recipe = matchRecipe(grid);
      expect(recipe?.output, ItemType.planks);
      expect(recipe?.outputCount, 4);
    });

    test('dwie deski w pionie dają patyki', () {
      final grid = gridOf(['P.', 'P.'], {'P': ItemType.planks});
      expect(matchRecipe(grid)?.output, ItemType.stick);
    });

    test('deski w pionie muszą być w jednej kolumnie', () {
      final grid = gridOf(['P.', '.P'], {'P': ItemType.planks});
      expect(matchRecipe(grid), isNull);
    });

    test('2x2 desek to stół rzemieślniczy', () {
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

    test('miecz da się zrobić w przesuniętym rogu siatki 3x3', () {
      final shifted = gridOf(
        ['..I', '..I', '..S'],
        {'I': ItemType.ironIngot, 'S': ItemType.stick},
      );
      expect(matchRecipe(shifted)?.output, ItemType.ironSword);
    });

    test('pierścień bruku to piec, pełny kwadrat już nie', () {
      final ring = gridOf(['CCC', 'C.C', 'CCC'], {'C': ItemType.cobblestone});
      expect(matchRecipe(ring)?.output, ItemType.furnace);

      final full = gridOf(['CCC', 'CCC', 'CCC'], {'C': ItemType.cobblestone});
      expect(matchRecipe(full), isNull);
    });

    test('consumeGrid zdejmuje po jednej sztuce z każdego pola', () {
      final grid = CraftingGrid(2);
      grid[0] = ItemStack(ItemType.planks, 3);
      grid[1] = ItemStack(ItemType.planks, 1);
      consumeGrid(grid);
      expect(grid[0]!.count, 2);
      expect(grid[1], isNull);
    });
  });

  group('Piec', () {
    test('wytapia surowe żelazo na sztabki, zużywając paliwo', () {
      // 3 sztuki po 4 s = 12 s wytopu; 2 węgle dają 16 s palenia.
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

    test('jedna porcja węgla starczy na dwa wytopy', () {
      final furnace = FurnaceState()
        ..input = ItemStack(ItemType.rawIron, 4)
        ..fuel = ItemStack(ItemType.coal, 1);

      for (var i = 0; i < 400; i++) {
        furnace.tick(0.05);
      }

      // 8 s palenia to dokładnie dwa cykle po 4 s.
      expect(furnace.output!.count, 2);
      expect(furnace.input!.count, 2);
      expect(furnace.isLit, isFalse);
    });

    test('bez paliwa nic się nie dzieje', () {
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

    test('zawartość wraca do gracza po rozbiciu', () {
      final furnace = FurnaceState()
        ..input = ItemStack(ItemType.rawIron, 2)
        ..output = ItemStack(ItemType.ironIngot, 1);
      expect(furnace.contents().length, 2);
    });
  });

  _slotTransferTests();
  _splitTests();

  group('ItemType', () {
    test('bloki znają swój przedmiot i odwrotnie', () {
      expect(ItemType.cobblestone.isBlock, isTrue);
      expect(ItemType.stick.isBlock, isFalse);
      expect(ItemType.forBlock(ItemType.furnace.block!), ItemType.furnace);
    });

    test('kilofy mają rosnący poziom i obrażenia', () {
      expect(ItemType.woodenPickaxe.tier, lessThan(ItemType.ironPickaxe.tier));
      expect(ItemType.woodenSword.damage, lessThan(ItemType.ironSword.damage));
    });

    test('tylko węgiel pali się w piecu', () {
      expect(ItemType.coal.isFuel, isTrue);
      expect(ItemType.ironIngot.isFuel, isFalse);
    });
  });
}

void _slotTransferTests() {
  group('Przekładanie przedmiotów', () {
    test('pusta ręka podnosi zawartość slotu', () {
      final result = transferSlot(ItemStack(ItemType.coal, 5), null);
      expect(result.slot, isNull);
      expect(result.cursor!.type, ItemType.coal);
      expect(result.cursor!.count, 5);
    });

    test('pełna ręka odkłada do pustego slotu', () {
      final result = transferSlot(null, ItemStack(ItemType.coal, 5));
      expect(result.slot!.count, 5);
      expect(result.cursor, isNull);
    });

    test('te same przedmioty się scalają', () {
      final result = transferSlot(
        ItemStack(ItemType.dirt, 60),
        ItemStack(ItemType.dirt, 10),
      );
      expect(result.slot!.count, 64);
      // Sześć sztuk nie zmieściło się i zostaje na kursorze.
      expect(result.cursor!.count, 6);
    });

    test('różne przedmioty zamieniają się miejscami', () {
      final result = transferSlot(
        ItemStack(ItemType.dirt, 3),
        ItemStack(ItemType.coal, 7),
      );
      expect(result.slot!.type, ItemType.coal);
      expect(result.cursor!.type, ItemType.dirt);
    });

    test('ze slotu wyniku można tylko zabierać', () {
      final put = takeOutput(null, ItemStack(ItemType.coal, 5));
      expect(put.slot, isNull, reason: 'nic nie wolno włożyć');
      expect(put.cursor!.count, 5);

      final take = takeOutput(ItemStack(ItemType.ironIngot, 2), null);
      expect(take.slot, isNull);
      expect(take.cursor!.count, 2);
    });

    test('wynik dokłada się do tego samego przedmiotu na kursorze', () {
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
    test('pustą ręką bierzemy połowę parzystego stosu', () {
      final result = splitSlot(ItemStack(ItemType.planks, 8), null);
      expect(result.slot!.count, 4);
      expect(result.cursor!.count, 4);
    });

    test('nieparzysty stos dzieli się z nadwyżką na kursor', () {
      final result = splitSlot(ItemStack(ItemType.planks, 7), null);
      expect(result.cursor!.count, 4);
      expect(result.slot!.count, 3);
    });

    test('pojedyncza sztuka trafia w całości na kursor', () {
      final result = splitSlot(ItemStack(ItemType.coal, 1), null);
      expect(result.slot, isNull);
      expect(result.cursor!.count, 1);
    });

    test('pusty slot pustą ręką nic nie robi', () {
      final result = splitSlot(null, null);
      expect(result.slot, isNull);
      expect(result.cursor, isNull);
    });

    test('z pełną ręką kładziemy jedną sztukę do pustego slotu', () {
      final result = splitSlot(null, ItemStack(ItemType.dirt, 5));
      expect(result.slot!.count, 1);
      expect(result.cursor!.count, 4);
    });

    test('ostatnia sztuka opróżnia kursor', () {
      final result = splitSlot(null, ItemStack(ItemType.dirt, 1));
      expect(result.slot!.count, 1);
      expect(result.cursor, isNull);
    });

    test('dokładamy po jednej do stosu tego samego typu', () {
      final result = splitSlot(
        ItemStack(ItemType.dirt, 3),
        ItemStack(ItemType.dirt, 5),
      );
      expect(result.slot!.count, 4);
      expect(result.cursor!.count, 4);
    });

    test('obcy przedmiot w slocie blokuje dokładanie', () {
      final result = splitSlot(
        ItemStack(ItemType.coal, 3),
        ItemStack(ItemType.dirt, 5),
      );
      expect(result.slot!.count, 3);
      expect(result.cursor!.count, 5);
    });

    test('pełnego stosu nie da się przepełnić', () {
      final result = splitSlot(
        ItemStack(ItemType.dirt, 64),
        ItemStack(ItemType.dirt, 5),
      );
      expect(result.slot!.count, 64);
      expect(result.cursor!.count, 5);
    });

    test('powtarzane dzielenie rozbija stos na coraz mniejsze porcje', () {
      // Osiem desek rozkładamy na cztery osobne sloty.
      var source = ItemStack(ItemType.planks, 8);
      final placed = <int>[];
      ItemStack? cursor;

      for (var i = 0; i < 4; i++) {
        final taken = splitSlot(source, cursor);
        source = taken.slot ?? ItemStack(ItemType.planks, 0);
        cursor = taken.cursor;

        // Kładziemy jedną sztukę do nowego, pustego slotu.
        final put = splitSlot(null, cursor);
        placed.add(put.slot!.count);
        cursor = put.cursor;

        // Reszta wraca do stosu źródłowego.
        final back = transferSlot(source, cursor);
        source = back.slot ?? ItemStack(ItemType.planks, 0);
        cursor = back.cursor;
      }

      expect(placed, [1, 1, 1, 1]);
      expect(source.count, 4);
    });
  });
}
