import 'dart:math' as math;

import '../blocks/block_type.dart';
import 'voxel_world.dart';

/// Generator terenu: szum wartościowy (value noise) + kilka warstw i drzewa.
///
/// Wszystko jest deterministyczne względem [seed], więc ten sam seed
/// daje ten sam świat.
class TerrainGenerator {
  TerrainGenerator({this.seed = 1337});

  final int seed;

  /// Poziom, poniżej którego powierzchnia jest piaszczysta.
  static const int beachLevel = 15;

  void generate(VoxelWorld world) {
    final heights = List<int>.filled(world.sizeX * world.sizeZ, 0);

    for (var z = 0; z < world.sizeZ; z++) {
      for (var x = 0; x < world.sizeX; x++) {
        final base = 14 + _fbm(x / 34.0, z / 34.0, 4, 1) * 16;
        final hills = _fbm(x / 11.0, z / 11.0, 3, 2) * 4;
        final h = (base + hills).round().clamp(2, world.sizeY - 12);
        heights[z * world.sizeX + x] = h;
        _column(world, x, z, h);
      }
    }

    _plantTrees(world, heights);
  }

  void _column(VoxelWorld world, int x, int z, int height) {
    final sandy = height <= beachLevel;

    for (var y = 0; y <= height; y++) {
      final BlockType block;
      if (y == 0) {
        block = BlockType.bedrock;
      } else if (y == height) {
        block = sandy ? BlockType.sand : BlockType.grass;
      } else if (y > height - 4) {
        block = sandy ? BlockType.sand : BlockType.dirt;
      } else {
        block = _stoneAt(x, y, z);
      }
      world.setRaw(x, y, z, block);
    }
  }

  /// Kamień z wtrąceniami rud i żwiru.
  BlockType _stoneAt(int x, int y, int z) {
    if (y < 24 && _value3(x / 5.5, y / 5.5, z / 5.5, 31) > 0.82) {
      return BlockType.coalOre;
    }
    if (y < 18 && _value3(x / 4.5, y / 4.5, z / 4.5, 57) > 0.86) {
      return BlockType.ironOre;
    }
    if (_value3(x / 7.0, y / 7.0, z / 7.0, 91) > 0.85) {
      return BlockType.gravel;
    }
    return BlockType.stone;
  }

  void _plantTrees(VoxelWorld world, List<int> heights) {
    for (var z = 3; z < world.sizeZ - 3; z++) {
      for (var x = 3; x < world.sizeX - 3; x++) {
        final h = heights[z * world.sizeX + x];
        if (h <= beachLevel || h > world.sizeY - 10) continue;
        if (world.blockAt(x, h, z) != BlockType.grass) continue;
        // Rzadki, deterministyczny rozsiew - ~1 drzewo na 110 kratek.
        if (_hash(x, z, seed + 3) % 110 != 0) continue;
        if (_tooCloseToTree(world, x, h, z)) continue;

        final trunk = 4 + _hash(x, z, seed + 9) % 3;
        for (var i = 1; i <= trunk; i++) {
          world.setRaw(x, h + i, z, BlockType.log);
        }
        _canopy(world, x, h + trunk, z);
      }
    }
  }

  bool _tooCloseToTree(VoxelWorld world, int x, int h, int z) {
    for (var dz = -2; dz <= 2; dz++) {
      for (var dx = -2; dx <= 2; dx++) {
        for (var dy = 1; dy <= 6; dy++) {
          if (world.blockAt(x + dx, h + dy, z + dz) == BlockType.log) {
            return true;
          }
        }
      }
    }
    return false;
  }

  void _canopy(VoxelWorld world, int x, int topY, int z) {
    for (var dy = -2; dy <= 1; dy++) {
      final radius = dy >= 1 ? 1 : 2;
      for (var dz = -radius; dz <= radius; dz++) {
        for (var dx = -radius; dx <= radius; dx++) {
          // Ścinamy rogi, żeby korona nie była sześcianem.
          if (dx.abs() == radius &&
              dz.abs() == radius &&
              _hash(x + dx, z + dz, seed + 17) % 2 == 0) {
            continue;
          }
          final y = topY + dy;
          if (world.blockAt(x + dx, y, z + dz) == BlockType.air) {
            world.setRaw(x + dx, y, z + dz, BlockType.leaves);
          }
        }
      }
    }
  }

  // --- szum ------------------------------------------------------------------

  int _hash(int x, int y, int salt) {
    var h =
        (x * 374761393 + y * 668265263 + (seed + salt) * 2246822519) &
        0xFFFFFFFF;
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF;
    return (h ^ (h >> 16)) & 0xFFFFFFFF;
  }

  double _rand(int x, int y, int salt) => (_hash(x, y, salt) % 4096) / 4095.0;

  double _rand3(int x, int y, int z, int salt) =>
      (_hash(x * 31 + z, y * 17 + z * 7, salt) % 4096) / 4095.0;

  static double _smooth(double t) => t * t * (3 - 2 * t);

  double _value2(double x, double z, int salt) {
    final x0 = x.floor();
    final z0 = z.floor();
    final fx = _smooth(x - x0);
    final fz = _smooth(z - z0);

    final n00 = _rand(x0, z0, salt);
    final n10 = _rand(x0 + 1, z0, salt);
    final n01 = _rand(x0, z0 + 1, salt);
    final n11 = _rand(x0 + 1, z0 + 1, salt);

    final a = n00 + (n10 - n00) * fx;
    final b = n01 + (n11 - n01) * fx;
    return a + (b - a) * fz;
  }

  double _value3(double x, double y, double z, int salt) {
    final x0 = x.floor();
    final y0 = y.floor();
    final z0 = z.floor();
    final fx = _smooth(x - x0);
    final fy = _smooth(y - y0);
    final fz = _smooth(z - z0);

    double corner(int dx, int dy, int dz) =>
        _rand3(x0 + dx, y0 + dy, z0 + dz, salt);

    double lerp(double a, double b, double t) => a + (b - a) * t;

    final c00 = lerp(corner(0, 0, 0), corner(1, 0, 0), fx);
    final c10 = lerp(corner(0, 1, 0), corner(1, 1, 0), fx);
    final c01 = lerp(corner(0, 0, 1), corner(1, 0, 1), fx);
    final c11 = lerp(corner(0, 1, 1), corner(1, 1, 1), fx);

    return lerp(lerp(c00, c10, fy), lerp(c01, c11, fy), fz);
  }

  /// Fractal Brownian motion - kilka oktaw szumu o malejącej amplitudzie.
  double _fbm(double x, double z, int octaves, int salt) {
    var amplitude = 1.0;
    var frequency = 1.0;
    var sum = 0.0;
    var norm = 0.0;
    for (var i = 0; i < octaves; i++) {
      sum += _value2(x * frequency, z * frequency, salt + i * 13) * amplitude;
      norm += amplitude;
      amplitude *= 0.5;
      frequency *= 2.0;
    }
    return math.max(0, sum / norm);
  }
}
