import '../../aiming/aim_result.dart';
import '../../aiming/target_picker.dart';
import '../game_state.dart';

/// Works out what the player is looking at, every frame.
///
/// Also owns one rule that is easy to miss: moving the crosshair to a
/// different block resets mining progress. Without it a player could chip
/// away at three blocks in parallel by sweeping the mouse.
class AimingSystem {
  const AimingSystem();

  /// How far the player can reach, in blocks.
  static const double reach = 5.5;

  void update(GameState state) {
    final previous = state.aim;
    state.aim = pickTarget(
      world: state.world,
      mobs: state.mobs,
      eye: state.player.eye,
      direction: state.player.lookDirection,
      reach: reach,
    );

    final aim = state.aim;
    if (aim is! BlockTarget) {
      state.breakProgress = 0;
      return;
    }
    if (previous is! BlockTarget || !previous.hit.samePosition(aim.hit)) {
      state.breakProgress = 0;
    }
  }
}
