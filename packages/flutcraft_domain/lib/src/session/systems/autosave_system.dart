import '../../save/game_persistence.dart';
import '../../save/save_sink.dart';
import '../game_state.dart';

/// Captures the game every [interval] seconds and hands it to a [SaveSink].
///
/// Runs even while a screen is open: the player pausing to sort their
/// inventory is a good moment to save, not a reason to stop.
class AutosaveSystem {
  AutosaveSystem({
    required this.sink,
    this.interval = 60,
    this.persistence = const GamePersistence(),
  }) : assert(interval > 0, 'an interval of zero would save every frame');

  final SaveSink sink;

  /// Seconds between automatic saves.
  final double interval;

  final GamePersistence persistence;

  double _sinceLastSave = 0;

  /// Seconds until the next automatic save.
  double get untilNextSave => interval - _sinceLastSave;

  /// Returns `true` on the frames where it saved.
  bool update(GameState state, double dt) {
    _sinceLastSave += dt;
    if (_sinceLastSave < interval) return false;
    return saveNow(state);
  }

  /// Saves immediately and restarts the countdown.
  ///
  /// Returns `false` when there was nothing worth saving. A dead player is
  /// never written: that state would mean the next launch opens straight onto
  /// the death screen, with the world's last living moment overwritten.
  bool saveNow(GameState state) {
    _sinceLastSave = 0;
    // Nobody left alive is the same reason not to save as a dead solo
    // player: the next launch would open straight onto a death screen.
    if (state.participants.values.every((p) => p.player.isDead)) return false;
    sink.persist(persistence.capture(state));
    return true;
  }
}
