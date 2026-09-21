import '../../actors/player.dart';
import '../game_state.dart';

/// Moves the player and keeps them inside the world.
///
/// Thin by design: the physics lives in [Player] and [VoxelBody]. This system
/// exists so the game loop has one place to call, and so that "the world is
/// frozen while a screen is open" is a rule of the simulation rather than an
/// early return buried in the engine.
class PlayerMovementSystem {
  const PlayerMovementSystem();

  void update(GameState state, double dt, MoveInput input) {
    if (state.route.pausesWorld) return;
    state.player.update(dt, input);
  }
}
