import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';
import '../blocks/block_pos.dart';
import '../blocks/block_type.dart';

/// A ray hitting a block.
class RayHit {
  const RayHit({
    required this.x,
    required this.y,
    required this.z,
    required this.block,
    required this.nx,
    required this.ny,
    required this.nz,
    required this.distance,
  });

  final int x;
  final int y;
  final int z;
  final BlockType block;

  /// The normal of the face that was hit: where a new block would go.
  final int nx;
  final int ny;
  final int nz;

  final double distance;

  /// The cell a block placed on that face would occupy.
  (int, int, int) get placement => (x + nx, y + ny, z + nz);

  /// The position of the block that was hit.
  BlockPos get pos => BlockPos(x, y, z);

  /// Whether both hits are on the same block, face aside.
  bool samePosition(RayHit other) =>
      other.x == x && other.y == y && other.z == z;
}

/// The voxel grid, kept in one contiguous byte array.
///
/// The world is finite — no chunk streaming from disk — because this is a
/// prototype: the whole map fits in memory and is generated once at start.
class VoxelWorld {
  VoxelWorld({this.sizeX = 128, this.sizeY = 48, this.sizeZ = 128})
    : _blocks = Uint8List(sizeX * sizeY * sizeZ);

  final int sizeX;
  final int sizeY;
  final int sizeZ;
  final Uint8List _blocks;

  final Map<BlockPos, BlockType> _changed = {};

  /// Blocks changed since the last [drainChanges], and what was there before.
  ///
  /// The renderer already tracks whole chunks, because that is the unit it
  /// rebuilds. A server needs the blocks themselves: a chunk is 16x48x16 and
  /// nobody wants to send it down a wire because one torch moved.
  ///
  /// The *previous* block is kept rather than the new one, which is already
  /// in the world. It is what a client needs to undo a placement the server
  /// turns out not to have agreed with.
  Map<BlockPos, BlockType> get changedBlocks => Map.unmodifiable(_changed);

  /// Takes the accumulated block changes and starts a new batch.
  Map<BlockPos, BlockType> drainChanges() {
    if (_changed.isEmpty) return const {};
    final taken = Map<BlockPos, BlockType>.of(_changed);
    _changed.clear();
    return taken;
  }

  /// Chunks whose mesh needs rebuilding.
  final Set<int> dirtyChunks = <int>{};

  /// Which seed produced this terrain.
  ///
  /// Stored here because it is a property of *this* world: the save keeps it
  /// instead of the block array and regenerates the terrain on load.
  int seed = 0;

  /// Blocks that differ from the generated terrain.
  ///
  /// A save keeps the seed and this map instead of 786,432 bytes of array:
  /// the terrain is deterministic and can be regenerated, and there are
  /// usually only a few hundred edits.
  final Map<BlockPos, BlockType> edits = {};

  static const int chunkSize = 16;

  int get chunksX => (sizeX / chunkSize).ceil();
  int get chunksZ => (sizeZ / chunkSize).ceil();

  int _index(int x, int y, int z) => (y * sizeZ + z) * sizeX + x;

  bool inBounds(int x, int y, int z) =>
      x >= 0 && x < sizeX && y >= 0 && y < sizeY && z >= 0 && z < sizeZ;

  BlockType blockAt(int x, int y, int z) {
    if (!inBounds(x, y, z)) return BlockType.air;
    return BlockType.byId[_blocks[_index(x, y, z)]];
  }

  bool isSolid(int x, int y, int z) => blockAt(x, y, z).solid;

  /// Writes without marking the chunk — only the terrain generator does this.
  void setRaw(int x, int y, int z, BlockType block) {
    if (!inBounds(x, y, z)) return;
    _blocks[_index(x, y, z)] = block.index;
  }

