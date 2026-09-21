import 'dart:math' as math;

import 'package:flutcraft_domain/flutcraft_domain.dart';

/// Paints one tile as ARGB pixels, [tilePixels] by [tilePixels].
///
/// A pure function of the tile: same input, same bytes, every run on every
/// platform. That is what makes a golden test on the atlas possible at all.
List<int> paintTile(Tile tile) => _paintTile(tile);

/// Side of a single tile, in pixels.
const int tilePixels = 16;

// --- pixel generation --------------------------------------------------------

int _hash(int x, int y, int salt) {
  var h = (x * 374761393 + y * 668265263 + salt * 2246822519) & 0xFFFFFFFF;
  h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF;
  return (h ^ (h >> 16)) & 0xFFFFFFFF;
}

/// Deterministyczny szum 0..1.
double _noise(int x, int y, int salt) => (_hash(x, y, salt) % 1024) / 1023.0;

/// Colours are 0xAARRGGBB; an alpha of 0 means the pixel is skipped, which
/// is how item icons get their transparent background.
int _rgb(int r, int g, int b) =>
    0xFF000000 |
    (r.clamp(0, 255) << 16) |
    (g.clamp(0, 255) << 8) |
    b.clamp(0, 255);

const int _clear = 0x00000000;

/// Lightens or darkens a colour by [delta], in 0..255 units.
int _vary(int color, double delta) {
  return _rgb(
    ((color >> 16) & 0xFF) + delta.round(),
    ((color >> 8) & 0xFF) + delta.round(),
    (color & 0xFF) + delta.round(),
  );
}

int _mix(int a, int b, double t) {
  return _rgb(
    (((a >> 16) & 0xFF) * (1 - t) + ((b >> 16) & 0xFF) * t).round(),
    (((a >> 8) & 0xFF) * (1 - t) + ((b >> 8) & 0xFF) * t).round(),
    ((a & 0xFF) * (1 - t) + (b & 0xFF) * t).round(),
  );
}

const _kDirt = 0x8B6644;
const _kGrass = 0x5D9B3B;
const _kStone = 0x8C8C8C;
const _kSand = 0xDCD2A0;
const _kGravel = 0x9B9490;
const _kLogSide = 0x6A5132;
const _kLogTop = 0xA07F4E;
const _kLeaves = 0x3F7E2C;
const _kPlanks = 0xB08A5C;
const _kBedrock = 0x585858;
const _kBrick = 0xA24A36;
const _kMortar = 0xB9B3A8;
const _kMetal = 0xB9BDC4;
const _kHandle = 0x8A6A3F;
const _kCoal = 0x22232A;
const _kRawIron = 0xC08A5E;
const _kIronIngot = 0xD6D6DC;
const _kBone = 0xE7E4D6;
const _kString = 0xE4E4E4;
const _kPowder = 0x9A9A9A;
const _kZombie = 0x4C8B49;
const _kSkeleton = 0xC9C9C2;
const _kPlayerShirt = 0x2F6DB5;
const _kPlayerFace = 0xC98E63;
const _kSpider = 0x3A2C26;
const _kCreeper = 0x5AAE4B;
const _kFire = 0xF08A20;

const int _n = tilePixels;

List<int> _paintTile(Tile tile) {
  final out = List<int>.filled(_n * _n, 0);
  for (var y = 0; y < _n; y++) {
    for (var x = 0; x < _n; x++) {
      out[y * _n + x] = _pixel(tile, x, y);
    }
  }
  return out;
}

