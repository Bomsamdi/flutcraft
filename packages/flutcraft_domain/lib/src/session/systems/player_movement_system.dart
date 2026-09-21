import '../../actors/player.dart';
import '../participant.dart';

/// Moves one player and keeps them inside the world.
///
/// Thin by design: the physics lives in [Player] and [VoxelBody]. This system
/// exists so the game loop has one place to call, and so that "the world is
/// frozen while a screen is open" is a rule of the simulation rather than an
/// early return buried in the engine.
class PlayerMovementSystem {
  const PlayerMovementSystem();

  void update(Participant participant, double dt, MoveInput input) {
    if (participant.route.pausesWorld) return;
    participant.player.update(dt, input);
  }
}
