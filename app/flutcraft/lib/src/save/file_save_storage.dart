import 'dart:io';
import 'dart:typed_data';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:path_provider/path_provider.dart';

/// Saves as files in the application support directory.
///
/// The only part of persistence that touches a platform. The domain talks to
/// [SaveStorage]; this is the adapter behind it, which is why the save format
/// itself can be tested without a device.
class FileSaveStorage implements SaveStorage {
  const FileSaveStorage(this.directory);

  final Directory directory;

  /// Opens — and creates, if needed — the directory saves live in.
  static Future<FileSaveStorage> open() async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory('${base.path}/saves');
    await directory.create(recursive: true);
    return FileSaveStorage(directory);
  }

  File _file(String name) => File('${directory.path}/$name');

  @override
  Future<Uint8List?> read(String name) async {
    final file = _file(name);
    return await file.exists() ? file.readAsBytes() : null;
  }

  /// Writes to a temporary file first, then renames.
  ///
  /// A rename is atomic, so a crash mid-save leaves the previous save intact
  /// instead of a half-written file that fails to parse.
  @override
  Future<void> write(String name, Uint8List bytes) async {
    final temporary = _file('$name.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(_file(name).path);
  }

  @override
  Future<void> delete(String name) async {
    final file = _file(name);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<List<String>> list() async {
    final entries = await directory.list().toList();
    return [
      for (final entry in entries.whereType<File>())
        entry.uri.pathSegments.last,
    ]..sort();
  }
}
