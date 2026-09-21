import 'dart:async';

import '../input/input_frame.dart';
import 'game_command.dart';
import 'game_event.dart';
import 'game_loop.dart';
import 'game_session.dart';
import 'game_snapshot.dart';

/// A [GameSession] driven by a [GameLoop].
///
/// Publishes snapshots at a fixed rate rather than every frame. At 60 Hz the
/// UI would rebuild sixty times a second for changes nobody can see; 20 Hz
/// is indistinguishable to the player and keeps the widget tree cheap.
/// Player actions publish immediately, because those must feel instant.
class LoopGameSession implements GameSession {
  LoopGameSession(this.loop, {this.snapshotHz = 20})
    : _snapshot = GameSnapshot.of(loop.state);

  final GameLoop loop;

  /// How many snapshots per second reach the interface.
  final int snapshotHz;

  final StreamController<GameSnapshot> _snapshots =
      StreamController<GameSnapshot>.broadcast();
  final StreamController<GameEvent> _events =
      StreamController<GameEvent>.broadcast();

  GameSnapshot _snapshot;
  double _sinceSnapshot = 0;

  @override
  GameSnapshot get snapshot => _snapshot;

  @override
  Stream<GameSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<GameEvent> get events => _events.stream;

  /// Advances the simulation. Call once per rendered frame.
  void tick(double dt, InputFrame input) {
    _publishEvents(loop.tick(dt, input));

    _sinceSnapshot += dt;
    if (_sinceSnapshot < 1 / snapshotHz) return;
    _sinceSnapshot = 0;
    _publishSnapshot();
  }

  @override
  void dispatch(GameCommand command) {
    _publishEvents(loop.dispatch(command));
    // An action the player just took should show up now, not up to 50 ms later.
    _publishSnapshot();
  }

  void _publishEvents(List<GameEvent> events) {
    for (final event in events) {
      _events.add(event);
    }
  }

  void _publishSnapshot() {
    _snapshot = GameSnapshot.of(loop.state);
    _snapshots.add(_snapshot);
  }

  Future<void> dispose() async {
    await _snapshots.close();
    await _events.close();
  }
}
