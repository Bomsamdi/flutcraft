import 'dart:async';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutter/foundation.dart';

/// The default — and, for now, only — save slot.
const String kWorldSlot = 'world';

/// Writes saves to a repository without blocking the frame that made them.
///
/// The simulation hands over a finished [SaveData] and moves on; encoding and
/// disk I/O happen afterwards. If another save arrives while one is still
/// being written, the newer one replaces the queued one — there is no point
/// writing a state the player has already left behind.
class RepositorySaveSink implements SaveSink {
  RepositorySaveSink({required this.repository, this.slot = kWorldSlot});

  final SaveRepository repository;
  final String slot;

  SaveData? _pending;
  bool _writing = false;

  @override
  void persist(SaveData data) {
    _pending = data;
    if (!_writing) unawaited(_drain());
  }

  Future<void> _drain() async {
    _writing = true;
    try {
      while (_pending != null) {
        final data = _pending!;
        _pending = null;
        try {
          await repository.save(slot, data);
        } on Object catch (error) {
          // A failed save must never take the game down with it.
          debugPrint('Could not save the game: $error');
        }
      }
    } finally {
      _writing = false;
    }
  }
}
