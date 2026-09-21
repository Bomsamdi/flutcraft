import '../items/item_type.dart';
import 'slot_container.dart';

/// Ekwipunek gracza: 9 slotów paska + 27 slotów plecaka.
///
/// Sloty 0-8 to pasek szybkiego dostępu, 9-35 to plecak - dokładnie
/// jak w Minecrafcie, dzięki czemu numeracja w UI jest oczywista.
final class Inventory extends SlotContainer {
  Inventory({this.hotbarSize = 9, this.backpackSize = 27})
    : super(hotbarSize + backpackSize);

  final int hotbarSize;
  final int backpackSize;

  Iterable<ItemStack?> get hotbar => slots.take(hotbarSize);

  /// Dokłada przedmioty, najpierw dopełniając istniejące stosy.
  ///
  /// Zwraca liczbę sztuk, które się nie zmieściły.
  int add(ItemType type, [int count = 1]) {
    var left = count;

    for (var i = 0; i < slots.length && left > 0; i++) {
      final stack = slots[i];
      if (stack == null || stack.type != type || stack.space <= 0) continue;
      final moved = left < stack.space ? left : stack.space;
      slots[i] = stack.plus(moved);
      left -= moved;
    }

    for (var i = 0; i < slots.length && left > 0; i++) {
      if (slots[i] != null) continue;
      final moved = left < type.maxStack ? left : type.maxStack;
      slots[i] = ItemStack(type, moved);
      left -= moved;
    }

    return left;
  }

  /// Zdejmuje [count] sztuk ze slotu; zwraca ile faktycznie zdjęto.
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

/// Zawartość slotu i kursora po przełożeniu.
typedef SlotSwap = ({ItemStack? slot, ItemStack? cursor});

/// Kliknięcie w zwykły slot: podnosi, odkłada, scala albo zamienia stosy.
///
/// Wydzielone z gry, żeby dało się przetestować bez GPU.
SlotSwap transferSlot(ItemStack? slot, ItemStack? cursor) {
  if (cursor == null) {
    // Pusta ręka podnosi zawartość slotu.
    return (slot: null, cursor: slot);
  }
  if (slot == null) {
    return (slot: cursor, cursor: null);
  }
  if (slot.type != cursor.type) {
    // Różne przedmioty po prostu zamieniają się miejscami.
    return (slot: cursor, cursor: slot);
  }

  final moved = cursor.count < slot.space ? cursor.count : slot.space;
  final merged = slot.plus(moved);
  final left = cursor.plus(-moved);
  return (slot: merged, cursor: left.isEmpty ? null : left);
}

/// Kliknięcie w slot wynikowy (crafting, piec): można tylko zabierać.
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

/// Kliknięcie pomocnicze (prawy przycisk / przytrzymanie) w slocie.
///
/// Odwzorowuje oryginał: pustą ręką bierzemy połowę stosu (zaokrągloną
/// w górę), a trzymając coś w ręce kładziemy po jednej sztuce. Dzięki temu
/// da się rozbić stos na mniejsze porcje.
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

  // Na obcy przedmiot albo pełny stos nic nie da się dołożyć.
  if (slot.type != cursor.type || slot.space <= 0) {
    return (slot: slot, cursor: cursor);
  }

  final left = cursor.plus(-1);
  return (slot: slot.plus(1), cursor: left.isEmpty ? null : left);
}
