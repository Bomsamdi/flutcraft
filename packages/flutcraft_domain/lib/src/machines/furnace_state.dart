import '../items/item_type.dart';
import '../crafting/recipes.dart';

/// Which of the furnace's three slots a click refers to.
enum FurnaceSlot {
  /// What is being smelted.
  input,

  /// What keeps it burning.
  fuel,

  /// The finished product; items can only be taken out.
  output,
}

/// The state of one furnace in the world.
///
/// Furnaces are keyed by block position, so the state survives the texture
/// swap between [BlockType.furnace] and [BlockType.furnaceLit].
class FurnaceState {
  ItemStack? input;
  ItemStack? fuel;
  ItemStack? output;

  /// Seconds of burning left from the current portion of fuel.
  double burnLeft = 0;

  /// How many seconds that portion gave, for the flame gauge.
  double burnTotal = 0;

  /// Progress on the current item, 0..1.
  double progress = 0;

  /// Ile sekund trwa wytopienie jednej sztuki.
  static const double smeltTime = 4.0;

  /// Comparison tolerance: adding up dt over hundreds of frames loses the
  /// last bits, which used to cost the fuel's final cycle.
  static const double _epsilon = 1e-9;

  bool get isLit => burnLeft > 0;

  /// Reads one of the three slots.
  ItemStack? slot(FurnaceSlot which) => switch (which) {
    FurnaceSlot.input => input,
    FurnaceSlot.fuel => fuel,
    FurnaceSlot.output => output,
  };

  /// Writes one of the three slots.
  void setSlot(FurnaceSlot which, ItemStack? stack) {
    switch (which) {
      case FurnaceSlot.input:
        input = stack;
      case FurnaceSlot.fuel:
        fuel = stack;
      case FurnaceSlot.output:
        output = stack;
    }
  }

  double get fuelFraction => burnTotal <= 0 ? 0 : burnLeft / burnTotal;

  bool get isEmpty => input == null && fuel == null && output == null;

  /// Whether anything can be smelted right now: input present, room for output.
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
      // A cold furnace loses progress slowly, as in the original.
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

    // Fuel is consumed after the work of this step, not before: otherwise
    // the last cycle of a portion was lost right at the end.
    burnLeft -= dt;
    if (burnLeft <= 0) burnTotal = 0;
  }

  void _consumeFuel() {
    final stack = fuel;
    if (stack == null || !stack.type.isFuel) return;
    burnTotal = stack.type.burnTime;
    burnLeft = burnTotal;
    final left = stack.plus(-1);
    fuel = left.isEmpty ? null : left;
  }

  void _finishSmelt() {
    final source = input!;
    final result = smeltResult(source.type)!;

    final left = source.plus(-1);
    input = left.isEmpty ? null : left;

    final slot = output;
    output = slot == null ? ItemStack(result) : slot.plus(1);
  }

  /// What to give back to the player when the furnace is broken.
  List<ItemStack> contents() =>
      [input, fuel, output].whereType<ItemStack>().toList();
}
