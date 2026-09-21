import 'package:meta/meta.dart';

import '../actors/player.dart';
import 'game_action.dart';

/// What the player is asking for during one tick.
///
/// Axes arrive already blended and clamped: the loop never has to know that
/// a joystick and the movement keys were both pushed at once. Held actions
/// last as long as the button does; pressed actions are edges, consumed once.
@immutable
final class InputFrame {
  const InputFrame({
    this.forward = 0,
    this.strafe = 0,
    this.lookYaw = 0,
    this.lookPitch = 0,
    this.held = const {},
    this.pressed = const [],
  });

  /// -1 (backwards) .. 1 (forwards)
  final double forward;

  /// -1 (left) .. 1 (right)
  final double strafe;

  /// Radians to turn this tick, already scaled by sensitivity.
  final double lookYaw;
  final double lookPitch;

  /// Buttons currently down.
  final Set<GameAction> held;

  /// Buttons that went down during this tick, in the order they did.
  final List<GameAction> pressed;

  /// Nothing is being pressed. The default in tests.
  static const idle = InputFrame();

  bool isHeld(GameAction action) => held.contains(action);

  /// This frame as step [index] of [steps] equal simulation steps.
  ///
  /// A rendered frame can be worth more than one step, and the parts of a
  /// frame do not all divide the same way:
  ///
  /// * Axes and held buttons are *states*. They are the same in every step.
  /// * A press is an *edge*. It belongs to the first step alone — otherwise
  ///   one tap of the inventory key would open and immediately close it.
  /// * Look deltas are *amounts already accumulated*. They are shared out,
  ///   or a 30 fps frame would turn twice as far as a 60 fps one.
  InputFrame asStep(int index, int steps) {
    if (steps <= 1) return this;
    return InputFrame(
      forward: forward,
      strafe: strafe,
      lookYaw: lookYaw / steps,
      lookPitch: lookPitch / steps,
      held: held,
      pressed: index == 0 ? pressed : const [],
    );
  }

  /// Movement as the player physics wants it.
  ///
  /// Sprint doubles as descend while flying — one button, two meanings,
  /// decided here rather than in three different input sources.
  MoveInput moveFor({required bool flying}) => MoveInput(
    forward: forward,
    strafe: strafe,
    jump: isHeld(GameAction.jump),
    crouch: isHeld(GameAction.crouch) || (flying && isHeld(GameAction.sprint)),
    sprint: !flying && isHeld(GameAction.sprint),
  );
}
