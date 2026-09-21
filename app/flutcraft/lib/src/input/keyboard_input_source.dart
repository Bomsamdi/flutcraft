import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutter/services.dart';

/// The keyboard layout the game starts with.
///
/// Key ids are what crosses into the domain, so the mapping from a physical
/// key to an action lives here, on the platform side. Changing a key is
/// changing this table — nothing in the simulation compares keys at all.
final Keymap defaultKeymap = Keymap({
  LogicalKeyboardKey.keyW.keyId: GameAction.moveForward,
  LogicalKeyboardKey.keyS.keyId: GameAction.moveBack,
  LogicalKeyboardKey.keyA.keyId: GameAction.strafeLeft,
  LogicalKeyboardKey.keyD.keyId: GameAction.strafeRight,
  LogicalKeyboardKey.space.keyId: GameAction.jump,
  LogicalKeyboardKey.shiftLeft.keyId: GameAction.sprint,
  LogicalKeyboardKey.arrowLeft.keyId: GameAction.lookLeft,
  LogicalKeyboardKey.arrowRight.keyId: GameAction.lookRight,
  LogicalKeyboardKey.arrowUp.keyId: GameAction.lookUp,
  LogicalKeyboardKey.arrowDown.keyId: GameAction.lookDown,
  LogicalKeyboardKey.keyR.keyId: GameAction.secondary,
  LogicalKeyboardKey.keyE.keyId: GameAction.toggleInventory,
  LogicalKeyboardKey.keyB.keyId: GameAction.toggleRecipes,
  LogicalKeyboardKey.keyF.keyId: GameAction.toggleFlight,
  LogicalKeyboardKey.escape.keyId: GameAction.closeScreen,
  LogicalKeyboardKey.f5.keyId: GameAction.saveGame,
  LogicalKeyboardKey.digit1.keyId: GameAction.hotbar1,
  LogicalKeyboardKey.digit2.keyId: GameAction.hotbar2,
  LogicalKeyboardKey.digit3.keyId: GameAction.hotbar3,
  LogicalKeyboardKey.digit4.keyId: GameAction.hotbar4,
  LogicalKeyboardKey.digit5.keyId: GameAction.hotbar5,
  LogicalKeyboardKey.digit6.keyId: GameAction.hotbar6,
  LogicalKeyboardKey.digit7.keyId: GameAction.hotbar7,
  LogicalKeyboardKey.digit8.keyId: GameAction.hotbar8,
  LogicalKeyboardKey.digit9.keyId: GameAction.hotbar9,
});

/// Turns the keys the platform reports into actions on a router.
///
/// Flutter hands over the whole set of keys that are down, not the change,
/// so the source pushes that set as a whole. A key released while the window
/// was in the background simply stops appearing, instead of staying stuck.
class KeyboardInputSource {
  KeyboardInputSource({required this.router, Keymap? keymap})
    : keymap = keymap ?? defaultKeymap;

  final InputRouter router;

  /// Swap this and every key changes at once — that is the whole point.
  Keymap keymap;

  void onKeysChanged(Set<LogicalKeyboardKey> keysPressed) => router.setHeld({
    for (final key in keysPressed) ?keymap.actionFor(key.keyId),
  });
}
