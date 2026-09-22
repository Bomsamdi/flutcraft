import 'dart:convert';
import 'dart:typed_data';

import 'package:flutcraft_domain/flutcraft_domain.dart';

/// The server and the name that worked last time.
///
/// Not the password. Remembering that would mean keeping it somewhere a
/// player never agreed to, and the one thing it would save is the typing.
final class LastVisit {
  const LastVisit({this.address = '', this.name = ''});

  final String address;
  final String name;

  bool get isEmpty => address.isEmpty;
}

/// Keeps [LastVisit] beside the saves.
///
/// It goes through [SaveStorage] rather than straight to a file because the
/// composition root already has one, and it already knows what to do on a
/// platform that has no writable directory.
class ClientMemory {
  const ClientMemory(this._storage);

  static const String fileName = 'client';

  final SaveStorage _storage;

  Future<LastVisit> read() async {
    try {
      final bytes = await _storage.read(fileName);
      if (bytes == null) return const LastVisit();
      final raw = json.decode(utf8.decode(bytes)) as Map<String, Object?>;
      return LastVisit(
        address: raw['server'] as String? ?? '',
        name: raw['name'] as String? ?? '',
      );
    } on Object {
      // A convenience that cannot be read is not worth a failed launch.
      return const LastVisit();
    }
  }

  Future<void> write(LastVisit visit) async {
    try {
      await _storage.write(
        fileName,
        Uint8List.fromList(
          utf8.encode(
            json.encode({'server': visit.address, 'name': visit.name}),
          ),
        ),
      );
    } on Object {
      // Same again: forgetting where you played is not a reason to stop.
    }
  }
}
