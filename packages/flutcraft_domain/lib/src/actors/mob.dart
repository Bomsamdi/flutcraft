import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';
import '../blocks/block_type.dart';
import '../items/item_type.dart';
import '../loot/loot_table.dart';
import 'mob_behavior.dart';
import '../blocks/tile.dart';
import 'player.dart';
import 'entity_id.dart';
import 'player_id.dart';
import '../physics/voxel_body.dart';
import '../world/voxel_world.dart';

/// The mob species and their stats.
enum MobKind {
  zombie(
    maxHealth: 20,
    speed: 2.3,
    width: 0.6,
    height: 1.9,
    damage: 2,
    attackCooldown: 1.2,
    weight: 40,
    skin: Tile.zombieSkin,
    face: Tile.zombieFace,
    behavior: MeleeBehavior(),
  ),
  skeleton(
    maxHealth: 16,
    speed: 2.6,
    width: 0.6,
    height: 1.9,
    damage: 2,
    attackCooldown: 2.2,
    weight: 25,
    skin: Tile.skeletonSkin,
    face: Tile.skeletonFace,
    behavior: RangedBehavior(),
  ),
  spider(
    maxHealth: 14,
    speed: 4.2,
    width: 1.2,
    height: 0.9,
    damage: 2,
    attackCooldown: 0.9,
    weight: 25,
    jumpSpeed: 9.5,
    skin: Tile.spiderSkin,
    face: Tile.spiderFace,
    behavior: MeleeBehavior(),
  ),
  creeper(
    maxHealth: 18,
    speed: 2.6,
    width: 0.6,
    height: 1.7,
    damage: 0,
    attackCooldown: 0,
    weight: 10,
    skin: Tile.creeperSkin,
    face: Tile.creeperFace,
    behavior: ExplodeBehavior(
      primeDistance: 3,
      fuseSeconds: 1.6,
      radius: 3.4,
      damage: 14,
    ),
  );

  const MobKind({
    required this.maxHealth,
    required this.speed,
    required this.width,
    required this.height,
    required this.damage,
    required this.attackCooldown,
    required this.skin,
    required this.face,
    required this.weight,
    required this.behavior,
    this.jumpSpeed = 8.2,
  });
  final int maxHealth;
  final double speed;
  final double width;
  final double height;
  final int damage;
  final double attackCooldown;
  final double jumpSpeed;
  final Tile skin;
  final Tile face;

  /// Relative chance of spawning — creepers are meant to be rare.
  final int weight;

  /// How this species behaves. A new behaviour is a new MobBehavior, not
  /// another branch inside Mob.
  final MobBehavior behavior;

  /// What it drops when killed — the same type blocks use.
  LootTable get loot => switch (this) {
    MobKind.skeleton => LootTable([
      const LootEntry(ItemType.bone, min: 1, max: 2),
      const LootEntry(ItemType.arrow, min: 1, max: 2, chance: 0.6),
    ]),
    MobKind.spider => LootTable([
      const LootEntry(ItemType.string, min: 1, max: 2),
    ]),
    MobKind.creeper => LootTable([
      const LootEntry(ItemType.gunpowder, min: 1, max: 2),
    ]),
    // A zombie only occasionally drops iron, as in the original.
    MobKind.zombie => LootTable([
      const LootEntry(ItemType.ironIngot, chance: 0.12),
    ]),
  };
}

/// What a mob is doing with itself.
enum MobMood {
  /// Standing around where it belongs.
  waiting,

  /// After somebody.
  chasing,

  /// Walking back to where the chase began, deaf to the player.
  ///
  /// Deaf on purpose. A mob that took an interest again the moment it stepped
  /// back inside its leash would bounce on the boundary for ever: out, in,
  /// out, in. Hitting it wakes it up — see [Mob.damage].
  returning,
}

/// One mob: a physical body plus a small state machine.
class Mob extends VoxelBody {
  // ignore: use_super_parameters
  Mob({required this.kind, required VoxelWorld world, required Vector3 spawn})
    : health = kind.maxHealth.toDouble(),
      _anchor = spawn.clone(),
      super(world: world, spawn: spawn, width: kind.width, height: kind.height);

  final MobKind kind;

  double health;

  /// What this mob is called on the wire.
  ///
  /// Assigned when the world takes the mob in, never by the mob itself, so
  /// that ids come from one counter and stay unique. Reading it before then
  /// fails loudly rather than handing out a zero that means nothing.
  late final EntityId id;

  /// Which way it faces, in radians; 0 is -Z.
  double yaw = 0;

  /// Where it is in its walk cycle.
  double walkPhase = 0;

  /// How fast the limbs move this frame; 0 means standing still.
  double walkSpeed = 0;

  double attackTimer = 0;
  double hurtFlash = 0;

  /// A creeper's fuse; -1 means unlit.
  double fuse = -1;

  bool removed = false;

  /// How far it notices the player. Must exceed [MobSpawner.minDistance],
  /// or freshly spawned mobs stand around doing nothing until the player
  /// walks up to them.
  static const double aggroRange = 20;

