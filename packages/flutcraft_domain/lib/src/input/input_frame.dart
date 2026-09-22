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

  /// The same intent, minus everything that may only happen once.
  ///
  /// A server keeps a client's last input for a few ticks so that one lost
  /// packet does not freeze that player. A held key genuinely still counts
  /// while the next packet is late; a press and a look delta do not — held
  /// for ten ticks they would open a screen ten times and spin the view a
  /// tenfold.
  InputFrame get sustained =>
      InputFrame(forward: forward, strafe: strafe, held: held);

  /// This frame followed by [later], as one frame.
  ///
  /// The mirror image of [asStep], and needed for the same reason: a frame is
  /// part state and part amount, and the two combine differently.
  ///
  /// * Axes and held buttons are *states*. The newer one wins; what the
  ///   player was holding a moment ago does not matter any more.
  /// * Presses are *edges*, and no edge may be lost: a dropped tap is a block
  ///   that was never placed.
  /// * Look deltas are *amounts*. They add up, because each is a piece of one
  ///   continuous turn.
  ///
  /// A server needs this because frames arrive in bursts — a socket hands
  /// over whatever the network delivered together — while the world steps on
  /// its own clock. Keeping only the newest of a burst throws away most of a
  /// fast turn, and the player it belongs to would be drawn facing somewhere
  /// they never looked.
  InputFrame mergedWith(InputFrame later) => InputFrame(
    forward: later.forward,
    strafe: later.strafe,
    lookYaw: lookYaw + later.lookYaw,
    lookPitch: lookPitch + later.lookPitch,
    held: later.held,
    pressed: [...pressed, ...later.pressed],
  );

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
