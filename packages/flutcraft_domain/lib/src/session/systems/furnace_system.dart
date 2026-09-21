import '../game_state.dart';

/// Keeps every furnace burning and its block texture in sync.
///
/// Runs even while a screen is open — a furnace does not stop smelting just
/// because the player opened their inventory.
class FurnaceSystem {
  const FurnaceSystem();

  void update(GameState state, double dt) {
    if (state.furnaces.isEmpty) return;

    for (final pos in state.furnaces.tick(dt)) {
      final current = state.world.blockAt(pos.x, pos.y, pos.z);
      if (!current.hasLitVariant) continue;

      final lit = state.furnaces[pos]!.isLit;
      final wanted =
          (lit ? current.litVariant : current.unlitVariant) ?? current;
      if (current != wanted) state.world.setBlock(pos.x, pos.y, pos.z, wanted);
    }
  }
}
