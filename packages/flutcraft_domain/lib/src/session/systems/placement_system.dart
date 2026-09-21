import '../../aiming/aim_result.dart';
import '../../world/voxel_world.dart';
import '../game_event.dart';
import '../game_state.dart';
import '../participant.dart';

/// Placing a block from the active hotbar slot.
///
/// All the rules that decide whether a block may go somewhere live here:
/// the slot must hold a block, the target must be empty and in bounds, and
/// nothing living may be standing there. Each refusal has its own reason, so
/// the player is told *why* rather than just seeing nothing happen.
class PlacementSystem {
  const PlacementSystem();

  /// Seconds between placements while the button is held.
  static const double cooldown = 0.22;

  /// Runs one frame for one player. [active] is true while they hold the
  /// button.
  List<GameEvent> update(
    GameState state,
    Participant participant,
    double dt, {
    required bool active,
  }) {
    participant.placeTimer -= dt;
    if (!active || participant.placeTimer > 0) return const [];
    participant.placeTimer = cooldown;
    return placeNow(state, participant);
  }

  /// Places immediately, ignoring the cooldown — used by a single key press.
  List<GameEvent> placeNow(GameState state, Participant participant) {
    if (participant.aim case BlockTarget(:final hit)) {
      return _place(state, participant, hit);
    }
    return const [];
  }

  List<GameEvent> _place(GameState state, Participant participant, RayHit hit) {
    final stack = participant.inventory[participant.selectedSlot];
    final item = stack?.type;
    final block = item?.block;
    if (stack == null || block == null) {
      return const [PlacementRejected(PlacementRejection.notABlock)];
    }

    final (x, y, z) = hit.placement;
    if (!state.world.inBounds(x, y, z)) return const [];
    if (state.world.blockAt(x, y, z).solid) return const [];

    // Nobody may be built into a wall, not just whoever is placing.
    if (state.participants.values.any(
      (other) => other.player.occupies(x, y, z),
    )) {
      return const [PlacementRejected(PlacementRejection.insidePlayer)];
    }
    if (state.mobs.any((mob) => mob.occupies(x, y, z))) {
      return const [PlacementRejected(PlacementRejection.insideMob)];
    }

    state.world.setBlock(x, y, z, block);
    participant.inventory.takeFrom(participant.selectedSlot, 1);
    return const [];
  }

  /// Lets a single press place a block without waiting out the cooldown.
  void resetCooldown(Participant participant) => participant.placeTimer = 0;
}
