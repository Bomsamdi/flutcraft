import 'package:vector_math/vector_math.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';

VoxelWorld emptyWorld() {
  final world = VoxelWorld(sizeX: 32, sizeY: 16, sizeZ: 32);
  for (var z = 0; z < 32; z++) {
    for (var x = 0; x < 32; x++) {
      world.setRaw(x, 0, z, BlockType.stone);
    }
  }
  return world;
}

Mob zombieAt(VoxelWorld world, double x, double z) =>
    Mob(kind: MobKind.zombie, world: world, spawn: Vector3(x, 1, z));

void main() {
  const reach = 5.5;
  final forward = Vector3(0, 0, -1);

  group('pickTarget', () {
    test('trafia potwora stojącego przed graczem', () {
      final world = emptyWorld();
      final mob = zombieAt(world, 16.5, 13.5);

      final aim = pickTarget(
        world: world,
        mobs: [mob],
        eye: Vector3(16.5, 2.6, 16.5),
        direction: forward,
        reach: reach,
      );

      expect(aim, isA<MobTarget>());
      expect((aim as MobTarget).mob, same(mob));
    });

    test('nie trafia potwora zza ściany', () {
      final world = emptyWorld();
      for (var y = 1; y <= 4; y++) {
        world.setRaw(16, y, 15, BlockType.stone);
      }
      final mob = zombieAt(world, 16.5, 13.5);

      final aim = pickTarget(
        world: world,
        mobs: [mob],
        eye: Vector3(16.5, 2.6, 16.5),
        direction: forward,
        reach: reach,
      );

      expect(aim, isA<BlockTarget>());
      expect((aim as BlockTarget).hit.block, BlockType.stone);
    });

    test('potwór poza zasięgiem ręki jest ignorowany', () {
      final world = emptyWorld();
      final mob = zombieAt(world, 16.5, 8.5);

      final aim = pickTarget(
        world: world,
        mobs: [mob],
        eye: Vector3(16.5, 2.6, 16.5),
        direction: forward,
        reach: reach,
      );

      expect(aim, isA<NoTarget>());
    });

    test('wybiera bliższego z dwóch potworów', () {
      final world = emptyWorld();
      final near = zombieAt(world, 16.5, 14.0);
      final far = zombieAt(world, 16.5, 12.0);

      final aim = pickTarget(
        world: world,
        mobs: [far, near],
        eye: Vector3(16.5, 2.6, 16.5),
        direction: forward,
        reach: reach,
      );

      expect((aim as MobTarget).mob, same(near));
    });

    test('martwy potwór nie jest celem', () {
      final world = emptyWorld();
      final mob = zombieAt(world, 16.5, 13.5)..health = 0;

      final aim = pickTarget(
        world: world,
        mobs: [mob],
        eye: Vector3(16.5, 2.6, 16.5),
        direction: forward,
        reach: reach,
      );

      expect(aim, isNot(isA<MobTarget>()));
    });

    test('patrząc w bok celuje w blok, nie w potwora obok', () {
      final world = emptyWorld();
      final mob = zombieAt(world, 16.5, 13.5);

      final aim = pickTarget(
        world: world,
        mobs: [mob],
        eye: Vector3(16.5, 2.6, 16.5),
        direction: Vector3(1, 0, 0),
        reach: reach,
      );

      expect(aim, isNot(isA<MobTarget>()));
    });

    test('patrząc pod nogi celuje w podłoże', () {
      final world = emptyWorld();

      final aim = pickTarget(
        world: world,
        mobs: const [],
        eye: Vector3(16.5, 2.6, 16.5),
        direction: Vector3(0, -1, 0),
        reach: reach,
      );

      expect(aim, isA<BlockTarget>());
      expect((aim as BlockTarget).hit.y, 0);
    });
  });

  _sealedSwitchTests();

  group('Obrażenia od trzymanego przedmiotu', () {
    test('miecz bije mocniej niż kilof, kilof mocniej niż ręka', () {
      const bare = 1;
      expect(ItemType.woodenPickaxe.damage, greaterThan(bare));
      expect(
        ItemType.woodenSword.damage,
        greaterThan(ItemType.woodenPickaxe.damage),
      );
      expect(
        ItemType.ironSword.damage,
        greaterThan(ItemType.stoneSword.damage),
      );
    });

    test('żelazny miecz zabija pająka w dwóch ciosach', () {
      final world = emptyWorld();
      final mob = Mob(
        kind: MobKind.spider,
        world: world,
        spawn: Vector3(16.5, 1, 16.5),
      );

      mob.damage(ItemType.ironSword.damage.toDouble());
      expect(mob.isDead, isFalse);
      mob.damage(ItemType.ironSword.damage.toDouble());
      expect(mob.isDead, isTrue);
    });

    test('gołą ręką zombie ginie po dwudziestu ciosach', () {
      final world = emptyWorld();
      final mob = Mob(
        kind: MobKind.zombie,
        world: world,
        spawn: Vector3(16.5, 1, 16.5),
      );

      for (var i = 0; i < 19; i++) {
        mob.damage(1);
      }
      expect(mob.isDead, isFalse);
      mob.damage(1);
      expect(mob.isDead, isTrue);
    });
  });
}

void _sealedSwitchTests() {
  group('Wyczerpujący switch', () {
    /// Kompilator wymusza obsługę wszystkich trzech przypadków — dodanie
    /// czwartego wariantu AimResult wywali to w czasie kompilacji.
    String describe(AimResult aim) => switch (aim) {
      NoTarget() => 'nic',
      BlockTarget(:final hit) => 'blok ${hit.block.name}',
      MobTarget(:final mob) => 'potwór ${mob.kind.name}',
    };

    test('każdy wariant ma swój opis', () {
      final world = emptyWorld();
      expect(describe(const NoTarget()), 'nic');

      final aimAtBlock = pickTarget(
        world: world,
        mobs: const [],
        eye: Vector3(16.5, 2.6, 16.5),
        direction: Vector3(0, -1, 0),
        reach: 5.5,
      );
      expect(describe(aimAtBlock), 'blok stone');

      final mob = zombieAt(world, 16.5, 13.5);
      final aimAtMob = pickTarget(
        world: world,
        mobs: [mob],
        eye: Vector3(16.5, 2.6, 16.5),
        direction: Vector3(0, 0, -1),
        reach: 5.5,
      );
      expect(describe(aimAtMob), 'potwór zombie');
    });

    test('MobTarget niesie dystans, nie tylko potwora', () {
      final world = emptyWorld();
      final aim = pickTarget(
        world: world,
        mobs: [zombieAt(world, 16.5, 13.5)],
        eye: Vector3(16.5, 2.6, 16.5),
        direction: Vector3(0, 0, -1),
        reach: 5.5,
      );
      expect((aim as MobTarget).distance, closeTo(2.2, 0.5));
    });
  });
}
