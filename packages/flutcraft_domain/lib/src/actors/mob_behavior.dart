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
  /// Speed the mob wants this frame. Negative means backing away, zero means
  /// it is already where it wants to be.
  double desiredSpeed(Mob mob, double distanceToTarget, Player target);

  /// Runs once per frame while [target] is within aggro range.
  void act(
    Mob mob,
    double dt,
    double distance,
    Player target,
    MobTickContext context,
  );
}

/// Walks up to the player and hits them from there.
final class MeleeBehavior implements MobBehavior {
  const MeleeBehavior({this.standOff = 0.2});

  /// How much clear space the mob wants between the two bodies.
  ///
  /// Without it a zombie walks until it is inside the player and keeps
  /// pushing; the separation system then shoves it out every frame and the
  /// fight happens in a shaking blur. Stopping at contact is both calmer to
  /// watch and easier to swing at.
  final double standOff;

  /// The distance at which the two bodies touch, plus the stand-off.
  double contactDistance(Mob mob, Player target) =>
      mob.halfWidth + target.halfWidth + standOff;

  @override
  double desiredSpeed(Mob mob, double distanceToTarget, Player target) =>
      distanceToTarget <= contactDistance(mob, target) ? 0 : mob.kind.speed;

  @override
  void act(
    Mob mob,
    double dt,
    double distance,
    Player target,
    MobTickContext context,
  ) {
    final reach = 0.8 + mob.kind.width / 2 + target.halfWidth;
    final verticalOverlap =
        (target.position.y - mob.position.y).abs() < mob.kind.height + 0.5;

    if (distance <= reach && verticalOverlap && mob.attackTimer <= 0) {
      mob.attackTimer = mob.kind.attackCooldown;
      target.damage(mob.kind.damage, source: mob.position);
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
  double desiredSpeed(Mob mob, double distanceToTarget, Player target) {
    if (distanceToTarget > approachAbove) return mob.kind.speed;
    if (distanceToTarget < retreatBelow) return -mob.kind.speed * 0.8;
    return 0;
  }

  @override
  void act(
    Mob mob,
    double dt,
    double distance,
    Player target,
    MobTickContext context,
  ) {
    if (distance >= maxShootRange || distance <= minShootRange) return;
    if (mob.attackTimer > 0) return;
    if (!mob.hasLineOfSightTo(target)) return;

    mob.attackTimer = mob.kind.attackCooldown;
    final aim = target.eye;
    // Aim slightly high so the arrow's drop lands it on target.
    final direction = Vector3(
      aim.x - mob.eye.x,
      aim.y - mob.eye.y + distance * 0.06,
      aim.z - mob.eye.z,
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

  /// Stops once the fuse is lit: it is already close enough to do the damage,
  /// and walking into the player from there only shoves them out of the blast
  /// they are trying to escape.
  @override
  double desiredSpeed(Mob mob, double distanceToTarget, Player target) =>
      distanceToTarget <= primeDistance ? 0 : mob.kind.speed;

  @override
  void act(
    Mob mob,
    double dt,
    double distance,
    Player target,
    MobTickContext context,
  ) {
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
  void spawnArrow(Vector3 from, Vector3 direction);

  void explode(Vector3 at, double radius, int maxDamage);
}
