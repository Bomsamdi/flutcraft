import 'game_action.dart';
import 'input_frame.dart';

/// Collects what every input source reports and hands the loop one frame.
///
/// Sources — keyboard, pointer, touch buttons, gamepad — push into this and
/// never talk to the game directly. Because they all arrive here, axes are
/// blended and clamped in exactly one place, and a joystick pushed while the
/// movement keys are held no longer produces a speed of two.
class InputRouter {
  InputRouter({this.keyboardLookSpeed = 1.8, this.lookStickSpeed = 2.8});

  /// Radians per second while a look key is held.
  final double keyboardLookSpeed;

  /// Radians per second at full deflection of the look stick.
  ///
  /// Roughly 160 degrees a second, so turning right around is a held thumb
  /// rather than four swipes across the screen.
  final double lookStickSpeed;

  final Set<GameAction> _held = {};
  final List<GameAction> _pressed = [];

  double _stickForward = 0;
  double _stickStrafe = 0;
  double _lookStickX = 0;
  double _lookStickY = 0;
  double _lookYaw = 0;
  double _lookPitch = 0;

  /// A button went down. Sources may repeat this; only the first counts.
  void press(GameAction action) {
    if (_held.add(action)) _pressed.add(action);
  }

  void release(GameAction action) => _held.remove(action);

  /// Press or release depending on [down] — what a hold button reports.
  void hold(GameAction action, {required bool down}) =>
      down ? press(action) : release(action);

  bool isHeld(GameAction action) => _held.contains(action);

  /// Replaces the set of held actions wholesale.
  ///
  /// Flutter reports the keys that are down, not the changes, so a keyboard
  /// source knows the whole truth every event and pushing it as a set avoids
  /// keys getting stuck down when a window loses focus mid-press.
  void setHeld(Set<GameAction> actions) {
    for (final action in actions) {
      press(action);
    }
    _held.removeWhere((action) => !actions.contains(action));
  }

  /// The virtual joystick, each axis in -1..1.
  void setStick({required double forward, required double strafe}) {
    _stickForward = forward.clamp(-1, 1);
    _stickStrafe = strafe.clamp(-1, 1);
  }

  /// Turn by this much, in radians. Pointer and gyro sources add deltas here;
  /// they accumulate until the next frame is built.
  void look(double yaw, double pitch) {
    _lookYaw += yaw;
    _lookPitch += pitch;
  }

  /// The look stick, each axis -1..1, with [x] to the right and [y] upwards.
  ///
  /// A stick is a *rate*, not a delta: a drag moves the view by how far the
  /// finger travelled, while a stick keeps turning for as long as it is held.
  /// That is the whole reason it exists — a drag has to end at the edge of
  /// the screen, so a half-turn takes four of them.
  ///
  /// Which way the view moves is decided here rather than by the widget, for
  /// the same reason every other axis is clamped in one place.
  void setLookStick({required double x, required double y}) {
    _lookStickX = x.clamp(-1, 1);
    _lookStickY = y.clamp(-1, 1);
  }

  /// Everything goes up — call it when focus is lost, or the player keeps
  /// walking into a wall while typing somewhere else.
  void releaseAll() {
    _held.clear();
    _pressed.clear();
    _stickForward = 0;
    _stickStrafe = 0;
    _lookStickX = 0;
    _lookStickY = 0;
  }

  /// Builds the frame for this tick and consumes the edges it reports.
  InputFrame build(double dt) {
    final frame = InputFrame(
      forward: _axis(
        _stickForward,
        GameAction.moveForward,
        GameAction.moveBack,
      ),
      strafe: _axis(
        _stickStrafe,
        GameAction.strafeRight,
        GameAction.strafeLeft,
      ),
      lookYaw:
          _lookYaw +
          _axis(0, GameAction.lookLeft, GameAction.lookRight) *
              keyboardLookSpeed *
              dt -
          _curved(_lookStickX) * lookStickSpeed * dt,
      lookPitch:
          _lookPitch +
          _axis(0, GameAction.lookUp, GameAction.lookDown) *
              keyboardLookSpeed *
              dt +
          _curved(_lookStickY) * lookStickSpeed * dt,
      held: Set.unmodifiable(_held),
      pressed: List.unmodifiable(_pressed),
    );

    _pressed.clear();
    _lookYaw = 0;
    _lookPitch = 0;
    return frame;
  }

  /// Squares the deflection while keeping its sign.
  ///
  /// A linear stick is twitchy: the small movements used for aiming live in
  /// the same few degrees of travel as a full spin. Squaring gives fine
  /// control near the centre without giving up the top speed at the edge.
  static double _curved(double value) => value * value.abs();

  double _axis(double base, GameAction positive, GameAction negative) {
    var value = base;
    if (_held.contains(positive)) value += 1;
    if (_held.contains(negative)) value -= 1;
    return value.clamp(-1, 1);
  }
}
