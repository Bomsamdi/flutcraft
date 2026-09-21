import 'dart:async';

import 'messages.dart';

/// Something that carries messages to a server and back.
///
/// An interface rather than a socket, so a whole client can be driven in a
/// test with a list on each side. The socket implementation lives in the app,
/// beside the other platform I/O, which is what keeps `dart:io` out of this
/// package entirely.
abstract interface class MessageChannel {
  /// What the server has said.
  Stream<ServerMessage> get incoming;

  /// Says something to the server.
  void send(ClientMessage message);

  Future<void> close();
}

/// A channel with both ends in the same process, for tests.
class FakeChannel implements MessageChannel {
  final _incoming = StreamController<ServerMessage>.broadcast();

  /// Everything the client has said, in order.
  final List<ClientMessage> sent = [];

  /// Pretends the server said this.
  void deliver(ServerMessage message) => _incoming.add(message);

  bool closed = false;

  @override
  Stream<ServerMessage> get incoming => _incoming.stream;

  @override
  void send(ClientMessage message) => sent.add(message);

  @override
  Future<void> close() async {
    closed = true;
    await _incoming.close();
  }
}
