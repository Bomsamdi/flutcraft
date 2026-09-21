import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';
import '../blocks/block_pos.dart';
import '../blocks/block_type.dart';

/// Trafienie promienia w blok.
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

  /// Normalna trafionej ściany - wskazuje, gdzie postawić nowy blok.
  final int nx;
  final int ny;
  final int nz;

  final double distance;

  /// Pozycja bloku stawianego "na" trafionej ścianie.
  (int, int, int) get placement => (x + nx, y + ny, z + nz);

  /// Pozycja trafionego bloku.
  BlockPos get pos => BlockPos(x, y, z);

  /// Czy oba trafienia wskazują ten sam blok (ściana może być inna).
  bool samePosition(RayHit other) =>
      other.x == x && other.y == y && other.z == z;
}

/// Siatka wokseli trzymana w jednej ciągłej tablicy bajtów.
///
/// Świat jest skończony (bez streamingu chunków z dysku) - to prototyp,
/// więc cała mapa mieści się w pamięci i generuje się raz na starcie.
class VoxelWorld {
  VoxelWorld({
    this.sizeX = 128,
    this.sizeY = 48,
    this.sizeZ = 128,
  }) : _blocks = Uint8List(sizeX * sizeY * sizeZ);

  final int sizeX;
  final int sizeY;
  final int sizeZ;
  final Uint8List _blocks;

  /// Chunki, które wymagają przebudowy siatki.
  final Set<int> dirtyChunks = <int>{};

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

  /// Zapis bez oznaczania chunku - używane tylko przez generator terenu.
  void setRaw(int x, int y, int z, BlockType block) {
    if (!inBounds(x, y, z)) return;
    _blocks[_index(x, y, z)] = block.index;
  }

  /// Zapis w trakcie gry: oznacza chunk (i sąsiadów na granicy) do
  /// przebudowy siatki.
  void setBlock(int x, int y, int z, BlockType block) {
    if (!inBounds(x, y, z)) return;
    _blocks[_index(x, y, z)] = block.index;

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

  /// Najwyższy niepusty blok w kolumnie (-1 jeśli kolumna jest pusta).
  int surfaceHeight(int x, int z) {
    for (var y = sizeY - 1; y >= 0; y--) {
      if (blockAt(x, y, z).solid) return y;
    }
    return -1;
  }

  /// Przejście promienia po wokselach (Amanatides & Woo).
  ///
  /// [dir] musi być znormalizowany. Zwraca pierwszy napotkany blok stały.
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

    // Gracz może stać wewnątrz bloku tylko w razie błędu - i tak sprawdzamy
    // komórkę startową, żeby nie przebić promieniem ściany.
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

      // Promień opuścił świat w pionie - dalej nic nie będzie.
      if (y < 0 || y >= sizeY) return null;
    }
    return null;
  }
}