  /// A write during play: marks the chunk — and its neighbours on a border —
  /// for a mesh rebuild, and records the change for the save.
  void setBlock(int x, int y, int z, BlockType block) {
    if (!inBounds(x, y, z)) return;
    final previous = blockAt(x, y, z);
    _blocks[_index(x, y, z)] = block.index;
    final pos = BlockPos(x, y, z);
    // Remember what was here first, and only the first time: a cell written
    // twice in one batch still has exactly one thing to be put back to.
    _changed.putIfAbsent(pos, () => previous);
    edits[pos] = block;

    final cx = x ~/ chunkSize;
    final cz = z ~/ chunkSize;
    _markDirty(cx, cz);
    if (x % chunkSize == 0) _markDirty(cx - 1, cz);
    if (x % chunkSize == chunkSize - 1) _markDirty(cx + 1, cz);
    if (z % chunkSize == 0) _markDirty(cx, cz - 1);
    if (z % chunkSize == chunkSize - 1) _markDirty(cx, cz + 1);
  }

  void _markDirty(int cx, int cz) {
    if (cx < 0 || cz < 0 || cx >= chunksX || cz >= chunksZ) return;
    dirtyChunks.add(cz * chunksX + cx);
  }

  void markAllDirty() {
    for (var i = 0; i < chunksX * chunksZ; i++) {
      dirtyChunks.add(i);
    }
  }

  /// The highest non-empty block in a column, or -1 when it is empty.
  int surfaceHeight(int x, int z) {
    for (var y = sizeY - 1; y >= 0; y--) {
      if (blockAt(x, y, z).solid) return y;
    }
    return -1;
  }

  /// Walks a ray through the voxels (Amanatides & Woo).
  ///
  /// [dir] must be normalised. Returns the first solid block met.
  RayHit? raycast(Vector3 origin, Vector3 dir, double maxDistance) {
    var x = origin.x.floor();
    var y = origin.y.floor();
    var z = origin.z.floor();

    final stepX = dir.x > 0 ? 1 : -1;
    final stepY = dir.y > 0 ? 1 : -1;
    final stepZ = dir.z > 0 ? 1 : -1;

    const inf = double.infinity;
    final tDeltaX = dir.x == 0 ? inf : (1 / dir.x).abs();
    final tDeltaY = dir.y == 0 ? inf : (1 / dir.y).abs();
    final tDeltaZ = dir.z == 0 ? inf : (1 / dir.z).abs();

    var tMaxX = dir.x == 0
        ? inf
        : ((dir.x > 0 ? (x + 1 - origin.x) : (origin.x - x)) * tDeltaX);
    var tMaxY = dir.y == 0
        ? inf
        : ((dir.y > 0 ? (y + 1 - origin.y) : (origin.y - y)) * tDeltaY);
    var tMaxZ = dir.z == 0
        ? inf
        : ((dir.z > 0 ? (z + 1 - origin.z) : (origin.z - z)) * tDeltaZ);

    var nx = 0;
    var ny = 0;
    var nz = 0;
    var travelled = 0.0;

    // The player can only be inside a block by mistake, but the starting
    // cell is checked anyway so the ray cannot shoot through a wall.
    while (travelled <= maxDistance) {
      final block = blockAt(x, y, z);
      if (block.solid) {
        return RayHit(
          x: x,
          y: y,
          z: z,
          block: block,
          nx: nx,
          ny: ny,
          nz: nz,
          distance: travelled,
        );
      }

      if (tMaxX < tMaxY && tMaxX < tMaxZ) {
        travelled = tMaxX;
        x += stepX;
        tMaxX += tDeltaX;
        nx = -stepX;
        ny = 0;
        nz = 0;
      } else if (tMaxY < tMaxZ) {
        travelled = tMaxY;
        y += stepY;
        tMaxY += tDeltaY;
        nx = 0;
        ny = -stepY;
        nz = 0;
      } else {
        travelled = tMaxZ;
        z += stepZ;
        tMaxZ += tDeltaZ;
        nx = 0;
        ny = 0;
        nz = -stepZ;
      }

      // The ray left the world vertically; there is nothing further out.
      if (y < 0 || y >= sizeY) return null;
    }
    return null;
  }
}
