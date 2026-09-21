import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';
import '../blocks/block_type.dart';
import '../items/item_type.dart';
import '../loot/loot_table.dart';
import '../blocks/tile.dart';
import 'player.dart';
import '../physics/voxel_body.dart';
import '../world/voxel_world.dart';

/// Gatunki potworów i ich statystyki.
enum MobKind {
  zombie(
    label: 'Zombie',
    maxHealth: 20,
    speed: 2.3,
    width: 0.6,
    height: 1.9,
    damage: 2,
    attackCooldown: 1.2,
    weight: 40,
    skin: Tile.zombieSkin,
    face: Tile.zombieFace,
  ),
  skeleton(
    label: 'Szkielet',
    maxHealth: 16,
    speed: 2.6,
    width: 0.6,
    height: 1.9,
    damage: 2,
    attackCooldown: 2.2,
    weight: 25,
    skin: Tile.skeletonSkin,
    face: Tile.skeletonFace,
    ranged: true,
  ),
  spider(
    label: 'Pająk',
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
  ),
  creeper(
    label: 'Creeper',
    maxHealth: 18,
    speed: 2.6,
    width: 0.6,
    height: 1.7,
    damage: 0,
    attackCooldown: 0,
    weight: 10,
    skin: Tile.creeperSkin,
    face: Tile.creeperFace,
    explodes: true,
  );

  const MobKind({
    required this.label,
    required this.maxHealth,
    required this.speed,
    required this.width,
    required this.height,
    required this.damage,
    required this.attackCooldown,
    required this.skin,
    required this.face,
    required this.weight,
    this.jumpSpeed = 8.2,
    this.ranged = false,
    this.explodes = false,
  });

  final String label;
  final int maxHealth;
  final double speed;
  final double width;
  final double height;
  final int damage;
  final double attackCooldown;
  final double jumpSpeed;
  final Tile skin;
  final Tile face;

  /// Względna szansa pojawienia się - creepery mają być rzadkie.
  final int weight;

  /// Strzela zamiast bić w zwarciu.
  final bool ranged;

  /// Wybucha zamiast atakować.
  final bool explodes;

  /// Co upuszcza po śmierci - ten sam typ co przy blokach.
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
    // Zombie tylko sporadycznie gubi żelazo - tak jak w oryginale.
    MobKind.zombie => LootTable([
      const LootEntry(ItemType.ironIngot, chance: 0.12),
    ]),
  };
}

/// Zdarzenia, które potwór zgłasza światu gry.
abstract class MobContext {
  void spawnArrow(Vector3 from, Vector3 direction);

  void explode(Vector3 at, double radius, int maxDamage);
}

/// Pojedynczy potwór: bryła fizyczna plus prosta maszyna stanów.
class Mob extends VoxelBody {
  // ignore: use_super_parameters
  Mob({
    required this.kind,
    required VoxelWorld world,
    required Vector3 spawn,
  }) : health = kind.maxHealth.toDouble(),
       super(
         world: world,
         spawn: spawn,
         width: kind.width,
         height: kind.height,
       );

  final MobKind kind;

  double health;

  /// Kierunek, w którym potwór patrzy (radiany, 0 = -Z).
  double yaw = 0;

  /// Faza animacji chodu.
  double walkPhase = 0;

  /// Jak szybko kończyny się ruszają w tej klatce (0 = stoi).
  double walkSpeed = 0;

  double attackTimer = 0;
  double hurtFlash = 0;

  /// Lont creepera; -1 oznacza "niezapalony".
  double fuse = -1;

  bool removed = false;

  /// Zasięg wykrywania gracza. Musi być większy niż
  /// [MobSpawner.minDistance], inaczej świeżo postawione potwory stoją
  /// bezczynnie, dopóki gracz sam do nich nie podejdzie.
  static const double aggroRange = 20;

  bool get isDead => health <= 0;

  bool get isPrimed => fuse >= 0;

  Vector3 get eye =>
      Vector3(position.x, position.y + height * 0.85, position.z);

