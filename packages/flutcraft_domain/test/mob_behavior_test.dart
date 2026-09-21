import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

class RecordingContext implements MobTickContext {
  RecordingContext(this.player);

  @override
  final Player player;

  final List<(Vector3, Vector3)> arrows = [];
  final List<(Vector3, double, int)> explosions = [];

  @override
  void spawnArrow(Vector3 from, Vector3 direction) =>
      arrows.add((from.clone(), direction.clone()));

  @override
  void explode(Vector3 at, double radius, int maxDamage) =>
      explosions.add((at.clone(), radius, maxDamage));
}

VoxelWorld flatWorld({int size = 64}) {
  final world = VoxelWorld(sizeX: size, sizeY: 24, sizeZ: size);
  for (var z = 0; z < size; z++) {
    for (var x = 0; x < size; x++) {
      world.setRaw(x, 0, z, BlockType.bedrock);
      world.setRaw(x, 1, z, BlockType.stone);
    }
  }
  return world;
}

void main() {
  late VoxelWorld world;
  late Player player;
  late RecordingContext context;

  setUp(() {
    world = flatWorld();
    player = Player(world: world, spawn: Vector3(32.5, 2, 32.5));
    context = RecordingContext(player);
  });

  Mob mobOf(MobKind kind, {double z = 32.5, double x = 32.5}) =>
      Mob(kind: kind, world: world, spawn: Vector3(x, 2, z));

  group('MeleeBehavior', () {
    const behavior = MeleeBehavior();

    test('it always pushes forward, whatever the distance', () {
      final mob = mobOf(MobKind.zombie);
      expect(behavior.desiredSpeed(mob, 20), MobKind.zombie.speed);
      expect(behavior.desiredSpeed(mob, 1), MobKind.zombie.speed);
    });

    test('it only hurts the player within arm\'s reach', () {
      final mob = mobOf(MobKind.zombie, x: 33.2);
      behavior.act(mob, 1 / 60, 0.7, context);
      expect(player.health, lessThan(Player.maxHealth));
    });

    test('from a distance it does no harm', () {
      final mob = mobOf(MobKind.zombie, x: 40);
      behavior.act(mob, 1 / 60, 7.5, context);
      expect(player.health, Player.maxHealth);
    });

    test('cooldown blokuje drugi cios w tej samej chwili', () {
      final mob = mobOf(MobKind.zombie, x: 33.2);
      behavior.act(mob, 1 / 60, 0.7, context);
      final afterFirst = player.health;
      player.hurtCooldown = 0; // drop the player's invulnerability
      behavior.act(mob, 1 / 60, 0.7, context);
      expect(player.health, afterFirst, reason: 'cooldown potwora trzyma');
    });
  });

  group('RangedBehavior', () {
    const behavior = RangedBehavior();

    test(
      'far off it closes in, up close it backs away, in the window it holds',
      () {
        final mob = mobOf(MobKind.skeleton);
        expect(behavior.desiredSpeed(mob, 15), greaterThan(0));
        expect(behavior.desiredSpeed(mob, 3), lessThan(0));
        expect(behavior.desiredSpeed(mob, 8), 0);
      },
    );

    test('it shoots inside its range window', () {
      final mob = mobOf(MobKind.skeleton, z: 40);
      behavior.act(mob, 1 / 60, 7.5, context);
      expect(context.arrows, hasLength(1));
    });

    test('it does not shoot from outside that window', () {
      final mob = mobOf(MobKind.skeleton, z: 40);
      behavior
        ..act(mob, 1 / 60, 1.0, context)
        ..act(mob, 1 / 60, 30.0, context);
      expect(context.arrows, isEmpty);
    });

    test('it does not shoot through a wall', () {
      for (var y = 1; y <= 6; y++) {
        for (var x = 28; x <= 38; x++) {
          world.setRaw(x, y, 36, BlockType.stone);
        }
      }
      final mob = mobOf(MobKind.skeleton, z: 40);
      behavior.act(mob, 1 / 60, 7.5, context);
      expect(context.arrows, isEmpty);
    });

    test('it aims a little high, because the arrow drops', () {
      final mob = mobOf(MobKind.skeleton, z: 40);
      behavior.act(mob, 1 / 60, 7.5, context);
      final (_, direction) = context.arrows.single;
      expect(direction.y, greaterThan(0));
    });
  });

  group('ExplodeBehavior', () {
    const behavior = ExplodeBehavior(
      primeDistance: 3,
      fuseSeconds: 1.6,
      radius: 3.4,
      damage: 14,
    );

    test('the fuse only lights up close', () {
      final mob = mobOf(MobKind.creeper);
      behavior.act(mob, 1 / 60, 5, context);
      expect(mob.isPrimed, isFalse);

      behavior.act(mob, 1 / 60, 2, context);
      expect(mob.isPrimed, isTrue);
    });

    test('po wypaleniu lontu wybucha raz i ginie', () {
      final mob = mobOf(MobKind.creeper);
      for (var i = 0; i < 200; i++) {
        behavior.act(mob, 1 / 60, 2, context);
      }
      expect(context.explosions, hasLength(1));
      expect(mob.isDead, isTrue);

      final (_, radius, damage) = context.explosions.single;
      expect(radius, 3.4);
      expect(damage, 14);
    });

    test('ucieczka gasi lont', () {
      final mob = mobOf(MobKind.creeper);
      behavior.act(mob, 1 / 60, 2, context);
      expect(mob.isPrimed, isTrue);

      behavior.act(mob, 1 / 60, 9, context);
      expect(mob.isPrimed, isFalse);
      expect(context.explosions, isEmpty);
    });
  });

  group('Every species has a behaviour', () {
    test('each species has one assigned', () {
      for (final kind in MobKind.values) {
        expect(kind.behavior, isNotNull, reason: kind.name);
      }
    });

    test('only a creeper explodes, only a skeleton shoots', () {
      expect(MobKind.creeper.behavior, isA<ExplodeBehavior>());
      expect(MobKind.skeleton.behavior, isA<RangedBehavior>());
      expect(MobKind.zombie.behavior, isA<MeleeBehavior>());
      expect(MobKind.spider.behavior, isA<MeleeBehavior>());
    });
  });
}
