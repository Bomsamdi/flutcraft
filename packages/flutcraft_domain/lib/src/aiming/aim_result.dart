import '../actors/mob.dart';
import '../world/voxel_world.dart';

/// What the ray from the player's eye found.
///
/// Sealed on purpose: the previous shape carried two nullable fields, so
/// "a block and a mob at once" and "neither, but not nothing" were both
/// representable even though neither can happen. Now the type system rules
/// them out and every consumer has to handle all three cases.
sealed class AimResult {
  const AimResult();
}

/// Nothing within reach.
final class NoTarget extends AimResult {
  const NoTarget();
}

/// A block is in front of the player.
final class BlockTarget extends AimResult {
  const BlockTarget(this.hit);

  final RayHit hit;
}

/// A mob is in front of the player, closer than any block.
final class MobTarget extends AimResult {
  const MobTarget(this.mob, this.distance);

  final Mob mob;

  /// Distance from the eye, in blocks.
  final double distance;
}
