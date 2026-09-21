import '../../actors/mob.dart';
import '../game_state.dart';

/// Arrows in flight.
///
/// Separate from the mobs that fired them: an arrow outlives its shooter and
/// has its own rules about hitting terrain and expiring.
class ProjectileSystem {
  const ProjectileSystem();

  void update(GameState state, double dt) {
    for (final arrow in List<Arrow>.from(state.arrows)) {
      // An arrow does not care who it was aimed at: whoever it reaches first
      // is the one it hits.
      for (final participant in state.participants.values) {
        if (arrow.removed) break;
        arrow.update(dt, participant.player);
      }
      if (arrow.removed) state.arrows.remove(arrow);
    }
  }

  void clear(GameState state) => state.arrows.clear();
}
