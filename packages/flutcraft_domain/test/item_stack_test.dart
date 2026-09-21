import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';

void main() {
  group('ItemStack jest niemutowalny', () {
    test('plus zwraca nowy stos, stary zostaje nietknięty', () {
      const original = ItemStack(ItemType.planks, 8);
      final bigger = original.plus(4);

      expect(original.count, 8, reason: 'oryginał nie może się zmienić');
      expect(bigger.count, 12);
      expect(identical(original, bigger), isFalse);
    });

    test('withCount podmienia tylko ilość', () {
      const original = ItemStack(ItemType.coal, 5);
      final one = original.withCount(1);
      expect(one.type, ItemType.coal);
      expect(one.count, 1);
      expect(original.count, 5);
    });

    test('równość po wartości, nie po tożsamości', () {
      expect(const ItemStack(ItemType.coal, 3), const ItemStack(ItemType.coal, 3));
      expect(
        const ItemStack(ItemType.coal, 3).hashCode,
        const ItemStack(ItemType.coal, 3).hashCode,
      );
    });

    test('różna ilość lub typ to różne stosy', () {
      expect(
        const ItemStack(ItemType.coal, 3),
        isNot(const ItemStack(ItemType.coal, 4)),
      );
      expect(
        const ItemStack(ItemType.coal, 3),
        isNot(const ItemStack(ItemType.bone, 3)),
      );
    });

    test('da się zbudować jako stałą', () {
      const stack = ItemStack(ItemType.stick, 2);
      expect(stack.count, 2);
    });

    test('plus w dół potrafi opróżnić stos', () {
      expect(const ItemStack(ItemType.coal, 1).plus(-1).isEmpty, isTrue);
    });
  });

  group('Migawka ekwipunku nie zmienia się pod ręką', () {
    test('lista slotów zapamiętana wcześniej nie widzi późniejszych zmian', () {
      final inventory = Inventory()..add(ItemType.planks, 8);
      final before = inventory.hotbar.toList();

      inventory.add(ItemType.planks, 4);

      // Gdyby stos był mutowalny, before[0].count pokazałby teraz 12
      // i HUD nie miałby jak zauważyć, że coś się zmieniło.
      expect(before.first!.count, 8);
      expect(inventory[0]!.count, 12);
      expect(before.first, isNot(inventory[0]));
    });

    test('przekładanie nie modyfikuje stosów w poprzedniej migawce', () {
      final slot = const ItemStack(ItemType.dirt, 60);
      const cursor = ItemStack(ItemType.dirt, 10);

      final result = transferSlot(slot, cursor);

      expect(slot.count, 60, reason: 'wejście zostaje nietknięte');
      expect(cursor.count, 10);
      expect(result.slot!.count, 64);
      expect(result.cursor!.count, 6);
    });

    test('dzielenie stosu też nie rusza wejścia', () {
      const slot = ItemStack(ItemType.planks, 8);
      final result = splitSlot(slot, null);

      expect(slot.count, 8);
      expect(result.slot!.count, 4);
      expect(result.cursor!.count, 4);
    });
  });

  group('SlotContainer', () {
    test('ekwipunek i siatka craftingu dzielą tę samą bazę', () {
      expect(Inventory(), isA<SlotContainer>());
      expect(CraftingGrid(3), isA<SlotContainer>());
    });

    test('opróżniony stos zapisuje się jako null, nie jako zero sztuk', () {
      final grid = CraftingGrid(2);
      grid[0] = const ItemStack(ItemType.coal, 0);
      expect(grid[0], isNull);
      expect(grid.isEmpty, isTrue);
    });

    test('clear czyści wszystkie sloty', () {
      final inventory = Inventory()..add(ItemType.dirt, 100);
      expect(inventory.isEmpty, isFalse);
      inventory.clear();
      expect(inventory.isEmpty, isTrue);
    });

    test('siatka 3x3 ma dziewięć slotów', () {
      expect(CraftingGrid(3).length, 9);
      expect(CraftingGrid(2).length, 4);
    });
  });
}
