import 'package:vector_math/vector_math.dart';

import 'mob.dart';
import 'player.dart';

/// How a mob decides to move and what it does when it gets close enough.
///
/// Pulled out of [Mob] so that adding a species no longer means editing the
/// class every existing species shares. Previously `_act` branched on
/// `kind.explodes` and `kind.ranged`, which meant any new behaviour widened
/// that method.
abstract interface class MobBehavior {
  /// Speed the mob wants this frame. Negative means backing away.
  double desiredSpeed(Mob mob, double distanceToPlayer);

  /// Runs once per frame while the player is within aggro range.
  void act(Mob mob, double dt, double distance, MobTickContext context);
}

/// Walks straight at the player and hits them in melee range.
final class MeleeBehavior implements MobBehavior {
  const MeleeBehavior();

  @override
  double desiredSpeed(Mob mob, double distanceToPlayer) => mob.kind.speed;

  @override
  void act(Mob mob, double dt, double distance, MobTickContext context) {
    final player = context.player;
    final reach = 0.8 + mob.kind.width / 2 + player.halfWidth;
    final verticalOverlap =
        (player.position.y - mob.position.y).abs() < mob.kind.height + 0.5;

    if (distance <= reach && verticalOverlap && mob.attackTimer <= 0) {
      mob.attackTimer = mob.kind.attackCooldown;
      player.damage(mob.kind.damage, source: mob.position);
    }
  }
}

/// Keeps its distance and shoots, but never through a wall.
final class RangedBehavior implements MobBehavior {
  const RangedBehavior({
    this.approachAbove = 11,
    this.retreatBelow = 5,
    this.minShootRange = 2.5,
    this.maxShootRange = 16,
  });

  /// Closes in when further away than this.
  final double approachAbove;

  /// Backs off when closer than this.
  final double retreatBelow;

  final double minShootRange;
  final double maxShootRange;

  @override
  double desiredSpeed(Mob mob, double distanceToPlayer) {
    if (distanceToPlayer > approachAbove) return mob.kind.speed;
    if (distanceToPlayer < retreatBelow) return -mob.kind.speed * 0.8;
    return 0;
  }

  @override
  void act(Mob mob, double dt, double distance, MobTickContext context) {
    if (distance >= maxShootRange || distance <= minShootRange) return;
    if (mob.attackTimer > 0) return;
    if (!mob.hasLineOfSightTo(context.player)) return;

    mob.attackTimer = mob.kind.attackCooldown;
    final target = context.player.eye;
    // Aim slightly high so the arrow's drop lands it on target.
    final direction = Vector3(
      target.x - mob.eye.x,
      target.y - mob.eye.y + distance * 0.06,
      target.z - mob.eye.z,
    )..normalize();
    context.spawnArrow(mob.eye, direction);
  }
}

/// Closes in, lights a fuse, and takes the terrain with it.
final class ExplodeBehavior implements MobBehavior {
  const ExplodeBehavior({
    required this.primeDistance,
    required this.fuseSeconds,
    required this.radius,
    required this.damage,
    this.abandonDistance = 5,
  });

  /// Lights the fuse once the player is this close.
  final double primeDistance;

  final double fuseSeconds;
  final double radius;
  final int damage;

  /// The fuse goes out if the player gets further away than this.
  final double abandonDistance;

  @override
  double desiredSpeed(Mob mob, double distanceToPlayer) => mob.kind.speed;

  @override
  void act(Mob mob, double dt, double distance, MobTickContext context) {
    // An explosion cannot be undone, so the strategy checks this itself
    // rather than trusting every caller to test isDead first.
    if (mob.isDead) return;

    if (distance < primeDistance) {
      if (!mob.isPrimed) mob.fuse = 0;
      mob.fuse += dt;
      if (mob.fuse >= fuseSeconds) {
        mob.fuse = -1;
        mob.health = 0;
        context.explode(mob.center, radius, damage);
      }
      return;
    }
    if (mob.isPrimed && distance > abandonDistance) mob.fuse = -1;
  }
}

/// What a behaviour is allowed to do to the world around it.
abstract interface class MobTickContext {
  Player get player;

  void spawnArrow(Vector3 from, Vector3 direction);

  void explode(Vector3 at, double radius, int maxDamage);
}
