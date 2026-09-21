import '../blocks/block_pos.dart';
import '../blocks/block_type.dart';
import '../items/item_type.dart';

/// A saved game, independent of how it is stored.
class SaveData {
  const SaveData({
    required this.seed,
    required this.edits,
    required this.player,
    required this.inventory,
    required this.selectedSlot,
    required this.furnaces,
    this.savedAt,
  });

  final int seed;

  /// Only the blocks that differ from the generated terrain.
  final Map<BlockPos, BlockType> edits;

  final SavedPlayer player;

  /// All 36 slots; `null` means empty.
  final List<ItemStack?> inventory;

  final int selectedSlot;
  final List<SavedFurnace> furnaces;
  final DateTime? savedAt;
}

class SavedPlayer {
  const SavedPlayer({
    required this.x,
    required this.y,
    required this.z,
    required this.yaw,
    required this.pitch,
    required this.health,
    required this.flying,
  });

  final double x;
  final double y;
  final double z;
  final double yaw;
  final double pitch;
  final int health;
  final bool flying;
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
