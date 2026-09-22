import 'package:vector_math/vector_math.dart';

import '../../aiming/aim_result.dart';
import '../../world/voxel_world.dart';
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

  /// How much further than [reach] a claim may point.
  ///
  /// A frame of movement, and no more. It is there so that a claim is not
  /// refused over the same tick of lag it exists to paper over.
  static const double claimSlack = 1;

  void update(GameState state, Participant participant) {
    final previous = participant.aim;
    participant.aim =
        _claimed(state, participant) ??
        pickTarget(
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

  /// The block the player says they are on, if that is a thing they could be
  /// on.
  ///
  /// Checked rather than believed: the block has to be there, and it has to
  /// be within arm's length. Both are things the server knows for itself, so
  /// a client that lies gains nothing it did not already have — it can only
  /// choose among the blocks it could have reached anyway.
  ///
  /// What is deliberately *not* checked is the line of sight. It would cost
  /// a second ray per player per tick to stop a player mining the far side of
  /// a wall they are standing against, which is a small prize for a real
  /// cost; the note is here so that the omission is a decision and not an
  /// oversight.
  AimResult? _claimed(GameState state, Participant participant) {
    final claim = participant.claimedAim;
    if (claim == null) return null;

    final at = claim.at;
    final block = state.world.blockAt(at.x, at.y, at.z);
    if (!block.solid) return null;

    final eye = participant.player.eye;
    final centre = Vector3(at.x + 0.5, at.y + 0.5, at.z + 0.5);
    final distance = eye.distanceTo(centre);
    if (distance > reach + claimSlack) return null;

    return BlockTarget(
      RayHit(
        x: at.x,
        y: at.y,
        z: at.z,
        block: block,
        nx: claim.against.x - at.x,
        ny: claim.against.y - at.y,
        nz: claim.against.z - at.z,
        distance: distance,
      ),
    );
  }
}
