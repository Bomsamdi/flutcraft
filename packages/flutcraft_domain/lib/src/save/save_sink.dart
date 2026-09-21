import 'save_data.dart';

/// Where a finished save goes.
///
/// The loop is synchronous and the domain owns no I/O, so it hands the
/// captured [SaveData] over and forgets about it. Writing bytes — to a file,
/// to a database, to nothing at all in tests — is the adapter's problem.
abstract interface class SaveSink {
  void persist(SaveData data);
}

/// Remembers the last save instead of writing it. Used by tests.
class RecordingSaveSink implements SaveSink {
  final List<SaveData> saves = [];

  SaveData? get last => saves.isEmpty ? null : saves.last;

  @override
  void persist(SaveData data) => saves.add(data);
}
