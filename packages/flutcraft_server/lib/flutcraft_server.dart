/// An authoritative Flutcraft server.
///
/// Pure Dart. The rules live in `flutcraft_domain` and the words on the wire
/// in `flutcraft_protocol`; what is here is who is connected, what they are
/// told, and when.
library;

export 'src/accounts.dart';
export 'src/client_link.dart';
export 'src/game_host.dart';
export 'src/outbound_queue.dart';
export 'src/web_socket_host.dart';
export 'src/world_store.dart';
