import 'package:vector_math/vector_math.dart';

import '../actors/mob.dart';
import '../world/voxel_world.dart';
import 'aim_result.dart';

/// Picks what the player is aiming at.
///
/// A mob only wins when it stands closer than the block the ray hit, which
/// is what stops the player from punching a zombie through a wall.
AimResult pickTarget({
  required VoxelWorld world,
  required Iterable<Mob> mobs,
  required Vector3 eye,
  required Vector3 direction,
  required double reach,
}) {
  final blockHit = world.raycast(eye, direction, reach);
  var nearestDistance = blockHit?.distance ?? reach;
  Mob? nearest;

  for (final mob in mobs) {
    if (mob.isDead) continue;
    final distance = mob.rayDistance(eye, direction, reach);
    if (distance == null || distance < 0 || distance > reach) continue;
    if (distance >= nearestDistance) continue;
    nearestDistance = distance;
    nearest = mob;
  }

  if (nearest != null) return MobTarget(nearest, nearestDistance);
  if (blockHit == null) return const NoTarget();
  return BlockTarget(blockHit);
}
