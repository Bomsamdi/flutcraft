/// What a Flutcraft client and server say to each other.
///
/// Pure Dart, and deliberately without `dart:io`: a message has to be
/// decodable in a test that opens no sockets, and the same package has to
/// compile into a Flutter app and into a server binary.
library;

export 'src/entity_mirror.dart';
export 'src/json_message_codec.dart';
export 'src/message_channel.dart';
export 'src/message_codec.dart';
export 'src/messages.dart';
export 'src/remote_game_session.dart';
export 'src/wire_values.dart';
