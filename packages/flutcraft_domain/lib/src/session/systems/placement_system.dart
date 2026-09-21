import '../../aiming/aim_result.dart';
import '../../world/voxel_world.dart';
import '../game_event.dart';
import '../game_state.dart';

/// Placing a block from the active hotbar slot.
///
/// All the rules that decide whether a block may go somewhere live here:
/// the slot must hold a block, the target must be empty and in bounds, and
/// nothing living may be standing there. Each refusal has its own reason, so
/// the player is told *why* rather than just seeing nothing happen.
class PlacementSystem {
  /// Seconds between placements while the button is held.
  static const double cooldown = 0.22;

  double _timer = 0;

  /// Runs one frame. [active] is true while the player holds the button.
  List<GameEvent> update(GameState state, double dt, {required bool active}) {
    _timer -= dt;
    if (!active || _timer > 0) return const [];
    _timer = cooldown;
    return placeNow(state);
  }

  /// Places immediately, ignoring the cooldown — used by a single key press.
  List<GameEvent> placeNow(GameState state) {
    if (state.aim case BlockTarget(:final hit)) return _place(state, hit);
    return const [];
  }

  List<GameEvent> _place(GameState state, RayHit hit) {
    final stack = state.inventory[state.selectedSlot];
    final item = stack?.type;
    final block = item?.block;
    if (stack == null || block == null) {
      return const [PlacementRejected(PlacementRejection.notABlock)];
    }

    final (x, y, z) = hit.placement;
    if (!state.world.inBounds(x, y, z)) return const [];
    if (state.world.blockAt(x, y, z).solid) return const [];

    if (state.player.occupies(x, y, z)) {
      return const [PlacementRejected(PlacementRejection.insidePlayer)];
    }
    if (state.mobs.any((mob) => mob.occupies(x, y, z))) {
      return const [PlacementRejected(PlacementRejection.insideMob)];
    }

    state.world.setBlock(x, y, z, block);
    state.inventory.takeFrom(state.selectedSlot, 1);
    return const [];
  }

  /// Lets a single press place a block without waiting out the cooldown.
  void resetCooldown() => _timer = 0;
}
