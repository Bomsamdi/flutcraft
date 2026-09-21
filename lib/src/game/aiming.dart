import 'package:flame_3d/core.dart';
import 'package:flutcraft/src/game/mob.dart';
import 'package:flutcraft/src/world/voxel_world.dart';

/// Co znalazł promień z oka gracza: blok, potwór albo nic.
class AimResult {
  const AimResult.block(this.blockHit) : mob = null;
  const AimResult.mob(this.mob) : blockHit = null;

  static const AimResult nothing = AimResult.block(null);

  final RayHit? blockHit;
  final Mob? mob;

  bool get isMob => mob != null;

  bool get isEmpty => mob == null && blockHit == null;
}

/// Wybiera cel pod celownikiem.
///
/// Potwór wygrywa tylko wtedy, gdy stoi bliżej niż trafiony blok - dzięki
/// temu nie da się uderzyć zombie przez ścianę.
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

  if (nearest != null) return AimResult.mob(nearest);
  if (blockHit == null) return AimResult.nothing;
  return AimResult.block(blockHit);
}
