import 'dart:math';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

const persistence = GamePersistence();
const codec = SaveCodec();

GameState freshGame({int seed = 1337}) {
  final world = VoxelWorld();
  TerrainGenerator(seed: seed).generate(world);
  final player = Player(world: world, spawn: Vector3.zero())..respawn();
  return GameState.solo(world: world, player: player, inventory: Inventory());
}

/// Encode, decode and rebuild — the full trip a save makes.
GameState roundTrip(GameState state) => persistence.restore(
  codec.decode(codec.encode(persistence.capture(state))).data,
);

void main() {
  group('A world is saved as a seed plus its edits', () {
    test('a freshly generated world has no edits', () {
      expect(freshGame().world.edits, isEmpty);
    });

    test('the generator stamps its seed on the world', () {
      expect(freshGame(seed: 4242).world.seed, 4242);
    });

    test('every block placed or broken is remembered', () {
      final state = freshGame();
      state.world
        ..setBlock(10, 20, 10, BlockType.planks)
        ..setBlock(11, 20, 10, BlockType.air);

      expect(state.world.edits, hasLength(2));
      expect(state.world.edits[const BlockPos(10, 20, 10)], BlockType.planks);
    });

    test('the save is orders of magnitude smaller than the voxel array', () {
      final state = freshGame();
      for (var i = 0; i < 200; i++) {
        state.world.setBlock(10 + i % 50, 20, 10, BlockType.cobblestone);
      }
      final bytes = codec.encode(persistence.capture(state));

      // The full array is 128 * 48 * 128 = 786,432 bytes.
      expect(bytes.length, lessThan(40000));
    });
  });

  group('Round trip', () {
    test('the restored world has the same blocks', () {
      final original = freshGame();
      original.world
        ..setBlock(64, 30, 64, BlockType.brick)
        ..setBlock(64, 31, 64, BlockType.furnace)
        ..setBlock(65, 30, 64, BlockType.air);

      final restored = roundTrip(original);

      for (final pos in [
        const BlockPos(64, 30, 64),
        const BlockPos(64, 31, 64),
        const BlockPos(65, 30, 64),
        const BlockPos(20, 20, 20),
      ]) {
        expect(
          restored.world.blockAt(pos.x, pos.y, pos.z),
          original.world.blockAt(pos.x, pos.y, pos.z),
          reason: '$pos',
        );
      }
    });

    test('the player comes back where they stood, with their health', () {
      final original = freshGame();
      original.solo.player
        ..position.setValues(12.5, 34.0, 56.5)
        ..yaw = 1.2
        ..pitch = -0.4
        ..flying = true
        ..damage(7);

      final restored = roundTrip(original);

      expect(restored.solo.player.position.x, closeTo(12.5, 1e-6));
      expect(restored.solo.player.position.z, closeTo(56.5, 1e-6));
      expect(restored.solo.player.yaw, closeTo(1.2, 1e-6));
      expect(restored.solo.player.health, Player.maxHealth - 7);
      expect(restored.solo.player.flying, isTrue);
    });

    test('the inventory and the selected slot survive', () {
      final original = freshGame();
      original.solo.inventory
        ..add(ItemType.ironPickaxe)
        ..add(ItemType.cobblestone, 40);
      original.solo.selectedSlot = 1;

      final restored = roundTrip(original);

      expect(restored.solo.inventory.countOf(ItemType.cobblestone), 40);
      expect(restored.solo.inventory.countOf(ItemType.ironPickaxe), 1);
      expect(restored.solo.selectedSlot, 1);
    });

    test('a furnace keeps its input, fuel and progress', () {
      final original = freshGame();
      original.world.setBlock(64, 30, 64, BlockType.furnace);
      original.furnaces.open(const BlockPos(64, 30, 64))
        ..input = const ItemStack(ItemType.rawIron, 3)
        ..fuel = const ItemStack(ItemType.coal, 2)
        ..progress = 0.4;

      final furnace = roundTrip(original).furnaces[const BlockPos(64, 30, 64)];

      expect(furnace?.input?.count, 3);
      expect(furnace?.fuel?.count, 2);
      expect(furnace?.progress, closeTo(0.4, 1e-6));
    });

    test('grid and cursor contents land in the inventory, never lost', () {
      final original = freshGame();
      original.solo.smallGrid[0] = const ItemStack(ItemType.log, 3);
      original.solo.cursor = const ItemStack(ItemType.coal, 2);

      final restored = roundTrip(original);

      expect(restored.solo.inventory.countOf(ItemType.log), 3);
      expect(restored.solo.inventory.countOf(ItemType.coal), 2);
      expect(restored.solo.cursor, isNull);
    });

    test('a save that says the player is dead restores them alive', () {
      final original = freshGame();
      original.solo.player.damage(Player.maxHealth);

      // Only an older version could write this, but loading it must not
      // leave the player stuck on the death screen.
      final restored = persistence.restore(
        codec.decode(codec.encode(persistence.capture(original))).data,
      );

      expect(restored.solo.player.isDead, isFalse);
    });

    test('capturing leaves the running game untouched', () {
      final original = freshGame();
      original.solo.smallGrid[0] = const ItemStack(ItemType.log, 3);
      original.solo.cursor = const ItemStack(ItemType.coal, 2);

      persistence.capture(original);

      // Autosave fires mid-craft; emptying the grid under the player would be
      // worse than not saving at all.
      expect(original.solo.smallGrid[0], const ItemStack(ItemType.log, 3));
      expect(original.solo.cursor, const ItemStack(ItemType.coal, 2));
      expect(original.solo.inventory.countOf(ItemType.log), 0);
    });
  });

  group('A tolerant reader', () {
    test('an unknown item disappears, the rest of the save survives', () {
      final state = freshGame();
      state.solo.inventory.add(ItemType.coal, 5);
      final raw = codec.toJson(persistence.capture(state));

      (raw['inventory'] as List)[0] = {'item': 'unobtanium', 'count': 1};
      final result = codec.fromJson(raw);

      expect(result.warnings, hasLength(1));
      expect(result.warnings.single.toString(), contains('unobtanium'));
      expect(result.data.seed, 1337);
    });

    test('an unknown block only costs its own edit', () {
      final state = freshGame();
      state.world
        ..setBlock(10, 20, 10, BlockType.planks)
        ..setBlock(11, 20, 10, BlockType.brick);
      final raw = codec.toJson(persistence.capture(state));

      (raw['edits'] as List)[0] = {
        'p': [10, 20, 10],
        'b': 'mithril',
      };
      final result = codec.fromJson(raw);

      expect(result.warnings, hasLength(1));
      expect(result.data.edits, hasLength(1));
    });

    test('a save from a future version is refused with a clear error', () {
      final raw = codec.toJson(persistence.capture(freshGame()))
        ..['version'] = SaveCodec.currentVersion + 5;

      expect(() => codec.fromJson(raw), throwsA(isA<SaveTooNewException>()));
    });

    test('enums are stored by name, not by index', () {
      final state = freshGame();
      state.solo.inventory.add(ItemType.ironSword);
      final raw = codec.toJson(persistence.capture(state));

      final slot =
          (raw['inventory'] as List).firstWhere((e) => e != null)
              as Map<String, Object?>;
      expect(slot['item'], 'ironSword');
      expect(slot['item'], isA<String>());
    });
  });

  group('SaveRepository', () {
    test('writes and reads back a slot', () async {
      final repository = SaveRepository(storage: InMemorySaveStorage());
      final state = freshGame(seed: 99);
      state.solo.inventory.add(ItemType.bone, 4);

      await repository.save('one', persistence.capture(state));
      final loaded = await repository.load('one');

      expect(loaded, isNotNull);
      expect(loaded!.data.seed, 99);
      expect(
        persistence.restore(loaded.data).solo.inventory.countOf(ItemType.bone),
        4,
      );
    });

    test('an empty slot reads as null', () async {
      final repository = SaveRepository(storage: InMemorySaveStorage());
      expect(await repository.load('missing'), isNull);
    });

    test('lists and deletes slots', () async {
      final repository = SaveRepository(storage: InMemorySaveStorage());
      final data = persistence.capture(freshGame());

      await repository.save('a', data);
      await repository.save('b', data);
      expect(await repository.slots(), ['a', 'b']);

      await repository.delete('a');
      expect(await repository.slots(), ['b']);
    });
  });

  group('Autosave', () {
    GameLoop loopWith(RecordingSaveSink sink, {double interval = 10}) =>
        GameLoop(
          state: freshGame(),
          spawner: MobSpawner(world: VoxelWorld(), seed: 1, maxMobs: 0),
          random: Random(1),
          saveSink: sink,
          autosaveInterval: interval,
        );

    test('saves once the interval has passed, and reports it', () {
      final sink = RecordingSaveSink();
      final loop = loopWith(sink);

      var events = <GameEvent>[];
      for (var i = 0; i < 60 * 9; i++) {
        events = loop.tickSolo(1 / 60, InputFrame.idle);
      }
      expect(sink.saves, isEmpty, reason: 'nine seconds is not ten');

      for (var i = 0; i < 60; i++) {
        final tickEvents = loop.tickSolo(1 / 60, InputFrame.idle);
        if (tickEvents.isNotEmpty) events = tickEvents;
      }
      expect(sink.saves, hasLength(1));
      expect(events.whereType<GameSaved>(), hasLength(1));
    });

    test('keeps saving while a screen is open', () {
      final sink = RecordingSaveSink();
      final loop = loopWith(sink)
        ..dispatchSolo(const OpenRoute(UiRoute.inventory));

      for (var i = 0; i < 60 * 11; i++) {
        loop.tickSolo(1 / 60, InputFrame.idle);
      }
      expect(sink.saves, hasLength(1));
    });

    test('an explicit save does not wait for the timer', () {
      final sink = RecordingSaveSink();
      final loop = loopWith(sink);

      final events = loop.dispatchSolo(const SaveGame());

      expect(sink.saves, hasLength(1));
      expect(events.single, isA<GameSaved>());
    });

    test('an explicit save restarts the countdown', () {
      final sink = RecordingSaveSink();
      final loop = loopWith(sink);

      for (var i = 0; i < 60 * 9; i++) {
        loop.tickSolo(1 / 60, InputFrame.idle);
      }
      loop.dispatchSolo(const SaveGame());
      for (var i = 0; i < 60 * 9; i++) {
        loop.tickSolo(1 / 60, InputFrame.idle);
      }

      expect(sink.saves, hasLength(1), reason: 'the timer restarted at zero');
    });

    test('a dead player is never autosaved', () {
      final sink = RecordingSaveSink();
      final loop = loopWith(sink);
      loop.state.solo.player.damage(Player.maxHealth);

      for (var i = 0; i < 60 * 11; i++) {
        loop.tickSolo(1 / 60, InputFrame.idle);
      }

      // Otherwise the next launch opens on the death screen, with the last
      // living moment already overwritten.
      expect(sink.saves, isEmpty);
    });

    test('an explicit save of a dead player is refused too', () {
      final sink = RecordingSaveSink();
      final loop = loopWith(sink);
      loop.state.solo.player.damage(Player.maxHealth);

      expect(loop.dispatchSolo(const SaveGame()), isEmpty);
      expect(sink.saves, isEmpty);
    });

    test('without a sink the loop simply does not save', () {
      final loop = GameLoop(
        state: freshGame(),
        spawner: MobSpawner(world: VoxelWorld(), seed: 1, maxMobs: 0),
      );

      expect(loop.dispatchSolo(const SaveGame()), isEmpty);
    });
  });

  group('The game still runs after loading', () {
    test('a restored world can be simulated further', () {
      final original = freshGame();
      original.world.setBlock(64, 30, 64, BlockType.planks);

      final restored = roundTrip(original);
      final loop = GameLoop(
        state: restored,
        spawner: MobSpawner(world: restored.world, seed: 1, maxMobs: 0),
        random: Random(1),
      );

      for (var i = 0; i < 300; i++) {
        loop.tickSolo(1 / 60, InputFrame.idle);
      }
      expect(restored.solo.player.position.y, greaterThan(0));
    });
  });
}
