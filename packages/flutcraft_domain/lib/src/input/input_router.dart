import 'game_action.dart';
import 'input_frame.dart';

/// Collects what every input source reports and hands the loop one frame.
///
/// Sources — keyboard, pointer, touch buttons, gamepad — push into this and
/// never talk to the game directly. Because they all arrive here, axes are
/// blended and clamped in exactly one place, and a joystick pushed while the
/// movement keys are held no longer produces a speed of two.
class InputRouter {
  InputRouter({this.keyboardLookSpeed = 1.8});

  /// Radians per second while a look key is held.
  final double keyboardLookSpeed;

  final Set<GameAction> _held = {};
  final List<GameAction> _pressed = [];

  double _stickForward = 0;
  double _stickStrafe = 0;
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

  /// Everything goes up — call it when focus is lost, or the player keeps
  /// walking into a wall while typing somewhere else.
  void releaseAll() {
    _held.clear();
    _pressed.clear();
    _stickForward = 0;
    _stickStrafe = 0;
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
              dt,
      lookPitch:
          _lookPitch +
          _axis(0, GameAction.lookUp, GameAction.lookDown) *
              keyboardLookSpeed *
              dt,
      held: Set.unmodifiable(_held),
      pressed: List.unmodifiable(_pressed),
    );

    _pressed.clear();
    _lookYaw = 0;
    _lookPitch = 0;
    return frame;
  }

  double _axis(double base, GameAction positive, GameAction negative) {
    var value = base;
    if (_held.contains(positive)) value += 1;
    if (_held.contains(negative)) value -= 1;
    return value.clamp(-1, 1);
  }
}
