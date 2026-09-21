import '../blocks/block_pos.dart';
import 'furnace_state.dart';

/// Every furnace placed in the world, keyed by its position.
///
/// Keying by [BlockPos] rather than by a packed integer means the world's
/// internal array layout can change without quietly relocating every
/// furnace in an existing world.
class FurnaceRegistry {
  final Map<BlockPos, FurnaceState> _furnaces = {};

  bool get isEmpty => _furnaces.isEmpty;

  int get length => _furnaces.length;

  Iterable<MapEntry<BlockPos, FurnaceState>> get entries => _furnaces.entries;

  FurnaceState? operator [](BlockPos pos) => _furnaces[pos];

  /// The furnace at [pos], creating an empty one if there is none yet.
  FurnaceState open(BlockPos pos) =>
      _furnaces.putIfAbsent(pos, FurnaceState.new);

  /// Removes the furnace at [pos] and returns it, or `null` if empty.
  FurnaceState? remove(BlockPos pos) => _furnaces.remove(pos);

  /// Advances every furnace and reports those whose lit state flipped, so the
  /// caller can swap the block texture without polling each one.
  List<BlockPos> tick(double dt) {
    final toggled = <BlockPos>[];
    for (final entry in _furnaces.entries) {
      final wasLit = entry.value.isLit;
      entry.value.tick(dt);
      if (entry.value.isLit != wasLit) toggled.add(entry.key);
    }
    return toggled;
  }

  void clear() => _furnaces.clear();
}
