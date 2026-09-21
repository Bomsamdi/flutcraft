import 'dart:io';
import 'dart:typed_data';

import 'package:flutcraft/src/save/file_save_storage.dart';
import 'package:flutcraft/src/save/repository_save_sink.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

SaveData sampleSave({int seed = 7}) {
  final world = VoxelWorld();
  TerrainGenerator(seed: seed).generate(world);
  final state = GameState.solo(
    world: world,
    player: Player(world: world, spawn: Vector3.zero())..respawn(),
    inventory: Inventory(),
  );
  return const GamePersistence().capture(state);
}

void main() {
  group('FileSaveStorage', () {
    late Directory directory;
    late FileSaveStorage storage;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('flutcraft_saves');
      storage = FileSaveStorage(directory);
    });

    tearDown(() => directory.deleteSync(recursive: true));

    test('writes, reads and deletes a file', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);

      await storage.write('a.json', bytes);
      expect(await storage.read('a.json'), bytes);

      await storage.delete('a.json');
      expect(await storage.read('a.json'), isNull);
    });

    test('a missing file reads as null, not as an exception', () async {
      expect(await storage.read('nothing.json'), isNull);
    });

    test('deleting a missing file is not an error', () async {
      await expectLater(storage.delete('nothing.json'), completes);
    });

    test('leaves no temporary files behind', () async {
      await storage.write('a.json', Uint8List.fromList([1]));
      expect(await storage.list(), ['a.json']);
    });

    test('a saved game survives the trip through the file system', () async {
      final repository = SaveRepository(storage: storage);

      await repository.save(kWorldSlot, sampleSave(seed: 4242));
      final loaded = await repository.load(kWorldSlot);

      expect(loaded?.data.world.seed, 4242);
      expect(await repository.slots(), [kWorldSlot]);
    });

    test('overwriting keeps the file readable', () async {
      final repository = SaveRepository(storage: storage);

      await repository.save(kWorldSlot, sampleSave(seed: 1));
      await repository.save(kWorldSlot, sampleSave(seed: 2));

      expect((await repository.load(kWorldSlot))?.data.world.seed, 2);
    });
  });

  group('RepositorySaveSink', () {
    test('writes the save it was handed', () async {
      final storage = InMemorySaveStorage();
      final sink = RepositorySaveSink(
        repository: SaveRepository(storage: storage),
      );

      sink.persist(sampleSave(seed: 11));
      await pumpEventQueue();

      final loaded = await SaveRepository(storage: storage).load(kWorldSlot);
      expect(loaded?.data.world.seed, 11);
    });

    test('a newer save supersedes one still queued', () async {
      final storage = InMemorySaveStorage();
      final sink = RepositorySaveSink(
        repository: SaveRepository(storage: storage),
      );

      sink
        ..persist(sampleSave(seed: 1))
        ..persist(sampleSave(seed: 2))
        ..persist(sampleSave(seed: 3));
      await pumpEventQueue();

      // The player has already moved on from the first two; only the last
      // state is worth the disk write.
      expect(
        (await SaveRepository(
          storage: storage,
        ).load(kWorldSlot))?.data.world.seed,
        3,
      );
    });

    test('a failing repository does not throw at the caller', () async {
      final sink = RepositorySaveSink(
        repository: SaveRepository(storage: _BrokenStorage()),
      );

      expect(() => sink.persist(sampleSave()), returnsNormally);
      await pumpEventQueue();
    });
  });
}

/// A disk that refuses to be written to.
class _BrokenStorage implements SaveStorage {
  @override
  Future<void> write(String name, Uint8List bytes) async =>
      throw const FileSystemException('disk full');

  @override
  Future<Uint8List?> read(String name) async => null;

  @override
  Future<void> delete(String name) async {}

  @override
  Future<List<String>> list() async => const [];
}
