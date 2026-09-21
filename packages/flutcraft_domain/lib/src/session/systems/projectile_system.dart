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
      arrow.update(dt, state.player);
      if (arrow.removed) state.arrows.remove(arrow);
    }
  }

  void clear(GameState state) => state.arrows.clear();
}