int _pixel(Tile tile, int x, int y) {
  final salt = tile.index + 1;
  final n = _noise(x, y, salt);

  switch (tile) {
    case Tile.grassTop:
      final c = _vary(_kGrass, (n - 0.5) * 26);
      return n > 0.93 ? _vary(c, 18) : c;

    case Tile.grassSide:
      // A ragged grass line: the height of the green cap varies per column.
      final cap = 3 + _hash(x, 0, salt) % 3;
      if (y < cap) {
        return _vary(_kGrass, (n - 0.5) * 24);
      }
      if (y == cap) {
        return _mix(_kGrass, _kDirt, 0.45);
      }
      return _vary(_kDirt, (n - 0.5) * 26);

    case Tile.dirt:
      return _vary(_kDirt, (n - 0.5) * 28);

    case Tile.stone:
      return _vary(_kStone, (n - 0.5) * 24);

    case Tile.cobblestone:
      return _cobble(x, y, salt, _kStone);

    case Tile.sand:
      return _vary(_kSand, (n - 0.5) * 18);

    case Tile.gravel:
      final c = _vary(_kGravel, (n - 0.5) * 34);
      return n < 0.14 ? _vary(c, -30) : c;

    case Tile.logSide:
      // Vertical grain in the bark.
      final grain = _noise(x, y ~/ 4, salt) - 0.5;
      final streak = (x % 5 == 2 || x % 7 == 5) ? -14.0 : 0.0;
      return _vary(_kLogSide, grain * 22 + streak);

    case Tile.logTop:
      final dx = x - 7.5;
      final dy = y - 7.5;
      final d = math.sqrt(dx * dx + dy * dy);
      final ring = ((d * 1.7).floor() % 2 == 0) ? 10.0 : -12.0;
      if (d < 1.6) return _vary(_kLogSide, 6);
      return _vary(_kLogTop, ring + (n - 0.5) * 12);

    case Tile.leaves:
      if (n < 0.16) return _vary(_kLeaves, -34);
      if (n > 0.88) return _vary(_kLeaves, 22);
      return _vary(_kLeaves, (n - 0.5) * 26);

    case Tile.planks:
      final plank = y ~/ 4;
      if (y % 4 == 0) return _vary(_kPlanks, -34);
      final grain = _noise(x, plank, salt) - 0.5;
      final tint = (_hash(0, plank, salt) % 13) - 6.0;
      return _vary(_kPlanks, grain * 16 + tint);

    case Tile.bedrock:
      final blocky = _noise(x ~/ 2, y ~/ 2, salt);
      return _vary(_kBedrock, (blocky - 0.5) * 70);

    case Tile.coalOre:
      final base = _vary(_kStone, (n - 0.5) * 20);
      return _oreBlob(x, y, salt) ? _vary(0x1E1E1E, (n - 0.5) * 18) : base;

    case Tile.ironOre:
      final base = _vary(_kStone, (n - 0.5) * 20);
      return _oreBlob(x, y, salt) ? _vary(0xC79A6E, (n - 0.5) * 18) : base;

    case Tile.brick:
      final row = y ~/ 4;
      final offset = row.isEven ? 0 : 4;
      if (y % 4 == 0 || (x + offset) % 8 == 0) {
        return _vary(_kMortar, (n - 0.5) * 12);
      }
      return _vary(_kBrick, (n - 0.5) * 22);

    case Tile.craftingTableTop:
      // Planks with a 3x3 grid drawn on them.
      if (x % 5 == 0 || y % 5 == 0 || x == 15 || y == 15) {
        return _vary(_kPlanks, -40);
      }
      return _vary(_kPlanks, (n - 0.5) * 18);

    case Tile.craftingTableSide:
      if (y < 4) return _vary(_kPlanks, -10 + (n - 0.5) * 14);
      if (y == 4) return _vary(_kPlanks, -38);
      // Tools hanging off the side of the table.
      if (_onLine(x, y, 4, 13, 7, 8, 1.0)) return _vary(_kHandle, 0);
      if (_onLine(x, y, 10, 13, 12, 7, 1.0)) return _vary(_kMetal, -20);
      return _vary(_kPlanks, (n - 0.5) * 20);

    case Tile.furnaceTop:
      if ((x - 7.5) * (x - 7.5) + (y - 7.5) * (y - 7.5) < 9) {
        return _vary(_kStone, -46);
      }
      return _cobble(x, y, salt, _kStone);

    case Tile.furnaceSide:
      return _cobble(x, y, salt, _kStone);

    case Tile.furnaceFront:
    case Tile.furnaceFrontLit:
      // The firebox; in the lit variant flames come out of it.
      if (x >= 3 && x <= 12 && y >= 6 && y <= 13) {
        if (tile == Tile.furnaceFrontLit && y >= 8) {
          final flicker = _noise(x, y, salt) * 60;
          return _vary(_kFire, flicker - 20);
        }
        return _vary(0x2A2A2A, (n - 0.5) * 14);
      }
      return _cobble(x, y, salt, _kStone);

    case Tile.metal:
      // A light edge along the top and left reads as a bevelled lump.
      final edge = (x == 0 || y == 0)
          ? 16.0
          : (x == _n - 1 || y == _n - 1)
          ? -22.0
          : 0.0;
      return _vary(_kMetal, edge + (n - 0.5) * 14);

    case Tile.handle:
      final grain = _noise(x, y ~/ 3, salt) - 0.5;
      return _vary(_kHandle, grain * 20 + (x % 4 == 0 ? -10 : 0));

    case Tile.stickIcon:
      if (_onLine(x, y, 4, 12, 11, 4, 1.1)) {
        return _vary(_kHandle, (n - 0.5) * 22);
      }
      return _clear;

    case Tile.coalIcon:
      return _nugget(x, y, _kCoal, salt);

    case Tile.rawIronIcon:
      return _nugget(x, y, _kRawIron, salt);

    case Tile.ironIngotIcon:
      // The ingot: a trapezium with a lighter top edge.
      if (y < 5 || y > 11) return _clear;
      final inset = y < 7 ? 4 : 2;
      if (x < inset || x > 15 - inset) return _clear;
      return _vary(_kIronIngot, y < 7 ? 12 : (n - 0.5) * 16);

    case Tile.boneIcon:
      if (_onLine(x, y, 4, 11, 11, 4, 1.2)) return _vary(_kBone, 0);
      // Thicker at both ends.
      for (final (cx, cy) in const [(3, 12), (5, 10), (10, 5), (12, 3)]) {
        final dx = x - cx;
        final dy = y - cy;
        if (dx * dx + dy * dy <= 2.6) return _vary(_kBone, 8);
      }
      return _clear;

    case Tile.stringIcon:
      if (_onLine(x, y, 3, 4, 8, 8, 0.9) ||
          _onLine(x, y, 8, 8, 4, 11, 0.9) ||
          _onLine(x, y, 4, 11, 12, 13, 0.9)) {
        return _vary(_kString, (n - 0.5) * 16);
      }
      return _clear;

    case Tile.gunpowderIcon:
      if (_oreBlob(x, y, salt)) return _vary(_kPowder, (n - 0.5) * 40);
      return _clear;

    case Tile.arrowIcon:
      if (_onLine(x, y, 3, 12, 12, 3, 0.9)) return _vary(_kHandle, 0);
      // Grot.
      if (_onLine(x, y, 10, 5, 13, 2, 1.4)) return _vary(_kIronIngot, 0);
      // Lotki.
      if (_onLine(x, y, 2, 13, 6, 12, 0.9) ||
          _onLine(x, y, 3, 10, 4, 14, 0.9)) {
        return _vary(_kBone, -10);
      }
      return _clear;

    case Tile.woodPickIcon:
      return _pickaxeIcon(x, y, _kPlanks, salt);
    case Tile.stonePickIcon:
      return _pickaxeIcon(x, y, _kStone, salt);
    case Tile.ironPickIcon:
      return _pickaxeIcon(x, y, _kIronIngot, salt);

    case Tile.woodSwordIcon:
      return _swordIcon(x, y, _kPlanks, salt);
    case Tile.stoneSwordIcon:
      return _swordIcon(x, y, _kStone, salt);
    case Tile.ironSwordIcon:
      return _swordIcon(x, y, _kIronIngot, salt);

    case Tile.zombieSkin:
      return _vary(_kZombie, (n - 0.5) * 22);

    case Tile.zombieFace:
      if (_eyes(x, y, 0x1B2B1B)) return 0xFF1B2B1B;
      if (y >= 11 && y <= 12 && x >= 5 && x <= 10) return 0xFF20301F;
      return _vary(_kZombie, (n - 0.5) * 18);

    case Tile.playerSkin:
      return _vary(_kPlayerShirt, (n - 0.5) * 20);

    case Tile.playerFace:
      if (_eyes(x, y, 0x2A2A38)) return 0xFF2A2A38;
      // A mouth, so the front of a person is obvious at a glance.
      if (y == 12 && x >= 6 && x <= 9) return 0xFF7A4A34;
      return _vary(_kPlayerFace, (n - 0.5) * 14);

    case Tile.skeletonSkin:
      return _vary(_kSkeleton, (n - 0.5) * 26);

    case Tile.skeletonFace:
      if (_eyes(x, y, 0x101010)) return 0xFF101010;
      if (y == 12 && x >= 5 && x <= 10) return 0xFF2A2A2A;
      return _vary(_kSkeleton, (n - 0.5) * 20);

    case Tile.spiderSkin:
      // Dark fur with lighter hairs through it.
      if (n > 0.9) return _vary(_kSpider, 34);
      return _vary(_kSpider, (n - 0.5) * 20);

    case Tile.spiderFace:
      for (final (cx, cy) in const [
        (4, 6),
        (7, 6),
        (9, 6),
        (12, 6),
        (5, 9),
        (11, 9),
      ]) {
        final dx = x - cx;
        final dy = y - cy;
        if (dx * dx + dy * dy <= 1.2) return 0xFFD02020;
      }
      return _vary(_kSpider, (n - 0.5) * 18);

    case Tile.creeperSkin:
      // The familiar mosaic of two greens.
      final patch = _noise(x ~/ 2, y ~/ 2, salt);
      return _vary(_kCreeper, (patch - 0.5) * 44);

    case Tile.creeperFace:
      if (_creeperMask(x, y)) return 0xFF10240F;
      final facePatch = _noise(x ~/ 2, y ~/ 2, salt);
      return _vary(_kCreeper, (facePatch - 0.5) * 40);
  }
}

