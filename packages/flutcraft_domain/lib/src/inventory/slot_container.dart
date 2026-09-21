import '../items/item_type.dart';

/// A fixed row of item slots.
///
/// The inventory and the crafting grid had identical `[]`, `[]=`, `isEmpty`
/// and `clear` implementations, including the same rule that an emptied
/// stack must become `null` rather than a zero-count stack. That rule now
/// lives in one place.
abstract base class SlotContainer {
  SlotContainer(int slotCount)
    : slots = List<ItemStack?>.filled(slotCount, null);

  final List<ItemStack?> slots;

  int get length => slots.length;

  ItemStack? operator [](int index) => slots[index];

  /// Stores [stack], normalising an emptied stack to `null` so that "empty"
  /// has exactly one representation.
  void operator []=(int index, ItemStack? stack) {
    slots[index] = (stack != null && stack.isEmpty) ? null : stack;
  }

  bool get isEmpty => slots.every((slot) => slot == null);

  void clear() {
    for (var i = 0; i < slots.length; i++) {
      slots[i] = null;
    }
  }
}
