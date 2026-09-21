import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';

void main() {
  group('ItemStack is immutable', () {
    test('plus returns a new stack and leaves the old one alone', () {
      const original = ItemStack(ItemType.planks, 8);
      final bigger = original.plus(4);

      expect(original.count, 8, reason: 'the original must not change');
      expect(bigger.count, 12);
      expect(identical(original, bigger), isFalse);
    });

    test('withCount changes only the count', () {
      const original = ItemStack(ItemType.coal, 5);
      final one = original.withCount(1);
      expect(one.type, ItemType.coal);
      expect(one.count, 1);
      expect(original.count, 5);
    });

    test('equality by value, not by identity', () {
      expect(
        const ItemStack(ItemType.coal, 3),
        const ItemStack(ItemType.coal, 3),
      );
      expect(
        const ItemStack(ItemType.coal, 3).hashCode,
        const ItemStack(ItemType.coal, 3).hashCode,
      );
    });

    test('a different count or type is a different stack', () {
      expect(
        const ItemStack(ItemType.coal, 3),
        isNot(const ItemStack(ItemType.coal, 4)),
      );
      expect(
        const ItemStack(ItemType.coal, 3),
        isNot(const ItemStack(ItemType.bone, 3)),
      );
    });

    test('it can be built as a constant', () {
      const stack = ItemStack(ItemType.stick, 2);
      expect(stack.count, 2);
    });

    test('plus downwards can empty a stack', () {
      expect(const ItemStack(ItemType.coal, 1).plus(-1).isEmpty, isTrue);
    });
  });

  group('An inventory snapshot does not change under you', () {
    test('a list of slots kept earlier does not see later changes', () {
      final inventory = Inventory()..add(ItemType.planks, 8);
      final before = inventory.hotbar.toList();

      inventory.add(ItemType.planks, 4);

      // If the stack were mutable, before[0].count would now read 12 and
      // the HUD would have no way of noticing anything had changed.
      expect(before.first!.count, 8);
      expect(inventory[0]!.count, 12);
      expect(before.first, isNot(inventory[0]));
    });

    test('a transfer does not touch the stacks of an earlier snapshot', () {
      final slot = const ItemStack(ItemType.dirt, 60);
      const cursor = ItemStack(ItemType.dirt, 10);

      final result = transferSlot(slot, cursor);

      expect(slot.count, 60, reason: 'the input is left alone');
      expect(cursor.count, 10);
      expect(result.slot!.count, 64);
      expect(result.cursor!.count, 6);
    });

    test('splitting a stack leaves the input alone too', () {
      const slot = ItemStack(ItemType.planks, 8);
      final result = splitSlot(slot, null);

      expect(slot.count, 8);
      expect(result.slot!.count, 4);
      expect(result.cursor!.count, 4);
    });
  });

  group('SlotContainer', () {
    test('inventory and crafting grid share the same base class', () {
      expect(Inventory(), isA<SlotContainer>());
      expect(CraftingGrid(3), isA<SlotContainer>());
    });

    test('an emptied stack is stored as null, not as a count of zero', () {
      final grid = CraftingGrid(2);
      grid[0] = const ItemStack(ItemType.coal, 0);
      expect(grid[0], isNull);
      expect(grid.isEmpty, isTrue);
    });

    test('the revision rises with every change, and only then', () {
      final inventory = Inventory();
      final start = inventory.revision;

      inventory.add(ItemType.coal, 3);
      final afterAdd = inventory.revision;
      inventory[0] = inventory[0];

      // A server sends an inventory when it changes; a write that changes
      // nothing must not make it look like news.
      expect(afterAdd, greaterThan(start));
      expect(inventory.revision, afterAdd);
    });

    test('clear empties every slot', () {
      final inventory = Inventory()..add(ItemType.dirt, 100);
      expect(inventory.isEmpty, isFalse);
      inventory.clear();
      expect(inventory.isEmpty, isTrue);
    });

    test('a 3x3 grid has nine slots', () {
      expect(CraftingGrid(3).length, 9);
      expect(CraftingGrid(2).length, 4);
    });
  });
}
