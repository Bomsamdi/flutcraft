import 'package:flutcraft_protocol/flutcraft_protocol.dart';

/// What is waiting to go out to one client.
///
/// `dart:io` never blocks on `WebSocket.add` and buffers without limit, and
/// there is nothing to consult about how much is pending. Six kilobytes a
/// second is nothing — until a phone spends a minute in a pocket, stops
/// reading, and the server is quietly holding a third of a megabyte for a
/// peer that may never come back.
///
/// So the queue is bounded, and it knows which messages may be thrown away:
///
/// * A *snapshot* is the whole truth as of a moment. Only the newest is worth
///   sending; an entity delta from 200 ms ago helps nobody.
/// * A *record* is one entry in an ordered log. Dropping a block change or an
///   inventory update leaves the client wrong about the world for good.
///
/// Past the cap the connection is closed. A client that cannot keep up with
/// six kilobytes a second is not going to catch up.
class OutboundQueue {
  OutboundQueue({this.capacity = 64});

  /// How many records may wait before the connection is hopeless.
  final int capacity;

  final List<ServerMessage> _records = [];
  final Map<Type, ServerMessage> _snapshots = {};

  /// Whether the client fell so far behind that it should be disconnected.
  bool get overflowed => _overflowed;
  bool _overflowed = false;

  /// How many messages are waiting.
  int get length => _records.length + _snapshots.length;

  /// Whether this kind of message may be replaced by a newer one.
  static bool isSnapshot(ServerMessage message) => switch (message) {
    EntityDelta() || PlayerStates() || SelfState() => true,
    Welcome() ||
    WorldDelta() ||
    InventoryState() ||
    ExplosionAt() ||
    Notice() ||
    Ping() ||
    Kick() => false,
  };

  void add(ServerMessage message) {
    if (isSnapshot(message)) {
      _snapshots[message.runtimeType] = message;
      return;
    }
    if (_records.length >= capacity) {
      _overflowed = true;
      return;
    }
    _records.add(message);
  }

  /// Takes everything waiting, records first so the log stays in order.
  List<ServerMessage> drain() {
    final out = [..._records, ..._snapshots.values];
    _records.clear();
    _snapshots.clear();
    return out;
  }
}
