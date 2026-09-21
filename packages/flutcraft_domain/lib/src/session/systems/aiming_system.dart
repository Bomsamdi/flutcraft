import '../../aiming/aim_result.dart';
import '../../aiming/target_picker.dart';
import '../game_state.dart';
import '../participant.dart';

/// Works out what a player is looking at, every frame.
///
/// Also owns one rule that is easy to miss: moving the crosshair to a
/// different block resets mining progress. Without it a player could chip
/// away at three blocks in parallel by sweeping the mouse.
class AimingSystem {
  const AimingSystem();

  /// How far the player can reach, in blocks.
  static const double reach = 5.5;

  void update(GameState state, Participant participant) {
    final previous = participant.aim;
    participant.aim = pickTarget(
      world: state.world,
      mobs: state.mobs,
      eye: participant.player.eye,
      direction: participant.player.lookDirection,
      reach: reach,
    );

    final aim = participant.aim;
    if (aim is! BlockTarget) {
      participant.breakProgress = 0;
      return;
    }
    if (previous is! BlockTarget || !previous.hit.samePosition(aim.hit)) {
      participant.breakProgress = 0;
    }
  }
}
