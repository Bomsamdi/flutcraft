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
  return GameState(world: world, player: player, inventory: Inventory());
}

void main() {
  group('Świat zapisuje się jako ziarno plus zmiany', () {
    test('świeży świat nie ma żadnych edycji', () {
      expect(freshGame().world.edits, isEmpty);
    });

    test('każdy postawiony i zbity blok zostaje zapamiętany', () {
      final state = freshGame();
      state.world
        ..setBlock(10, 20, 10, BlockType.planks)
        ..setBlock(11, 20, 10, BlockType.air);

      expect(state.world.edits, hasLength(2));
      expect(state.world.edits[const BlockPos(10, 20, 10)], BlockType.planks);
    });

    test('zapis jest o rzędy wielkości mniejszy niż tablica wokseli', () {
      final state = freshGame();
      for (var i = 0; i < 200; i++) {
        state.world.setBlock(10 + i % 50, 20, 10, BlockType.cobblestone);
      }
      final bytes = codec.encode(persistence.capture(state, seed: 1337));

      // Pełna tablica to 128 * 48 * 128 = 786 432 bajty.
      expect(bytes.length, lessThan(40000));
    });
  });

  group('Round-trip', () {
    test('odtworzony świat ma te same bloki', () {
      final original = freshGame();
      original.world
        ..setBlock(64, 30, 64, BlockType.brick)
        ..setBlock(64, 31, 64, BlockType.furnace)
        ..setBlock(65, 30, 64, BlockType.air);

      final restored = persistence.restore(
        codec
            .decode(codec.encode(persistence.capture(original, seed: 1337)))
            .data,
      );

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

    test('gracz wraca na swoje miejsce i ze swoim życiem', () {
      final original = freshGame();
      original.player
        ..position.setValues(12.5, 34.0, 56.5)
        ..yaw = 1.2
        ..pitch = -0.4
        ..flying = true
        ..damage(7);

      final restored = persistence.restore(
        codec
            .decode(codec.encode(persistence.capture(original, seed: 1337)))
            .data,
      );

      expect(restored.player.position.x, closeTo(12.5, 1e-6));
      expect(restored.player.position.z, closeTo(56.5, 1e-6));
      expect(restored.player.yaw, closeTo(1.2, 1e-6));
      expect(restored.player.health, Player.maxHealth - 7);
      expect(restored.player.flying, isTrue);
    });

    test('ekwipunek i wybrany slot przeżywają zapis', () {
      final original = freshGame();
      original.inventory
        ..add(ItemType.ironPickaxe)
        ..add(ItemType.cobblestone, 40);
      original.selectedSlot = 1;

      final restored = persistence.restore(
        codec
            .decode(codec.encode(persistence.capture(original, seed: 1337)))
            .data,
      );

      expect(restored.inventory.countOf(ItemType.cobblestone), 40);
      expect(restored.inventory.countOf(ItemType.ironPickaxe), 1);
      expect(restored.selectedSlot, 1);
    });

    test('piec zachowuje wsad, paliwo i postęp', () {
      final original = freshGame();
      original.world.setBlock(64, 30, 64, BlockType.furnace);
      original.furnaces.open(const BlockPos(64, 30, 64))
        ..input = const ItemStack(ItemType.rawIron, 3)
        ..fuel = const ItemStack(ItemType.coal, 2)
        ..progress = 0.4;

      final restored = persistence.restore(
        codec
            .decode(codec.encode(persistence.capture(original, seed: 1337)))
            .data,
      );

      final furnace = restored.furnaces[const BlockPos(64, 30, 64)];
      expect(furnace?.input?.count, 3);
      expect(furnace?.fuel?.count, 2);
      expect(furnace?.progress, closeTo(0.4, 1e-6));
    });

    test('zawartość siatki wraca do ekwipunku, nie ginie', () {
      final original = freshGame();
      original.smallGrid[0] = const ItemStack(ItemType.log, 3);
      original.cursor = const ItemStack(ItemType.coal, 2);

      final data = persistence.capture(original, seed: 1337);
      final restored = persistence.restore(data);

      expect(restored.inventory.countOf(ItemType.log), 3);
      expect(restored.inventory.countOf(ItemType.coal), 2);
      expect(restored.cursor, isNull);
    });
  });

  group('Tolerancyjny czytelnik', () {
    test('nieznany przedmiot znika, reszta zapisu ocalała', () {
      final state = freshGame();
      state.inventory.add(ItemType.coal, 5);
      final raw = codec.toJson(persistence.capture(state, seed: 1337));

      (raw['inventory'] as List)[0] = {'item': 'unobtanium', 'count': 1};
      final result = codec.fromJson(raw);

      expect(result.warnings, hasLength(1));
      expect(result.warnings.single.toString(), contains('unobtanium'));
      expect(result.data.seed, 1337);
    });

    test('nieznany blok pomija tylko swoją edycję', () {
      final state = freshGame();
      state.world
        ..setBlock(10, 20, 10, BlockType.planks)
        ..setBlock(11, 20, 10, BlockType.brick);
      final raw = codec.toJson(persistence.capture(state, seed: 1337));

      (raw['edits'] as List)[0] = {
        'p': [10, 20, 10],
        'b': 'mithril',
      };
      final result = codec.fromJson(raw);

      expect(result.warnings, hasLength(1));
      expect(result.data.edits, hasLength(1));
    });

    test('zapis z przyszłej wersji jest odrzucany jasnym błędem', () {
      final raw = codec.toJson(persistence.capture(freshGame(), seed: 1))
        ..['version'] = SaveCodec.currentVersion + 5;

      expect(() => codec.fromJson(raw), throwsA(isA<SaveTooNewException>()));
    });

    test('enumy zapisywane po nazwie, nie po indeksie', () {
      final state = freshGame();
      state.inventory.add(ItemType.ironSword);
      final raw = codec.toJson(persistence.capture(state, seed: 1));

      final slot =
          (raw['inventory'] as List).firstWhere((e) => e != null)
              as Map<String, Object?>;
      expect(slot['item'], 'ironSword');
      expect(slot['item'], isA<String>());
    });
  });

  group('SaveRepository', () {
    test('zapisuje i odczytuje slot', () async {
      final repository = SaveRepository(storage: InMemorySaveStorage());
      final state = freshGame();
      state.inventory.add(ItemType.bone, 4);

      await repository.save('one', persistence.capture(state, seed: 99));
      final loaded = await repository.load('one');

      expect(loaded, isNotNull);
      expect(loaded!.data.seed, 99);
      expect(
        persistence.restore(loaded.data).inventory.countOf(ItemType.bone),
        4,
      );
    });

    test('pusty slot zwraca null', () async {
      final repository = SaveRepository(storage: InMemorySaveStorage());
      expect(await repository.load('missing'), isNull);
    });

    test('wypisuje i kasuje sloty', () async {
      final repository = SaveRepository(storage: InMemorySaveStorage());
      final data = persistence.capture(freshGame(), seed: 1);

      await repository.save('a', data);
      await repository.save('b', data);
      expect(await repository.slots(), ['a', 'b']);

      await repository.delete('a');
      expect(await repository.slots(), ['b']);
    });
  });

  group('Gra działa po wczytaniu', () {
    test('wczytany świat da się dalej symulować', () {
      final original = freshGame();
      original.world.setBlock(64, 30, 64, BlockType.planks);

      final restored = persistence.restore(
        codec
            .decode(codec.encode(persistence.capture(original, seed: 1337)))
            .data,
      );
      final loop = GameLoop(
        state: restored,
        spawner: MobSpawner(world: restored.world, seed: 1, maxMobs: 0),
        random: Random(1),
      );

      for (var i = 0; i < 300; i++) {
        loop.tick(1 / 60, InputFrame.idle);
      }
      expect(restored.player.position.y, greaterThan(0));
    });
  });
}
