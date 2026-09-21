/// Something the player can ask for, independent of how they asked.
///
/// A key, a button, a gamepad stick and a touch control all produce actions,
/// never key codes. That is what makes rebinding a one-line change instead of
/// a hunt through the code for every place a key was compared.
enum GameAction {
  moveForward,
  moveBack,
  strafeLeft,
  strafeRight,
  jump,

  /// Run on the ground, descend while flying.
  sprint,
  crouch,

  lookLeft,
  lookRight,
  lookUp,
  lookDown,

  /// Break blocks, hit mobs.
  primary,

  /// Place a block, or use the one aimed at.
  secondary,

  toggleInventory,
  toggleRecipes,
  toggleFlight,
  closeScreen,
  respawn,
  saveGame,

  nextSlot,
  previousSlot,

  hotbar1,
  hotbar2,
  hotbar3,
  hotbar4,
  hotbar5,
  hotbar6,
  hotbar7,
  hotbar8,
  hotbar9;

  /// The hotbar slot this action selects, or `null` if it selects none.
  int? get hotbarIndex {
    final first = GameAction.hotbar1.index;
    final offset = index - first;
    return offset >= 0 && offset < 9 ? offset : null;
  }

  /// Actions that only make sense while being held down.
  bool get isContinuous => switch (this) {
    moveForward ||
    moveBack ||
    strafeLeft ||
    strafeRight ||
    jump ||
    sprint ||
    crouch ||
    lookLeft ||
    lookRight ||
    lookUp ||
    lookDown ||
    primary ||
    secondary => true,
    _ => false,
  };
}
