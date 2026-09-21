import '../machines/furnace_state.dart';
import 'ui_route.dart';

/// Which slot a click refers to.
sealed class SlotRef {
  const SlotRef();
}

final class InventorySlotRef extends SlotRef {
  const InventorySlotRef(this.index);

  final int index;
}

final class GridSlotRef extends SlotRef {
  const GridSlotRef(this.index);

  final int index;
}

final class FurnaceSlotRef extends SlotRef {
  const FurnaceSlotRef(this.slot);

  final FurnaceSlot slot;
}

/// The output of the crafting grid — items can only be taken from it.
final class CraftResultRef extends SlotRef {
  const CraftResultRef();
}

/// Left click versus right click / long press.
enum ClickKind {
  /// Picks up, drops or merges the whole stack.
  primary,

  /// Takes half a stack, or places one item at a time.
  split,
}

/// Something the player asked the game to do.
///
/// Replaces roughly twenty-five public methods that the UI used to call
/// directly on the game object. With one entry point the UI no longer needs
/// to know the engine type at all, and every player action becomes a value
/// that can be logged, replayed or tested.
sealed class GameCommand {
  const GameCommand();
}

final class SelectHotbarSlot extends GameCommand {
  const SelectHotbarSlot(this.index);

  final int index;
}

final class CycleHotbarSlot extends GameCommand {
  const CycleHotbarSlot(this.delta);

  final int delta;
}

final class ClickSlot extends GameCommand {
  const ClickSlot(this.ref, {this.kind = ClickKind.primary});

  final SlotRef ref;
  final ClickKind kind;
}

final class OpenRoute extends GameCommand {
  const OpenRoute(this.route);

  final UiRoute route;
}

/// Closes the current screen, returning grid contents to the inventory.
final class CloseRoute extends GameCommand {
  const CloseRoute();
}

/// Opens the recipe book, remembering where to go back to.
final class OpenRecipes extends GameCommand {
  const OpenRecipes();
}

final class ToggleFlight extends GameCommand {
  const ToggleFlight();
}

final class Respawn extends GameCommand {
  const Respawn();
}

/// Use the aimed block, or place one if it does nothing.
final class UseOrPlace extends GameCommand {
  const UseOrPlace();
}

/// Saves the game now, without waiting for the autosave timer.
final class SaveGame extends GameCommand {
  const SaveGame();
}