  void update(double dt, Player player, MobContext context) {
    // Martwy potwór czeka tylko na sprzątnięcie - bez tego creeper
    // mógłby wybuchnąć kilka razy w tej samej klatce.
    if (isDead) return;

    final step = math.min(dt, 1 / 30);

    if (attackTimer > 0) attackTimer -= dt;
    if (hurtFlash > 0) hurtFlash -= dt;

    final toPlayer = Vector3(
      player.position.x - position.x,
      0,
      player.position.z - position.z,
    );
    final distance = toPlayer.length;
    final chasing = distance < aggroRange && !player.isDead;

    if (chasing) {
      yaw = math.atan2(-toPlayer.x, -toPlayer.z);
    }

    final desired = chasing ? _desiredSpeed(distance) : 0.0;
    if (desired != 0 && distance > 1e-3) {
      final dir = toPlayer / distance * desired;
      velocity
        ..x = dir.x
        ..z = dir.z;
    } else {
      velocity
        ..x = 0
        ..z = 0;
    }

    stepPhysics(step);

    // Prosty "pathfinding": przeszkoda na drodze = podskok.
    if (blockedHorizontally && onGround && chasing) {
      velocity.y = kind.jumpSpeed;
    }

    walkSpeed = math.sqrt(
      velocity.x * velocity.x + velocity.z * velocity.z,
    );
    walkPhase += walkSpeed * step * 3.2;

    if (chasing) {
      _act(dt, distance, player, context);
    } else if (isPrimed) {
      fuse = -1;
    }

    if (position.y < -8) health = 0;
  }

  /// Szkielet trzyma dystans, reszta prze na gracza.
  double _desiredSpeed(double distance) {
    if (!kind.ranged) return kind.speed;
    if (distance > 11) return kind.speed;
    if (distance < 5) return -kind.speed * 0.8;
    return 0;
  }

  void _act(double dt, double distance, Player player, MobContext context) {
    if (kind.explodes) {
      _tickFuse(dt, distance, context);
      return;
    }

    if (kind.ranged) {
      if (distance < 16 && distance > 2.5 && attackTimer <= 0 && _canSee(player)) {
        attackTimer = kind.attackCooldown;
        final target = player.eye;
        final dir = Vector3(
          target.x - eye.x,
          target.y - eye.y + distance * 0.06,
          target.z - eye.z,
        )..normalize();
        context.spawnArrow(eye, dir);
      }
      return;
    }

    final reach = 0.8 + kind.width / 2 + player.halfWidth;
    final verticalOverlap =
        (player.position.y - position.y).abs() < kind.height + 0.5;
    if (distance <= reach && verticalOverlap && attackTimer <= 0) {
      attackTimer = kind.attackCooldown;
      player.damage(kind.damage, source: position);
    }
  }

  void _tickFuse(double dt, double distance, MobContext context) {
    if (distance < 3.0) {
      if (!isPrimed) fuse = 0;
      fuse += dt;
      if (fuse >= 1.6) {
        fuse = -1;
        health = 0;
        context.explode(center, 3.4, 14);
      }
    } else if (isPrimed) {
      // Gracz uciekł - lont gaśnie.
      fuse = distance > 5 ? -1 : fuse;
    }
  }

  /// Czy potwór ma czystą linię strzału do gracza.
  bool _canSee(Player player) {
    final target = player.eye;
    final dir = Vector3(
      target.x - eye.x,
      target.y - eye.y,
      target.z - eye.z,
    );
    final distance = dir.length;
    if (distance < 1e-3) return true;
    dir.normalize();
    final hit = world.raycast(eye, dir, distance);
    return hit == null;
  }

  /// Zadaje potworowi obrażenia i odrzuca go.
  void damage(double amount, {Vector3? source}) {
    if (isDead) return;
    health -= amount;
    hurtFlash = 0.25;

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

/// Strzała wystrzelona przez szkieleta.
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

    // Zatrzymana w locie znaczy, że wbiła się w blok.
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

/// Wypuszcza potwory w pobliżu gracza, trzymając populację w ryzach.
class MobSpawner {
  MobSpawner({required this.world, this.maxMobs = 6, int seed = 7})
    : _rng = math.Random(seed);

  final VoxelWorld world;
  final int maxMobs;
  final math.Random _rng;

  double _timer = 0;

  /// Co ile sekund próbować dosypać potwora.
  static const double interval = 6.0;
  static const double minDistance = 12;
  static const double maxDistance = 26;

  math.Random get rng => _rng;

  /// Zwraca nowego potwora albo `null`, gdy nie ma miejsca lub szczęścia.
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
      // Nie wciskamy potwora w ścianę ani w strop.
      if (mob.collides()) continue;
      return mob;
    }
    return null;
  }

  /// Losowanie gatunku ważone polem [MobKind.weight].
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
