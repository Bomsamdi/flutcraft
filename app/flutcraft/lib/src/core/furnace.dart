import 'package:flutcraft/src/core/item.dart';
import 'package:flutcraft/src/core/recipes.dart';

/// Stan jednego pieca w świecie.
///
/// Piece są indeksowane pozycją bloku, więc stan przeżywa przełączanie
/// tekstury między [BlockType.furnace] a [BlockType.furnaceLit].
class FurnaceState {
  ItemStack? input;
  ItemStack? fuel;
  ItemStack? output;

  /// Ile sekund palenia zostało z bieżącej porcji paliwa.
  double burnLeft = 0;

  /// Ile sekund dawała ta porcja - potrzebne do paska płomienia.
  double burnTotal = 0;

  /// Postęp wytopu bieżącej sztuki (0..1).
  double progress = 0;

  /// Ile sekund trwa wytopienie jednej sztuki.
  static const double smeltTime = 4.0;

  /// Tolerancja porównań: sumowanie dt po setkach klatek gubi ostatnie
  /// bity, przez co ostatni cykl porcji paliwa przepadał.
  static const double _epsilon = 1e-9;

  bool get isLit => burnLeft > 0;

  double get fuelFraction => burnTotal <= 0 ? 0 : burnLeft / burnTotal;

  bool get isEmpty => input == null && fuel == null && output == null;

  /// Czy da się teraz coś wytapiać (jest wsad i miejsce na wynik).
  bool get canSmelt {
    final source = input;
    if (source == null) return false;
    final result = smeltResult(source.type);
    if (result == null) return false;

    final slot = output;
    if (slot == null) return true;
    return slot.type == result && slot.space > 0;
  }

  void tick(double dt) {
    final smelting = canSmelt;

    if (burnLeft <= 0 && smelting) _consumeFuel();

    if (burnLeft <= 0) {
      // Zimny piec powoli traci postęp, jak w oryginale.
      progress = (progress - dt / smeltTime).clamp(0.0, 1.0);
      burnTotal = 0;
      return;
    }

    if (smelting) {
      progress += dt / smeltTime;
      if (progress >= 1 - _epsilon) {
        progress = 0;
        _finishSmelt();
      }
    } else {
      progress = (progress - dt / smeltTime).clamp(0.0, 1.0);
    }

    // Paliwo zużywamy dopiero po wykonaniu pracy w tym kroku - inaczej
    // ostatni cykl porcji paliwa przepadałby tuż przed końcem.
    burnLeft -= dt;
    if (burnLeft <= 0) burnTotal = 0;
  }

  void _consumeFuel() {
    final stack = fuel;
    if (stack == null || !stack.type.isFuel) return;
    burnTotal = stack.type.burnTime;
    burnLeft = burnTotal;
    stack.count--;
    if (stack.isEmpty) fuel = null;
  }

  void _finishSmelt() {
    final source = input!;
    final result = smeltResult(source.type)!;

    source.count--;
    if (source.isEmpty) input = null;

    final slot = output;
    if (slot == null) {
      output = ItemStack(result);
    } else {
      slot.count++;
    }
  }

  /// Zawartość do zwrócenia graczowi po zbiciu pieca.
  List<ItemStack> contents() =>
      [input, fuel, output].whereType<ItemStack>().toList();
}
