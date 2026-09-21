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

  int _revision = 0;

  /// Rises with every change to these slots.
  ///
  /// A server sends an inventory when it changes rather than on a timer, and
  /// a client drops a copy that arrived out of order. Comparing the lists
  /// themselves would mean comparing thirty-six entries per player per tick
  /// for something that changes a few times a minute.
  int get revision => _revision;

  int get length => slots.length;

  ItemStack? operator [](int index) => slots[index];

  /// Stores [stack], normalising an emptied stack to `null` so that "empty"
  /// has exactly one representation.
  void operator []=(int index, ItemStack? stack) {
    final value = (stack != null && stack.isEmpty) ? null : stack;
    if (slots[index] == value) return;
    slots[index] = value;
    _revision++;
  }

  bool get isEmpty => slots.every((slot) => slot == null);

  void clear() {
    for (var i = 0; i < slots.length; i++) {
      this[i] = null;
    }
  }
}
