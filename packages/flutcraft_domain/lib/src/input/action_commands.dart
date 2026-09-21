import '../session/game_command.dart';
import '../session/ui_route.dart';
import 'game_action.dart';

/// Which command an action means, given where the player is in the interface.
///
/// Returns `null` when the action does nothing there — pressing the inventory
/// key on the death screen, say. Keeping this as one function of two values
/// means the rules can be read in one place and tested without any input at
/// all; they used to be scattered through the key handler as nested ifs.
GameCommand? commandFor(GameAction action, UiRoute route) {
  if (action.hotbarIndex case final slot?) {
    return route.pausesWorld ? null : SelectHotbarSlot(slot);
  }

  return switch (action) {
    GameAction.toggleInventory => switch (route) {
      UiRoute.dead => null,
      UiRoute.none => const OpenRoute(UiRoute.inventory),
      _ => const CloseRoute(),
    },
    GameAction.toggleRecipes =>
      route == UiRoute.dead ? null : const OpenRecipes(),
    GameAction.closeScreen => switch (route) {
      UiRoute.none || UiRoute.dead => null,
      _ => const CloseRoute(),
    },
    GameAction.toggleFlight => route.pausesWorld ? null : const ToggleFlight(),
    GameAction.respawn => route == UiRoute.dead ? const Respawn() : null,
    // A dead player has nothing to use, so the use key doubles as respawn —
    // which is exactly what the death screen offers.
    GameAction.secondary => route == UiRoute.dead ? const Respawn() : null,
    GameAction.saveGame => const SaveGame(),
    GameAction.nextSlot => route.pausesWorld ? null : const CycleHotbarSlot(1),
    GameAction.previousSlot =>
      route.pausesWorld ? null : const CycleHotbarSlot(-1),
    _ => null,
  };
}
