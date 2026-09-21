import '../actors/player_id.dart';
import '../blocks/block_pos.dart';
import '../blocks/block_type.dart';
import '../items/item_type.dart';

/// A saved game: one world, and everybody who was in it.
///
/// The two halves are kept apart on purpose. A world is rewritten every time
/// the autosave fires; a player's belongings change when that player does
/// something. Welding them into one document would mean every autosave
/// rewrites everyone's inventory, and moving a player between worlds would
/// be impossible.
class SaveData {
  const SaveData({required this.world, required this.players, this.savedAt});

  /// A game with exactly one player in it, which is what the app runs.
  factory SaveData.solo({
    required WorldSave world,
    required PlayerSave player,
    DateTime? savedAt,
  }) => SaveData(world: world, players: [player], savedAt: savedAt);

  final WorldSave world;

  /// Everyone whose belongings this save holds, in no particular order.
  final List<PlayerSave> players;

  final DateTime? savedAt;

  /// The only player, for a save that holds one.
  PlayerSave get solo => players.single;
}

/// A world: what it was generated from, and everything done to it since.
class WorldSave {
  const WorldSave({
    required this.seed,
    required this.edits,
    required this.furnaces,
  });

  final int seed;

  /// Only the blocks that differ from the generated terrain.
  final Map<BlockPos, BlockType> edits;

  final List<SavedFurnace> furnaces;
}

/// One player's belongings and where they were standing.
class PlayerSave {
  const PlayerSave({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
    required this.yaw,
    required this.pitch,
    required this.health,
    required this.flying,
    required this.inventory,
    required this.selectedSlot,
  });

  /// The player's own id, which survives a reconnect.
  ///
  /// Not the connection: coming back after a dropped connection has to find
  /// the same inventory, not a new player standing beside the old one's
  /// belongings.
  final PlayerId id;

  final double x;
  final double y;
  final double z;
  final double yaw;
  final double pitch;
  final int health;
  final bool flying;

  /// All 36 slots; `null` means empty.
  final List<ItemStack?> inventory;

  final int selectedSlot;
}

class SavedFurnace {
  const SavedFurnace({
    required this.pos,
    required this.input,
    required this.fuel,
    required this.output,
    required this.burnLeft,
    required this.burnTotal,
    required this.progress,
  });

  final BlockPos pos;
  final ItemStack? input;
  final ItemStack? fuel;
  final ItemStack? output;
  final double burnLeft;
  final double burnTotal;
  final double progress;
}

/// A problem found while loading that did not stop the load.
class SaveWarning {
  const SaveWarning(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The outcome of loading: a game, plus anything that had to be skipped.
class LoadResult {
  const LoadResult(this.data, this.warnings);

  final SaveData data;
  final List<SaveWarning> warnings;
}

/// Thrown when a save comes from a newer version than this build understands.
class SaveTooNewException implements Exception {
  const SaveTooNewException(this.version, this.supported);

  final int version;
  final int supported;

  @override
  String toString() =>
      'Save version $version is newer than the supported $supported';
}