/// A lump of raw material: an irregular blob with noise in it.
int _nugget(int x, int y, int color, int salt) {
  final dx = x - 7.5;
  final dy = y - 8.0;
  final wobble = _noise(x ~/ 3, y ~/ 3, salt) * 6;
  if (dx * dx + dy * dy > 22 + wobble) return _clear;
  return _vary(color, (_noise(x, y, salt) - 0.5) * 40);
}

/// The pair of rectangular eyes every mob face shares.
bool _eyes(int x, int y, int _) =>
    y >= 6 && y <= 8 && ((x >= 3 && x <= 5) || (x >= 10 && x <= 12));

/// Maska czarnej twarzy creepera.
bool _creeperMask(int x, int y) {
  if (y >= 4 && y <= 7 && ((x >= 3 && x <= 5) || (x >= 10 && x <= 12))) {
    return true;
  }
  if (y >= 8 && y <= 10 && x >= 6 && x <= 9) return true;
  if (y >= 11 && y <= 14 && ((x >= 4 && x <= 6) || (x >= 9 && x <= 11))) {
    return true;
  }
  return false;
}

/// Worley-lite: cobble cells with dark mortar along the borders.
int _cobble(int x, int y, int salt, int base) {
  var best = 1e9;
  var second = 1e9;
  var bestIndex = 0;
  for (var i = 0; i < 7; i++) {
    final sx = (_hash(i, 0, salt) % 16) + 0.5;
    final sy = (_hash(0, i, salt + 7) % 16) + 0.5;
    final dx = x + 0.5 - sx;
    final dy = y + 0.5 - sy;
    final d = dx * dx + dy * dy;
    if (d < best) {
      second = best;
      best = d;
      bestIndex = i;
    } else if (d < second) {
      second = d;
    }
  }
  if (math.sqrt(second) - math.sqrt(best) < 0.9) {
    return _vary(base, -42);
  }
  final tint = (_hash(bestIndex, bestIndex, salt) % 25) - 12.0;
  return _vary(base, tint + (_noise(x, y, salt) - 0.5) * 14);
}

