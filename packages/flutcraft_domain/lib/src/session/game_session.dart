import 'game_command.dart';
import 'game_event.dart';
import 'game_snapshot.dart';

/// Everything the user interface is allowed to do with the game.
///
/// Two members instead of the twenty-five methods the UI used to call on the
/// engine class. Because this is an interface in the domain, a widget test
/// can drive a real, headless game without Flame or a GPU anywhere in sight.
abstract interface class GameSession {
  /// Asks the game to do something.
  void dispatch(GameCommand command);

  /// The latest picture of the game, refreshed at a fixed rate.
  Stream<GameSnapshot> get snapshots;

  /// Things worth telling the player about, as they happen.
  Stream<GameEvent> get events;

  /// The current snapshot, for the first build before any stream event.
  GameSnapshot get snapshot;
}
