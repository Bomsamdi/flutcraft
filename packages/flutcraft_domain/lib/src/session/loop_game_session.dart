import 'dart:async';

import '../actors/player_id.dart';
import '../input/input_frame.dart';
import 'addressed_event.dart';
import 'game_command.dart';
import 'game_event.dart';
import 'game_loop.dart';
import 'game_session.dart';
import 'game_state.dart';
import 'game_snapshot.dart';
import 'simulated_session.dart';
import 'tick_clock.dart';

/// A [GameSession] driven by a [GameLoop], for one player.
///
/// The loop itself runs any number of players; this is the single-player
/// facade the app talks to. A server would drive the same loop with one
/// input frame per connection instead.
///
/// Publishes snapshots at a fixed rate rather than every frame. At 60 Hz the
/// UI would rebuild sixty times a second for changes nobody can see; 20 Hz
/// is indistinguishable to the player and keeps the widget tree cheap.
/// Player actions publish immediately, because those must feel instant.
class LoopGameSession implements GameSession, SimulatedSession {
  LoopGameSession(this.loop, {this.snapshotHz = 20, TickClock? clock})
    : _clock = clock ?? TickClock(),
      _snapshot = GameSnapshot.of(loop.state);

  final GameLoop loop;

  /// Turns rendered frames into whole simulation steps.
  final TickClock _clock;

  /// How many snapshots per second reach the interface.
  final int snapshotHz;

  final StreamController<GameSnapshot> _snapshots =
      StreamController<GameSnapshot>.broadcast();
  final StreamController<GameEvent> _events =
      StreamController<GameEvent>.broadcast();

  GameSnapshot _snapshot;
  int _stepsSinceSnapshot = 0;

  @override
  GameSnapshot get snapshot => _snapshot;

  @override
  Stream<GameSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<GameEvent> get events => _events.stream;

  @override
  GameState get state => loop.state;

  /// The only player, because this session drives a single-player game.
  @override
  PlayerId get viewerId => loop.state.solo.id;

  /// Advances the simulation. Call once per rendered frame with the real
  /// time that frame took; the clock decides how many steps that is worth.
  @override
  void tick(double dt, InputFrame input) {
    final steps = _clock.stepsFor(dt);
    for (var i = 0; i < steps; i++) {
      _publishEvents(loop.tickSolo(_clock.step, input.asStep(i, steps)));
    }

    // Counted in steps rather than seconds, so the rate a widget rebuilds at
    // does not drift with the frame rate.
    _stepsSinceSnapshot += steps;
    if (_stepsSinceSnapshot < kTicksPerSecond / snapshotHz) return;
    _stepsSinceSnapshot = 0;
    _publishSnapshot();
  }

  @override
  void dispatch(GameCommand command) {
    _publishEvents(loop.dispatchSolo(command));
    // An action the player just took should show up now, not up to 50 ms later.
    _publishSnapshot();
  }

  /// Publishes what this player is meant to hear.
  ///
  /// The loop reports everyone's events; a single-player session filters to
  /// its own. That is what keeps [GameSession.events] the same four-member
  /// contract the widgets were written against.
  void _publishEvents(List<AddressedEvent> events) {
    for (final event in events.forPlayer(loop.state.solo.id)) {
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
