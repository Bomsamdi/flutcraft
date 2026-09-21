/// Which interface is open on top of the world.
///
/// Lives in the domain rather than the UI because the simulation itself
/// needs it: an open inventory freezes the world and swallows movement
/// input. Naming it a *route* rather than a *screen* keeps it honest —
/// it says where the player is, not what widget draws it.
enum UiRoute {
  /// Playing. Nothing on top of the world.
  none,

  /// Inventory with the 2x2 crafting grid.
  inventory,

  /// Crafting table with the 3x3 grid.
  craftingTable,

  /// Furnace.
  furnace,

  /// Recipe book.
  recipes,

  /// The player is dead and waiting to respawn.
  dead;

  /// Whether the world should stop simulating while this route is open.
  bool get pausesWorld => this != UiRoute.none;

  /// Whether the player can still be hurt here.
  bool get isPlayable => this == UiRoute.none;
}