  /// How far from [anchor] a chase may drag it before it gives up.
  ///
  /// Aggro range alone is no limit at all. It is measured to the player, and
  /// that distance does not grow while the player walks away with a mob
  /// behind them, so every mob that ever noticed you joins the queue and the
  /// world empties out behind it. This is measured to a fixed point instead,
  /// and a fixed point is something a player can outrun.
  ///
  /// Must exceed [MobSpawner.maxDistance]: a mob is anchored where it spawns,
  /// so a shorter leash would run out on the way over and the player would
  /// watch it turn back just short of arriving.
  static const double leashRange = 32;

  /// Near enough to the anchor to stop walking and call it home.
  static const double settleRange = 1.5;

  /// What it is doing: waiting, chasing, or on its way back.
  MobMood mood = MobMood.waiting;

  final Vector3 _anchor;

  /// The point the leash is measured from — where the current pursuit began.
  ///
  /// Not the spawn. A mob that spawned twenty blocks off has already spent
  /// most of a spawn-anchored leash getting to the player, so the same number
  /// would buy one mob a long chase and the next none at all. It moves when a
  /// pursuit starts, which makes every chase the same length.
  Vector3 get anchor => _anchor;

  bool get isDead => health <= 0;

  bool get isPrimed => fuse >= 0;

  Vector3 get eye =>
      Vector3(position.x, position.y + height * 0.85, position.z);

  void update(double dt, Player player, MobTickContext context) {
    // A dead mob is only waiting to be cleaned up; without this a creeper
    // could explode several times in one frame.
    if (isDead) return;

    if (attackTimer > 0) attackTimer -= dt;
    if (hurtFlash > 0) hurtFlash -= dt;

    final toPlayer = Vector3(
      player.position.x - position.x,
      0,
      player.position.z - position.z,
    );
    final distance = toPlayer.length;

    final was = mood;
    mood = _nextMood(player, distance);
    // The leash is measured from wherever the chase started, so a chase that
    // is starting now starts here.
    if (mood == MobMood.chasing && was != MobMood.chasing) {
      _anchor.setFrom(position);
    }
    final chasing = mood == MobMood.chasing;

    if (chasing) {
      yaw = math.atan2(-toPlayer.x, -toPlayer.z);
    }

    final desired = chasing
        ? kind.behavior.desiredSpeed(this, distance, player)
        : 0.0;
    if (desired != 0 && distance > 1e-3) {
      final dir = toPlayer / distance * desired;
      velocity
        ..x = dir.x
        ..z = dir.z;
    } else if (mood == MobMood.returning) {
      _headFor(_anchor);
    } else {
      velocity
        ..x = 0
        ..z = 0;
    }

    stepPhysics(dt);

    // Pathfinding, such as it is: something in the way means jump. A mob on
    // its way home needs this as much as one in pursuit — walled in at the
    // far end of its leash, it would never get back.
    if (blockedHorizontally && onGround && mood != MobMood.waiting) {
      velocity.y = kind.jumpSpeed;
    }

    walkSpeed = math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z);
    walkPhase += walkSpeed * dt * 3.2;

    if (chasing) {
      kind.behavior.act(this, dt, distance, player, context);
    } else if (isPrimed) {
      fuse = -1;
    }

    if (position.y < -8) health = 0;
  }

  /// Decides between waiting, chasing and going home.
  ///
  /// Written as one function returning the next mood rather than as
  /// assignments scattered through [update], because the interesting part of
  /// this change is the three rules and not where each of them fires.
  MobMood _nextMood(Player player, double distanceToPlayer) {
    final fromAnchor = _flatDistanceTo(_anchor);

    // Somebody on their way back is not looking for a fight.
    if (mood == MobMood.returning) {
      return fromAnchor <= settleRange ? MobMood.waiting : MobMood.returning;
    }

    final interested = distanceToPlayer < aggroRange && !player.isDead;
    if (!interested || fromAnchor >= leashRange) {
      return fromAnchor <= settleRange ? MobMood.waiting : MobMood.returning;
    }
    return MobMood.chasing;
  }

  /// Walks towards a point on the ground, unhurried: it is going home, not
  /// hunting.
  void _headFor(Vector3 target) {
    final away = Vector3(target.x - position.x, 0, target.z - position.z);
    final distance = away.length;
    if (distance < 1e-3) {
      velocity
        ..x = 0
        ..z = 0;
      return;
    }
    yaw = math.atan2(-away.x, -away.z);
    final step = away / distance * (kind.speed * 0.6);
    velocity
      ..x = step.x
      ..z = step.z;
  }

  /// Distance ignoring height: a mob two blocks up a hill is not further off.
  double _flatDistanceTo(Vector3 point) {
    final dx = point.x - position.x;
    final dz = point.z - position.z;
    return math.sqrt(dx * dx + dz * dz);
  }

  /// Whether it has a clear line of fire to the player.
  bool hasLineOfSightTo(Player player) {
    final target = player.eye;
    final dir = Vector3(target.x - eye.x, target.y - eye.y, target.z - eye.z);
    final distance = dir.length;
    if (distance < 1e-3) return true;
    dir.normalize();
    final hit = world.raycast(eye, dir, distance);
    return hit == null;
  }

  /// Who struck this mob last, if a player did.
  ///
  /// The loot goes to whoever landed the killing blow. Handing it to the
  /// nearest player instead would mean walking past someone else's fight and
  /// collecting the bones.
  PlayerId? lastHitBy;

  /// Damages the mob and knocks it back.
  ///
  /// [by] is the player responsible, when one is.
  void damage(double amount, {Vector3? source, PlayerId? by}) {
    if (isDead) return;
    health -= amount;
    hurtFlash = 0.25;
    if (by != null) lastHitBy = by;

    // Being hit is an invitation that cannot be refused. Without this, a mob
    // walking home would take an axe in the back without turning round, and
    // the leash would read as a bug rather than as a rule. The anchor moves
    // here too: the fight is starting where the fight is, so the player gets
    // a full leash of chase out of picking it.
    if (mood != MobMood.chasing) {
      _anchor.setFrom(position);
      mood = MobMood.chasing;
    }

    if (source != null) {
      final push = Vector3(position.x - source.x, 0, position.z - source.z);
      if (push.length2 > 1e-6) {
        push
          ..normalize()
          ..scale(5.0);
        velocity
          ..x = push.x
          ..z = push.z;
        if (onGround) velocity.y = 4.0;
      }
    }
  }
}

