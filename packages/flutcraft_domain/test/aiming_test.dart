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
    test('it hits a mob standing in front of the player', () {
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

    test('it does not hit a mob behind a wall', () {
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

    test('a mob out of arm\'s reach is ignored', () {
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

    test('it picks the nearer of two mobs', () {
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

    test('a dead mob is not a target', () {
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

    test('looking aside aims at the block, not the mob beside it', () {
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

    test('looking down aims at the ground', () {
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

  group('Damage from the held item', () {
    test(
      'a sword hits harder than a pickaxe, a pickaxe harder than a fist',
      () {
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
      },
    );

    test('an iron sword kills a spider in two hits', () {
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

    test('bare-handed, a zombie takes twenty hits', () {
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
  group('An exhaustive switch', () {
    /// The compiler insists on all three cases — adding
    /// czwartego wariantu AimResult wywali to w czasie kompilacji.
    String describe(AimResult aim) => switch (aim) {
      NoTarget() => 'nic',
      BlockTarget(:final hit) => 'blok ${hit.block.name}',
      MobTarget(:final mob) => 'mob ${mob.kind.name}',
    };

    test('every variant has its own description', () {
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
      expect(describe(aimAtMob), 'mob zombie');
    });

    test('MobTarget carries the distance, not just the mob', () {
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

  group('Taking the player at their word', () {
    late GameState state;
    late Participant it;
    const aiming = AimingSystem();

    setUp(() {
      final world = emptyWorld();
      // A pillar off to one side, so the ray straight ahead cannot find it.
      world.setRaw(18, 1, 14, BlockType.stone);
      state = GameState.solo(
        world: world,
        player: Player(world: world, spawn: Vector3(16.5, 1, 16.5)),
        inventory: Inventory(),
      );
      it = state.solo;
      it.player
        ..position.setValues(16.5, 1, 16.5)
        ..yaw = 0
        ..pitch = 0;
    });

    BlockPos? aimed() {
      final aim = it.aim;
      return aim is BlockTarget ? aim.hit.pos : null;
    }

    test('a claim decides the target, and the ray does not', () {
      aiming.update(state, it);
      final byRay = aimed();

      it.claimedAim = const AimClaim(
        at: BlockPos(18, 1, 14),
        against: BlockPos(18, 2, 14),
      );
      aiming.update(state, it);

      // The whole point: a server's own ray is a tick out of date, and along
      // the ground a tick is worth whole blocks.
      expect(aimed(), const BlockPos(18, 1, 14));
      expect(aimed(), isNot(byRay));
    });

    test('the face comes with it, so a block goes on the right side', () {
      it.claimedAim = const AimClaim(
        at: BlockPos(18, 1, 14),
        against: BlockPos(18, 2, 14),
      );

      aiming.update(state, it);

      final hit = (it.aim as BlockTarget).hit;
      expect(hit.placement, (18, 2, 14));
    });

    test('a claim about empty air is refused', () {
      it.claimedAim = const AimClaim(
        at: BlockPos(18, 5, 14),
        against: BlockPos(18, 6, 14),
      );

      aiming.update(state, it);

      // Nothing is there, so the ray decides after all.
      expect(aimed(), isNot(const BlockPos(18, 5, 14)));
    });

    test('a claim out of arm\'s reach is refused', () {
      // Solid, and much too far: this is the one a client would lie about.
      state.world.setRaw(30, 1, 16, BlockType.stone);
      it.claimedAim = const AimClaim(
        at: BlockPos(30, 1, 16),
        against: BlockPos(30, 2, 16),
      );

      aiming.update(state, it);

      expect(aimed(), isNot(const BlockPos(30, 1, 16)));
    });

    test('moving the claim resets the progress, as moving the ray does', () {
      it.claimedAim = const AimClaim(
        at: BlockPos(18, 1, 14),
        against: BlockPos(18, 2, 14),
      );
      aiming.update(state, it);
      it.breakProgress = 0.8;

      it.claimedAim = const AimClaim(
        at: BlockPos(16, 0, 16),
        against: BlockPos(16, 1, 16),
      );
      aiming.update(state, it);

      // Otherwise a player could chip at three blocks at once by sweeping,
      // which is the rule this system already had and the claim must obey.
      expect(it.breakProgress, 0);
    });
  });
}
