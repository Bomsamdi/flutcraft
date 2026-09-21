import '../actors/player_id.dart';
import '../input/input_frame.dart';
import 'game_state.dart';
import 'participant.dart';

/// A running game, as the thing that draws it needs to see it.
///
/// [GameSession] is what the *interface* is allowed to do: send a command,
/// read a snapshot. A renderer needs something else — the live world, so it
/// can mesh chunks and follow entities frame by frame — and pretending
/// otherwise is how the engine ended up naming a concrete class and reaching
/// through it into the aggregate.
///
/// Naming the viewer is the other half. A simulation can hold several
/// players; a renderer draws exactly one point of view, and which one is a
/// decision somebody has to make rather than a lucky guess about there being
/// only one.
abstract interface class SimulatedSession {
  /// The world as it is right now.
  GameState get state;

  /// Whose eyes this client is looking through.
  PlayerId get viewerId;

  /// Advances the game by a rendered frame's worth of time.
  void tick(double dt, InputFrame input);
}

/// Reading the viewer out of a session.
extension ViewerOf on SimulatedSession {
  /// The player this client is playing.
  ///
  /// Throws if that player is not in the world, which is the right answer:
  /// drawing somebody else's game silently would be worse.
  Participant get viewer => state.participants[viewerId]!;
}
