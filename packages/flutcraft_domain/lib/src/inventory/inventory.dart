import '../items/item_type.dart';
import 'slot_container.dart';

/// The player's inventory: a 9-slot hotbar and a 27-slot backpack.
///
/// Slots 0-8 are the hotbar, 9-35 the backpack — the same numbering the
/// original uses, so the interface needs no translation table.
final class Inventory extends SlotContainer {
  Inventory({this.hotbarSize = 9, this.backpackSize = 27})
    : super(hotbarSize + backpackSize);

  final int hotbarSize;
  final int backpackSize;

  Iterable<ItemStack?> get hotbar => slots.take(hotbarSize);

  /// Adds items, filling existing stacks first.
  ///
  /// Returns how many did not fit.
  int add(ItemType type, [int count = 1]) {
    var left = count;

    for (var i = 0; i < slots.length && left > 0; i++) {
      final stack = slots[i];
      if (stack == null || stack.type != type || stack.space <= 0) continue;
      final moved = left < stack.space ? left : stack.space;
      this[i] = stack.plus(moved);
      left -= moved;
    }

    for (var i = 0; i < slots.length && left > 0; i++) {
      if (slots[i] != null) continue;
      final moved = left < type.maxStack ? left : type.maxStack;
      this[i] = ItemStack(type, moved);
      left -= moved;
    }

    return left;
  }

  /// Takes [count] items from a slot; returns how many it actually got.
  int takeFrom(int index, int count) {
    final stack = slots[index];
    if (stack == null) return 0;
    final taken = count < stack.count ? count : stack.count;
    this[index] = stack.plus(-taken);
    return taken;
  }

  int countOf(ItemType type) {
    var total = 0;
    for (final stack in slots) {
      if (stack?.type == type) total += stack!.count;
    }
    return total;
  }
}

/// What the slot and the cursor hold after a transfer.
typedef SlotSwap = ({ItemStack? slot, ItemStack? cursor});

/// A click on an ordinary slot: picks up, puts down, merges or swaps.
///
/// Pulled out of the game so it can be tested without a GPU.
SlotSwap transferSlot(ItemStack? slot, ItemStack? cursor) {
  if (cursor == null) {
    // An empty hand picks the slot up.
    return (slot: null, cursor: slot);
  }
  if (slot == null) {
    return (slot: cursor, cursor: null);
  }
  if (slot.type != cursor.type) {
    // Different items simply trade places.
    return (slot: cursor, cursor: slot);
  }

  final moved = cursor.count < slot.space ? cursor.count : slot.space;
  final merged = slot.plus(moved);
  final left = cursor.plus(-moved);
  return (slot: merged, cursor: left.isEmpty ? null : left);
}

/// A click on an output slot — crafting, furnace: taking only.
SlotSwap takeOutput(ItemStack? slot, ItemStack? cursor) {
  if (slot == null) return (slot: null, cursor: cursor);
  if (cursor == null) return (slot: null, cursor: slot);
  if (cursor.type != slot.type) return (slot: slot, cursor: cursor);

  final moved = slot.count < cursor.space ? slot.count : cursor.space;
  final taken = cursor.plus(moved);
  final rest = slot.plus(-moved);
  return (slot: rest.isEmpty ? null : rest, cursor: taken);
}

/// Czy kursor przyjmie [count] sztuk [type] (np. wynik craftingu).
bool cursorAccepts(ItemStack? cursor, ItemType type, int count) {
  if (cursor == null) return true;
  return cursor.type == type && cursor.space >= count;
}

/// The secondary click on a slot: right button, or a long press.
///
/// It follows the original: an empty hand takes half a stack, rounded up,
/// and a full hand puts down one item at a time. That is how a stack gets
/// split into smaller ones.
SlotSwap splitSlot(ItemStack? slot, ItemStack? cursor) {
  if (cursor == null) {
    if (slot == null) return (slot: null, cursor: null);
    final taken = (slot.count + 1) ~/ 2;
    final rest = slot.plus(-taken);
    return (slot: rest.isEmpty ? null : rest, cursor: slot.withCount(taken));
  }

  if (slot == null) {
    final left = cursor.plus(-1);
    return (slot: cursor.withCount(1), cursor: left.isEmpty ? null : left);
  }

  // Nothing can be added to a different item, or to a full stack.
  if (slot.type != cursor.type || slot.space <= 0) {
    return (slot: slot, cursor: cursor);
  }

  final left = cursor.plus(-1);
  return (slot: slot.plus(1), cursor: left.isEmpty ? null : left);
}
