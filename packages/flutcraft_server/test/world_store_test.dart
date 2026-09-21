import 'dart:io';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_server/flutcraft_server.dart';
import 'package:test/test.dart';

const alice = PlayerId('alice');

void main() {
  late Directory directory;
  late WorldStore store;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('flutcraft_world');
    store = WorldStore(directory);
  });

  tearDown(() => directory.deleteSync(recursive: true));

  group('A world outlives the process that ran it', () {
    test('an empty directory is not an error, it is a new world', () {
      expect(store.loadWorld(), isNull);
      expect(store.loadPlayers(), isEmpty);
    });

    test('what somebody built is still there after a restart', () {
      final first = GameHost.fromStore(store, seed: 99);
      first.state.world.setBlock(64, 30, 64, BlockType.planks);
      first.saveNow();

      final second = GameHost.fromStore(store);

      expect(second.state.world.seed, 99);
      expect(second.state.world.blockAt(64, 30, 64), BlockType.planks);
    });

    test('a returning player finds what they were carrying', () {
      final first = GameHost.fromStore(store, seed: 99);
      first.join(alice, RecordingLink());
      first.state.participants[alice]!.inventory.add(ItemType.ironIngot, 5);
      first.leave(alice);

      final second = GameHost.fromStore(store)..join(alice, RecordingLink());

      expect(
        second.state.participants[alice]!.inventory.countOf(ItemType.ironIngot),
        5,
      );
    });

    test('somebody who has never been here arrives new', () {
      final host = GameHost.fromStore(store)
        ..join(const PlayerId('stranger'), RecordingLink());

      expect(
        host.state.participants[const PlayerId('stranger')]!.inventory.countOf(
          ItemType.ironIngot,
        ),
        0,
      );
    });

    test('the world is written on a schedule, not only on the way out', () {
      final host = GameHost.fromStore(store, seed: 5);
      host.state.world.setBlock(64, 30, 64, BlockType.brick);

      for (var i = 0; i < GameHost.saveEvery; i++) {
        host.step();
      }

      expect(store.loadWorld(), isNotNull);
      expect(
        GameHost.fromStore(store).state.world.blockAt(64, 30, 64),
        BlockType.brick,
      );
    });
  });

  group('A store that will not be tricked', () {
    test('an unreadable world starts a new one instead of refusing to run', () {
      File('${directory.path}/world.json').writeAsStringSync('{ not json');

      // A server that will not start because of one bad file is worse than
      // one that says so and carries on.
      expect(store.loadWorld(), isNull);
      expect(() => GameHost.fromStore(store), returnsNormally);
    });

    test('a player id cannot reach outside the world directory', () {
      final host = GameHost.fromStore(store);
      const nasty = PlayerId('../../etc/passwd');
      host.join(nasty, RecordingLink());

      host.leave(nasty);

      // An id comes from a client, and a client is not to be trusted with
      // the server's file system.
      final written = Directory('${directory.path}/players').listSync();
      expect(written, hasLength(1));
      expect(written.single.path, contains(directory.path));
      expect(written.single.path, isNot(contains('..')));
    });

    test('one bad player file does not hide the others', () {
      final host = GameHost.fromStore(store);
      host.join(alice, RecordingLink());
      host.leave(alice);
      File('${directory.path}/players/broken.json').writeAsStringSync('nope');

      expect(WorldStore(directory).loadPlayers(), hasLength(1));
    });
  });
}
