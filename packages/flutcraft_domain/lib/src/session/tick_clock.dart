/// How many simulation steps fit in one second.
///
/// The same number on every machine and on the server. A tick is the unit
/// everything else is counted in, so it is a constant rather than a setting.
const int kTicksPerSecond = 60;

/// How much time one simulation step covers, in seconds.
const double kStep = 1 / kTicksPerSecond;

/// The most steps one rendered frame may be worth — a quarter of a second.
const int kMaxCatchUp = kTicksPerSecond ~/ 4;

/// Turns wall-clock time into a whole number of fixed simulation steps.
///
/// The simulation used to advance by whatever `dt` the renderer happened to
/// hand it, and that quietly made the outcome depend on the frame rate:
/// [VoxelBody] splits a move into sub-steps and snaps to a block edge on
/// contact, so the same held key lands a player on a different side of the
/// same wall at 30 fps and at 120 fps. Nothing can be predicted, replayed or
/// agreed on between two machines while that is true.
class TickClock {
  TickClock({this.step = kStep, this.maxCatchUp = kMaxCatchUp})
    : assert(step > 0, 'a step of zero would never advance'),
      assert(maxCatchUp > 0, 'the clock has to be allowed at least one step');

  /// Seconds covered by one step.
  final double step;

  /// The most steps one call may run.
  ///
  /// A quarter of a second: long enough to swallow the worst hitch a chunk
  /// rebuild produces, so a stutter costs smoothness rather than distance.
  /// Past it the frame is not a hitch but a suspended app — a phone woken
  /// after eight seconds in a pocket would otherwise freeze the game while
  /// it simulated eight seconds of nothing.
  final int maxCatchUp;

  double _pending = 0;
  int _elapsed = 0;

  /// Steps run since the clock started.
  ///
  /// Monotonic, and the number a networked client and server will later
  /// stamp their messages with — two machines agreeing on *when* something
  /// happened is the whole reason the step is fixed.
  int get elapsed => _elapsed;

  /// Whether the last call had to throw time away.
  bool get skipped => _skipped;
  bool _skipped = false;

  /// How many steps [dt] seconds of wall clock have earned.
  int stepsFor(double dt) {
    if (dt > 0) _pending += dt;

    var steps = _pending ~/ step;
    _skipped = steps > maxCatchUp;
    if (_skipped) {
      steps = maxCatchUp;
      _pending = 0;
    } else {
      _pending -= steps * step;
    }

    _elapsed += steps;
    return steps;
  }
}
