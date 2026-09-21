import 'dart:math';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

const alice = PlayerId('alice');
const bob = PlayerId('bob');

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

Participant playerAt(PlayerId id, VoxelWorld world, double x, double z) =>
    Participant(
      id: id,
      player: Player(world: world, spawn: Vector3(x, 2, z)),
    );

void main() {
  late VoxelWorld world;
  late GameState state;
  late GameLoop loop;

  setUp(() {
    world = flatWorld();
    state = GameState(
      world: world,
      players: [
        playerAt(alice, world, 20.5, 20.5),
        playerAt(bob, world, 40.5, 40.5),
      ],
    );
    loop = GameLoop(
      state: state,
      spawner: MobSpawner(world: world, seed: 1, maxMobs: 0),
      random: Random(1),
    );
  });

  Participant of(PlayerId id) => state.participants[id]!;

  group('Two players, one world', () {
    test('each carries their own inventory', () {
      of(alice).inventory.add(ItemType.planks, 8);

      expect(of(alice).inventory.countOf(ItemType.planks), 8);
      expect(of(bob).inventory.countOf(ItemType.planks), 0);
    });

    test('a command names who sent it', () {
      loop.dispatch(alice, const SelectHotbarSlot(3));

      expect(of(alice).selectedSlot, 3);
      expect(of(bob).selectedSlot, 0, reason: 'bob touched nothing');
    });

    test('one player opening a screen does not freeze the other', () {
      loop.dispatch(alice, const OpenRoute(UiRoute.inventory));
      final bobStart = of(bob).player.position.clone();

      for (var i = 0; i < 30; i++) {
        loop.tick(1 / 60, {
          bob: const InputFrame(forward: 1, held: {GameAction.moveForward}),
        });
      }

      expect(of(bob).player.position.distanceTo(bobStart), greaterThan(0.5));
      expect(of(alice).route, UiRoute.inventory);
    });

    test('the world keeps running while one player is in a menu', () {
      loop.dispatch(alice, const OpenRoute(UiRoute.inventory));
      // Far enough from Bob to have somewhere to walk, close enough to care.
      state.mobs.add(
        Mob(kind: MobKind.zombie, world: world, spawn: Vector3(45.5, 2, 45.5)),
      );
      final mobStart = state.mobs.first.position.clone();

      for (var i = 0; i < 60; i++) {
        loop.tick(1 / 60, const {});
      }

      // The zombie is hunting Bob, who never opened anything.
      expect(state.mobs.first.position.distanceTo(mobStart), greaterThan(0.5));
    });

    test('everyone in a menu does stop the world', () {
      loop
        ..dispatch(alice, const OpenRoute(UiRoute.inventory))
        ..dispatch(bob, const OpenRoute(UiRoute.inventory));
      state.mobs.add(
        Mob(kind: MobKind.zombie, world: world, spawn: Vector3(45.5, 2, 45.5)),
      );
      final mobStart = state.mobs.first.position.clone();

      for (var i = 0; i < 60; i++) {
        loop.tick(1 / 60, const {});
      }

      expect(state.mobs.first.position.distanceTo(mobStart), lessThan(1e-6));
    });

    test('a block one player breaks is gone for both', () {
      world.setBlock(20, 3, 20, BlockType.planks);
      final hit = world.raycast(
        Vector3(20.5, 3.5, 22),
        Vector3(0, 0, -1)..normalize(),
        6,
      )!;

      MiningSystem(random: Random(1)).breakBlockAt(state, of(alice), hit);

      expect(world.blockAt(20, 3, 20), BlockType.air);
      expect(of(alice).inventory.countOf(ItemType.planks), 1);
      expect(
        of(bob).inventory.countOf(ItemType.planks),
        0,
        reason: 'the drops went to whoever swung',
      );
    });

    test('a mob chases whoever is nearest, and switches when that changes', () {
      final mob = Mob(
        kind: MobKind.zombie,
        world: world,
        spawn: Vector3(22, 2, 22),
      );
      state.mobs.add(mob);

      expect(state.nearestLivingTo(mob.position)?.id, alice);

      // Alice walks off; Bob is now the closer target.
      of(alice).player.position.setValues(60.5, 2, 60.5);
      expect(state.nearestLivingTo(mob.position)?.id, bob);
    });

    test('a dead player is not chased', () {
      of(alice).player.damage(Player.maxHealth);
      final point = Vector3(21, 2, 21);

      expect(state.nearestLivingTo(point)?.id, bob);
    });

    test('an explosion hurts everyone standing in it', () {
      of(bob).player.position.setValues(21.5, 2, 20.5);
      const ExplosionSystem().explode(state, Vector3(21, 2, 20.5), 3, 20);

      expect(of(alice).player.health, lessThan(Player.maxHealth));
      expect(of(bob).player.health, lessThan(Player.maxHealth));
    });

    test('players cannot stand inside each other', () {
      of(bob).player.position.setFrom(of(alice).player.position);

      const EntitySeparationSystem().update(state);

      final apart = of(
        alice,
      ).player.position.distanceTo(of(bob).player.position);
      expect(apart, greaterThan(0.5));
    });

    test('each player gets their own snapshot', () {
      of(alice).inventory.add(ItemType.coal, 5);
      loop.dispatch(bob, const OpenRoute(UiRoute.inventory));

      final forAlice = GameSnapshot.forPlayer(state, of(alice));
      final forBob = GameSnapshot.forPlayer(state, of(bob));

      expect(forAlice.hotbar.first?.count, 5);
      expect(forBob.hotbar.first, isNull);
      expect(forAlice.route, UiRoute.none);
      expect(forBob.route, UiRoute.inventory);
      expect(
        forAlice.mobCount,
        forBob.mobCount,
        reason: 'the world looks the same to both',
      );
    });

    test('a swing by one does not put the other on cooldown', () {
      final mob = Mob(
        kind: MobKind.zombie,
        world: world,
        spawn: Vector3(21, 2, 20.5),
      );
      state.mobs.add(mob);
      final mining = MiningSystem(random: Random(1));

      of(alice).aim = MobTarget(mob, 1);
      of(bob).aim = MobTarget(mob, 1);
      switch (mining.accumulate(of(alice), 1 / 60, active: true)) {
        case BlockGivesWay(:final hit):
          mining.breakBlockAt(state, of(alice), hit);
        case MobStruck(:final mob):
          mining.strike(of(alice), mob);
        case SwingContinues():
          break;
      }
      final afterAlice = mob.health;
      switch (mining.accumulate(of(bob), 1 / 60, active: true)) {
        case MobStruck(:final mob):
          mining.strike(of(bob), mob);
        case BlockGivesWay() || SwingContinues():
          break;
      }

      // The swing timer used to be a field on the system, shared by everyone.
      expect(mob.health, lessThan(afterAlice));
    });
  });

  group('A world with company saves everyone in it', () {
    test('both inventories come back', () {
      of(alice).inventory.add(ItemType.ironIngot, 3);
      of(bob).inventory.add(ItemType.bone, 5);

      final restored = const GamePersistence().restore(
        const SaveCodec()
            .decode(
              const SaveCodec().encode(const GamePersistence().capture(state)),
            )
            .data,
      );

      expect(restored.participants, hasLength(2));
      expect(
        restored.participants[alice]!.inventory.countOf(ItemType.ironIngot),
        3,
      );
      expect(restored.participants[bob]!.inventory.countOf(ItemType.bone), 5);
    });

    test('a save no longer throws the moment a second player joins', () {
      // This used to be pinned as a landmine: capture() read GameState.solo,
      // which is `participants.values.single`, so a server with a save sink
      // would have taken the tick loop down a minute after the second player
      // arrived.
      expect(() => const GamePersistence().capture(state), returnsNormally);
    });
  });

  group('Spawning does not scale with the crowd', () {
    test('a second player does not double the spawn rate', () {
      int mobsAfter(int players, {required double seconds}) {
        final world = flatWorld();
        final state = GameState(
          world: world,
          players: [
            for (var i = 0; i < players; i++)
              playerAt(PlayerId('p$i'), world, 20.5 + i * 4, 20.5),
          ],
        );
        final loop = GameLoop(
          state: state,
          spawner: MobSpawner(world: world, seed: 7),
          random: Random(7),
        );
        for (var i = 0; i < seconds * 60; i++) {
          loop.tick(1 / 60, const {});
        }
        return state.mobs.length;
      }

      // Long enough for a couple of spawn windows, short of the cap.
      const seconds = 14.0;
      final solo = mobsAfter(1, seconds: seconds);
      final crowd = mobsAfter(4, seconds: seconds);

      expect(solo, greaterThan(0), reason: 'something should have spawned');
      expect(
        crowd,
        solo,
        reason: 'the spawner has one clock, however many people share it',
      );
    });
  });

  group('Loot goes to whoever earned it', () {
    Mob zombieNear(Participant it) => Mob(
      kind: MobKind.zombie,
      world: world,
      spawn: Vector3(it.player.position.x + 1, 2, it.player.position.z),
    );

    test('the killer collects, not the bystander', () {
      // Bob stands next to Alice's fight. Under the old rule — nearest player
      // wins — he could walk past and collect her bones.
      final mob = zombieNear(of(alice))..health = 1;
      state.mobs.add(mob);
      of(bob).player.position.setFrom(mob.position);

      final mining = MiningSystem(random: Random(1));
      of(alice).inventory.add(ItemType.ironSword);
      of(alice).aim = MobTarget(mob, 1);
      switch (mining.accumulate(of(alice), 1 / 60, active: true)) {
        case BlockGivesWay(:final hit):
          mining.breakBlockAt(state, of(alice), hit);
        case MobStruck(:final mob):
          mining.strike(of(alice), mob);
        case SwingContinues():
          break;
      }
      loop.tick(1 / 60, const {});

      expect(mob.lastHitBy, alice);
      expect(state.mobs, isEmpty, reason: 'the zombie died');
    });

    test('a mob that nobody hit leaves its drops to the nearest player', () {
      final mob = zombieNear(of(bob))..health = 0;
      state.mobs.add(mob);

      loop.tick(1 / 60, const {});

      expect(mob.lastHitBy, isNull, reason: 'a creeper or a fall killed it');
      expect(state.mobs, isEmpty);
    });

    test('a killer who has left does not take the loot with them', () {
      final mob = zombieNear(of(bob))
        ..health = 0
        ..lastHitBy = alice;
      state.mobs.add(mob);
      state.leave(alice);

      expect(() => loop.tick(1 / 60, const {}), returnsNormally);
      expect(state.mobs, isEmpty);
    });
  });

  group('Rules that changed meaning with company', () {
    test('one player respawning does not clear everyone\'s mobs', () {
      state.mobs.add(
        Mob(kind: MobKind.zombie, world: world, spawn: Vector3(45, 2, 45)),
      );
      of(alice).player.damage(Player.maxHealth);

      loop.dispatch(alice, const Respawn());

      // Alone, respawning wipes the world clean. With company, the mobs are
      // everybody's problem and Bob is still fighting them.
      expect(state.mobs, hasLength(1));
      expect(of(alice).player.isDead, isFalse);
    });

    test('the autosave still refuses when everyone is dead', () {
      final sink = RecordingSaveSink();
      final saving = GameLoop(
        state: state,
        spawner: MobSpawner(world: world, seed: 1, maxMobs: 0),
        random: Random(1),
        saveSink: sink,
        autosaveInterval: 1,
      );
      for (final it in state.participants.values) {
        it.player.damage(Player.maxHealth);
      }

      for (var i = 0; i < 120; i++) {
        saving.tick(1 / 60, const {});
      }

      expect(sink.saves, isEmpty);
    });
  });

  group('Events reach the player they are about', () {
    test('a full inventory is one player\'s problem', () {
      // Fill Alice up so a drop has nowhere to go.
      for (var i = 0; i < of(alice).inventory.length; i++) {
        of(alice).inventory[i] = const ItemStack(ItemType.bone, 64);
      }
      world.setBlock(20, 3, 20, BlockType.planks);
      final hit = world.raycast(
        Vector3(20.5, 3.5, 22),
        Vector3(0, 0, -1)..normalize(),
        6,
      )!;

      final events = addressedTo(
        alice,
        MiningSystem(random: Random(1)).breakBlockAt(state, of(alice), hit),
      );

      expect(events.forPlayer(alice).whereType<InventoryFull>(), isNotEmpty);
      expect(
        events.forPlayer(bob),
        isEmpty,
        reason: "Bob's screen used to announce that his inventory was full",
      );
    });

    test('the kill notice follows the loot', () {
      final mob =
          Mob(kind: MobKind.skeleton, world: world, spawn: Vector3(21, 2, 20.5))
            ..health = 0
            ..lastHitBy = alice;
      state.mobs.add(mob);
      // Bob is nearer the corpse than the player who killed it.
      of(bob).player.position.setValues(21, 2, 20.5);

      final events = loop.tick(1 / 60, const {});

      expect(events.forPlayer(alice).whereType<MobKilled>(), hasLength(1));
      expect(events.forPlayer(bob).whereType<MobKilled>(), isEmpty);
    });

    test('an explosion is heard by everyone, not only its victim', () {
      // A real creeper, because explode() is called from inside a tick and
      // the loop clears its event list at the start of every one.
      state.mobs.add(
        Mob(kind: MobKind.creeper, world: world, spawn: Vector3(21.5, 2, 20.5)),
      );

      final heard = <AddressedEvent>[];
      for (var i = 0; i < 60 * 3; i++) {
        heard.addAll(loop.tick(kStep, const {}));
      }

      // Bob is twenty blocks away and still hears the bang.
      expect(heard.forPlayer(alice).whereType<CreeperExploded>(), hasLength(1));
      expect(heard.forPlayer(bob).whereType<CreeperExploded>(), hasLength(1));
      expect(of(alice).player.health, lessThan(Player.maxHealth));
      expect(
        of(bob).player.health,
        Player.maxHealth,
        reason: 'hearing it is not the same as being caught in it',
      );
    });

    test('a single-player session still hears everything it used to', () async {
      final solo = flatWorld();
      final session = LoopGameSession(
        GameLoop(
          state: GameState.solo(
            world: solo,
            player: Player(world: solo, spawn: Vector3(32.5, 2, 32.5)),
            inventory: Inventory(),
          ),
          spawner: MobSpawner(world: solo, seed: 1, maxMobs: 0),
          random: Random(1),
        ),
      );
      final heard = <GameEvent>[];
      session.events.listen(heard.add);

      session.dispatch(const ToggleFlight());
      await Future<void>.delayed(Duration.zero);

      // The filtering must not have cost the one player their own events.
      expect(heard.whereType<FlightToggled>(), hasLength(1));
    });
  });

  group('Entities are named on the way in', () {
    test('every mob gets its own name', () {
      final first = state.spawn(
        Mob(kind: MobKind.zombie, world: world, spawn: Vector3(20, 2, 24)),
      );
      final second = state.spawn(
        Mob(kind: MobKind.zombie, world: world, spawn: Vector3(20, 2, 26)),
      );

      expect(first.id, isNot(second.id));
    });

    test('mobs and arrows draw from the same counter', () {
      final mob = state.spawn(
        Mob(kind: MobKind.zombie, world: world, spawn: Vector3(20, 2, 24)),
      );
      final arrow = state.launch(
        Arrow(
          world: world,
          spawn: Vector3(20, 3, 24),
          direction: Vector3(0, 0, 1),
        ),
      );

      // One name space, so a packet about entity 7 is unambiguous.
      expect(arrow.id, isNot(mob.id));
    });

    test('two mobs alike in every value are still two mobs', () {
      Mob twin() =>
          Mob(kind: MobKind.zombie, world: world, spawn: Vector3(30, 2, 30));
      final first = state.spawn(twin());
      final second = state.spawn(twin());

      // Identity, not equality: the renderer keeps one component per entity
      // in a map keyed by the object. Value equality here would merge these
      // two into one component and make a zombie disappear.
      expect(first == second, isFalse);
      expect(state.mobs.toSet(), hasLength(2));
      expect(first.id, isNot(second.id));
    });
  });

  group('Joining and leaving', () {
    test('a player can join a world that is already running', () {
      for (var i = 0; i < 60; i++) {
        loop.tick(1 / 60, const {});
      }

      state.join(playerAt(const PlayerId('carol'), world, 30.5, 30.5));
      loop.tick(1 / 60, const {});

      expect(state.participants, hasLength(3));
    });

    test('leaving hands back what they were carrying', () {
      of(bob).inventory.add(ItemType.ironIngot, 3);

      final gone = state.leave(bob);

      expect(gone?.inventory.countOf(ItemType.ironIngot), 3);
      expect(state.participants, hasLength(1));
    });

    test('a command from someone who left is ignored, not fatal', () {
      state.leave(bob);

      expect(
        () => loop.dispatch(bob, const SelectHotbarSlot(2)),
        returnsNormally,
      );
      expect(loop.dispatch(bob, const SelectHotbarSlot(2)), isEmpty);
    });
  });
}
