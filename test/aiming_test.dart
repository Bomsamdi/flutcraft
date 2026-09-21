import 'package:vector_math/vector_math.dart';
import 'package:flutcraft/src/core/block.dart';
import 'package:flutcraft/src/core/item.dart';
import 'package:flutcraft/src/game/aiming.dart';
import 'package:flutcraft/src/game/mob.dart';
import 'package:flutcraft/src/world/voxel_world.dart';
import 'package:flutter_test/flutter_test.dart';

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

      expect(aim.isMob, isTrue);
      expect(aim.mob, same(mob));
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

      expect(aim.isMob, isFalse);
      expect(aim.blockHit, isNotNull);
      expect(aim.blockHit!.block, BlockType.stone);
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

      expect(aim.isMob, isFalse);
      expect(aim.isEmpty, isTrue);
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

      expect(aim.mob, same(near));
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

      expect(aim.isMob, isFalse);
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

      expect(aim.isMob, isFalse);
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

      expect(aim.blockHit, isNotNull);
      expect(aim.blockHit!.y, 0);
    });
  });

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