/// An arrow loosed by a skeleton.
class Arrow extends VoxelBody {
  // ignore: use_super_parameters
  Arrow({
    required VoxelWorld world,
    required Vector3 spawn,
    required Vector3 direction,
  }) : super(world: world, spawn: spawn, width: 0.2, height: 0.2) {
    velocity.setFrom(direction * speed);
    yaw = math.atan2(-direction.x, -direction.z);
    pitch = math.asin(direction.y.clamp(-1.0, 1.0));
  }

  /// What this arrow is called on the wire; see [Mob.id].
  late final EntityId id;

  static const double speed = 26;
  static const int damage = 3;

  double life = 0;
  double yaw = 0;
  double pitch = 0;
  bool removed = false;

  void update(double dt, Player player) {
    life += dt;
    if (life > 6) {
      removed = true;
      return;
    }

    final before = position.clone();
    stepPhysics(math.min(dt, 1 / 60), gravity: 9, terminal: 40);

    // Stopped in flight means it stuck into a block.
    if (position.distanceToSquared(before) < 1e-8 || onGround) {
      removed = true;
      return;
    }

    pitch = math.atan2(
      velocity.y,
      math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z),
    );

    if (_hits(player)) {
      player.damage(damage, source: position);
      removed = true;
    }
  }

  bool _hits(Player player) {
    return position.x > player.position.x - player.halfWidth - 0.15 &&
        position.x < player.position.x + player.halfWidth + 0.15 &&
        position.z > player.position.z - player.halfWidth - 0.15 &&
        position.z < player.position.z + player.halfWidth + 0.15 &&
        position.y > player.position.y - 0.15 &&
        position.y < player.position.y + player.height + 0.15;
  }
}

/// Spawns mobs near the player, keeping the population in check.
class MobSpawner {
  MobSpawner({required this.world, this.maxMobs = 6, int seed = 7})
    : _rng = math.Random(seed);

  final VoxelWorld world;
  final int maxMobs;
  final math.Random _rng;

  double _timer = 0;

  /// Seconds between attempts to add another mob.
  static const double interval = 6.0;
  static const double minDistance = 12;
  static const double maxDistance = 26;

  math.Random get rng => _rng;

  /// Returns a new mob, or `null` when there is no room or no luck.
  Mob? maybeSpawn(double dt, Player player, int currentCount) {
    _timer += dt;
    if (_timer < interval) return null;
    _timer = 0;
    if (currentCount >= maxMobs) return null;

    for (var attempt = 0; attempt < 12; attempt++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final radius =
          minDistance + _rng.nextDouble() * (maxDistance - minDistance);
      final x = (player.position.x + math.cos(angle) * radius).round();
      final z = (player.position.z + math.sin(angle) * radius).round();
      if (x < 2 || z < 2 || x >= world.sizeX - 2 || z >= world.sizeZ - 2) {
        continue;
      }

      final surface = world.surfaceHeight(x, z);
      if (surface < 1 || surface > world.sizeY - 6) continue;
      if (world.blockAt(x, surface, z) == BlockType.leaves) continue;

      final kind = _pickKind();
      final spawn = Vector3(x + 0.5, surface + 1.0, z + 0.5);
      final mob = Mob(kind: kind, world: world, spawn: spawn);
      // Never wedge a mob into a wall or a ceiling.
      if (mob.collides()) continue;
      return mob;
    }
    return null;
  }

  /// Picks a species, weighted by [MobKind.weight].
  MobKind _pickKind() {
    final total = MobKind.values.fold(0, (sum, k) => sum + k.weight);
    var roll = _rng.nextInt(total);
    for (final kind in MobKind.values) {
      roll -= kind.weight;
      if (roll < 0) return kind;
    }
    return MobKind.zombie;
  }
}
