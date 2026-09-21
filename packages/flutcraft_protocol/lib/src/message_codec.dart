import 'dart:typed_data';

import 'messages.dart';

/// How messages are spelled on the wire.
///
/// An interface from the first message, with one implementation behind it.
/// JSON is the right first answer — it reuses conventions the save format
/// already established, and a frame can be read in a terminal while the game
/// runs — but bandwidth is not the reason it was chosen, so swapping in a
/// packed codec later should cost one line at the composition root.
abstract interface class MessageCodec {
  Uint8List encodeClient(ClientMessage message);

  Uint8List encodeServer(ServerMessage message);

  ClientMessage decodeClient(Uint8List bytes);

  ServerMessage decodeServer(Uint8List bytes);
}

/// The wire format changed in a way the other end cannot read.
class ProtocolMismatch implements Exception {
  const ProtocolMismatch(this.found, this.expected);

  final int found;
  final int expected;

  @override
  String toString() =>
      'Protocol version $found, but this build speaks $expected';
}

/// A message this build has no idea about.
///
/// Unknown *members* — an action, an item, a block added in a later version —
/// are dropped and the rest of the message is still read. An unknown message
/// is different: half of it cannot be applied, so it is refused outright.
class UnknownMessage implements Exception {
  const UnknownMessage(this.type);

  final String type;

  @override
  String toString() => 'No such message: "$type"';
}
