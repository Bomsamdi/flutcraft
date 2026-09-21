import 'dart:typed_data';

import 'save_codec.dart';
import 'save_data.dart';

/// Where saves live. The domain says *what* to store, never *how*.
abstract interface class SaveStorage {
  Future<Uint8List?> read(String name);

  Future<void> write(String name, Uint8List bytes);

  Future<void> delete(String name);

  Future<List<String>> list();
}

/// Keeps saves in memory — the default in tests, and a working fallback on
/// platforms without a file system.
class InMemorySaveStorage implements SaveStorage {
  final Map<String, Uint8List> _files = {};

  @override
  Future<Uint8List?> read(String name) async => _files[name];

  @override
  Future<void> write(String name, Uint8List bytes) async =>
      _files[name] = bytes;

  @override
  Future<void> delete(String name) async => _files.remove(name);

  @override
  Future<List<String>> list() async => _files.keys.toList()..sort();
}

/// Reads and writes saved games.
class SaveRepository {
  const SaveRepository({required this.storage, this.codec = const SaveCodec()});

  final SaveStorage storage;
  final SaveCodec codec;

  String _fileName(String slot) => 'save_$slot.json';

  Future<void> save(String slot, SaveData data) =>
      storage.write(_fileName(slot), codec.encode(data));

  /// Returns `null` when the slot is empty.
  Future<LoadResult?> load(String slot) async {
    final bytes = await storage.read(_fileName(slot));
    if (bytes == null) return null;
    return codec.decode(bytes);
  }

  Future<void> delete(String slot) => storage.delete(_fileName(slot));

  Future<List<String>> slots() async {
    final files = await storage.list();
    return [
      for (final file in files)
        if (file.startsWith('save_') && file.endsWith('.json'))
          file.substring('save_'.length, file.length - '.json'.length),
    ];
  }
}
