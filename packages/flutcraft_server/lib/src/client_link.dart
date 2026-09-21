import 'package:flutcraft_protocol/flutcraft_protocol.dart';

/// One connected player, as the world sees them.
///
/// An interface rather than a socket, so the whole server can be driven in a
/// test that opens nothing. The socket is one implementation of this, and it
/// is the only part of the server that knows what a socket is.
abstract interface class ClientLink {
  /// Sends a message, or drops it if this client has stopped keeping up.
  void send(ServerMessage message);

  /// Closes the connection.
  void close();
}

/// Remembers what was sent, for tests and for a server that talks to itself.
class RecordingLink implements ClientLink {
  final List<ServerMessage> sent = [];
  bool closed = false;

  /// The most recent message of a given kind, or `null` if none arrived.
  T? last<T extends ServerMessage>() => sent.whereType<T>().lastOrNull;

  /// Every message of a given kind, oldest first.
  List<T> all<T extends ServerMessage>() => sent.whereType<T>().toList();

  @override
  void send(ServerMessage message) => sent.add(message);

  @override
  void close() => closed = true;
}
