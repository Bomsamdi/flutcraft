import 'dart:convert';
import 'dart:io';

import 'package:flutcraft_domain/flutcraft_domain.dart';

/// Where a server keeps its world and the people who have been in it.
///
/// Two kinds of document, in two kinds of file:
///
/// * `world.json` — the seed, the blocks that differ from it and the
///   furnaces. Rewritten whenever the autosave fires.
/// * `players/<id>.json` — one person's belongings and where they stood.
///   Written when that person leaves.
///
/// One file for both would mean every autosave rewrites everybody's
/// inventory, and moving a player between worlds would be impossible.
///
/// Not shared with the app's save storage on purpose: that one asks
/// `path_provider` for a container inside a sandboxed app, which is a Flutter
/// plugin and a concept a server does not have.
class WorldStore {
  WorldStore(this.directory, {this.codec = const SaveCodec()});

  final Directory directory;
  final SaveCodec codec;

  Directory get _players => Directory('${directory.path}/players');

  File get _world => File('${directory.path}/world.json');

  /// Reads the world, or `null` when this directory has never held one.
  ///
  /// A file that cannot be read is not a reason to refuse to start: the
  /// server says so and begins a new world, leaving the old file alone in
  /// case somebody wants to look at it.
  WorldSave? loadWorld() {
    if (!_world.existsSync()) return null;
    try {
      final raw =
          json.decode(_world.readAsStringSync()) as Map<String, Object?>;
      return codec.worldFromJson(raw, <SaveWarning>[]);
    } on Object catch (error) {
      stderr.writeln('Could not read ${_world.path}: $error');
      return null;
    }
  }

  /// Reads everybody this world remembers.
  List<PlayerSave> loadPlayers() {
    if (!_players.existsSync()) return const [];
    final saved = <PlayerSave>[];

    for (final file in _players.listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      try {
        final raw =
            json.decode(file.readAsStringSync()) as Map<String, Object?>;
        saved.add(codec.playerFromJson(raw, <SaveWarning>[]));
      } on Object catch (error) {
        stderr.writeln('Could not read ${file.path}: $error');
      }
    }
    return saved;
  }

  /// Writes the world down. False means it could not be written.
  bool saveWorld(WorldSave world) => _write(_world, codec.worldToJson(world));

  /// Writes one player down. False means they could not be written.
  bool savePlayer(PlayerSave player) => _write(
    File('${_players.path}/${_fileNameFor(player.id)}.json'),
    codec.playerToJson(player),
  );

  /// Writes to a temporary file and renames.
  ///
  /// A rename is atomic, so a server killed mid-save leaves the previous
  /// world intact rather than half of a new one that will not parse.
  ///
  /// A failure is reported and swallowed, as on the reading side. The disk is
  /// where a server meets everything it does not control — a full volume, a
  /// read-only mount, a directory owned by somebody else — and a save runs
  /// inside a tick and inside the handler for somebody leaving. Letting it
  /// throw takes down a process that everybody else is still playing on.
  /// Losing one save is bad; it is not as bad as losing the server.
  bool _write(File file, Map<String, Object?> document) {
    try {
      file.parent.createSync(recursive: true);
      final temporary = File('${file.path}.tmp')
        ..writeAsStringSync(json.encode(document), flush: true);
      temporary.renameSync(file.path);
      return true;
    } on Object catch (error) {
      stderr.writeln('Could not write ${file.path}: $error');
      return false;
    }
  }

  /// A player id, made safe to use as a file name.
  ///
  /// An id comes from a client and a client is not to be trusted with the
  /// server's file system: `../../etc/passwd` is a perfectly good string.
  static String _fileNameFor(PlayerId id) {
    final safe = id.value.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    return safe.isEmpty ? 'unnamed' : safe;
  }
}
