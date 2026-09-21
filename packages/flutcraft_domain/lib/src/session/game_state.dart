import 'package:vector_math/vector_math.dart';

import '../actors/mob.dart';
import '../actors/player.dart';
import '../inventory/inventory.dart';
import '../machines/furnace_registry.dart';
import '../world/voxel_world.dart';
import 'participant.dart';

/// Everything the simulation knows.
///
/// One aggregate passed to every system, so that systems stay free functions
/// over state rather than methods on an object that owns half the game. It
/// holds no rendering, no textures and no widgets — those read from it.
///
/// The world, the mobs and the furnaces are shared by everyone in it; what
/// belongs to one player lives in their [Participant].
class GameState {
  GameState({required this.world, required Iterable<Participant> players})
    : participants = {for (final player in players) player.id: player} {
    assert(participants.isNotEmpty, 'a game needs at least one player');
  }

  /// A game with a single player — what the app runs, and what most tests
  /// want. The id is fixed because there is nobody to tell it apart from.
  factory GameState.solo({
    required VoxelWorld world,
    required Player player,
    required Inventory inventory,
    int hotbarSlot = 0,
  }) => GameState(
    world: world,
    players: [
      Participant(
        id: soloId,
        player: player,
        inventory: inventory,
        selectedSlot: hotbarSlot,
      ),
    ],
  );

  /// The id given to the only player of a single-player game.
  static const PlayerId soloId = PlayerId('solo');

  final VoxelWorld world;

  /// Everyone in this world, by id.
  final Map<PlayerId, Participant> participants;

  final List<Mob> mobs = [];
  final List<Arrow> arrows = [];
  final FurnaceRegistry furnaces = FurnaceRegistry();

  /// The only player, for a game that has only one.
  ///
  /// Throws where several are present, which is the point: code written for
  /// one player should not quietly pick a winner.
  Participant get solo => participants.values.single;

  /// Adds a player to a world that is already running.
  void join(Participant player) => participants[player.id] = player;

  /// Removes a player. Returns them, so a caller can save what they carried.
  Participant? leave(PlayerId id) => participants.remove(id);

  /// The living player nearest to [point], or `null` when everyone is dead.
  ///
  /// What a mob chases. With one player it is that player; with several it is
  /// whoever wandered too close.
  Participant? nearestLivingTo(Vector3 point) {
    Participant? best;
    var bestDistance = double.infinity;

    for (final participant in participants.values) {
      if (participant.player.isDead) continue;
      final distance = participant.player.position.distanceToSquared(point);
      if (distance >= bestDistance) continue;
      best = participant;
      bestDistance = distance;
    }
    return best;
  }
}