/// Whether the pixel lies on the segment (x0,y0)-(x1,y1) of radius [r].
bool _onLine(
  int x,
  int y,
  double x0,
  double y0,
  double x1,
  double y1,
  double r,
) {
  final dx = x1 - x0;
  final dy = y1 - y0;
  final len2 = dx * dx + dy * dy;
  var t = len2 == 0 ? 0.0 : ((x - x0) * dx + (y - y0) * dy) / len2;
  t = t.clamp(0.0, 1.0);
  final px = x0 + dx * t - x;
  final py = y0 + dy * t - y;
  return px * px + py * py <= r * r;
}

/// A pickaxe icon: a diagonal handle and a curved head in the material's colour.
int _pickaxeIcon(int x, int y, int head, int salt) {
  if (_onLine(x, y, 4, 13, 9.5, 7, 1.1)) {
    return _vary(_kHandle, (_noise(x, y, salt) - 0.5) * 16);
  }
  final onHead =
      _onLine(x, y, 3, 6.5, 7.5, 3.5, 1.2) ||
      _onLine(x, y, 7.5, 3.5, 12, 6.5, 1.2);
  if (onHead) return _vary(head, (_noise(x, y, salt) - 0.5) * 18);
  return _clear;
}

/// A sword icon: grip, crossguard and blade.
int _swordIcon(int x, int y, int blade, int salt) {
  if (_onLine(x, y, 2, 13.5, 4.5, 11, 1.0)) return _vary(_kHandle, 0);
  if (_onLine(x, y, 2.5, 10, 6, 13.5, 1.0)) return _vary(0x6B6B6B, 0);
  if (_onLine(x, y, 4, 11, 13, 2, 1.3)) {
    return _vary(blade, (_noise(x, y, salt) - 0.5) * 16);
  }
  return _clear;
}

bool _oreBlob(int x, int y, int salt) {
  for (var i = 0; i < 4; i++) {
    final sx = (_hash(i, 3, salt) % 12) + 2;
    final sy = (_hash(3, i, salt + 11) % 12) + 2;
    final r = 1.4 + (_hash(i, i, salt) % 100) / 100.0;
    final dx = x - sx;
    final dy = y - sy;
    if (dx * dx + dy * dy <= r * r) return true;
  }
  return false;
}
