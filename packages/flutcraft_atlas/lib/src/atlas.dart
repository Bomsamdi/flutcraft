import 'dart:typed_data';

import 'package:flutcraft_domain/flutcraft_domain.dart';

import 'tile_painter.dart';
import 'tile_uv.dart';

/// A texture atlas generated at startup — the prototype loads no assets from
/// disk at all.
///
/// Layout: one column per [Tile], one row per [Shade]. Face shading is baked
/// into the pixels, so the whole world renders with a single unlit material
/// and no lighting pass.
class TextureAtlas {
  TextureAtlas._(this.pixels, this.width, this.height, this._uv);

  /// Side of a single tile, in pixels.
  static const int tilePx = tilePixels;

  /// RGBA, row-major, [width] * [height] * 4 bytes.
  final Uint8List pixels;

  final int width;
  final int height;
  final List<List<TileUv>> _uv;

  TileUv uv(Tile tile, Shade shade) => _uv[tile.index][shade.index];

  factory TextureAtlas.generate() {
    final tiles = Tile.values;
    final shades = Shade.values;
    final width = tiles.length * tilePx;
    final height = shades.length * tilePx;
    final pixels = Uint8List(width * height * 4);

    for (var t = 0; t < tiles.length; t++) {
      final base = paintTile(tiles[t]);
      for (var s = 0; s < shades.length; s++) {
        final factor = shades[s].factor;
        for (var py = 0; py < tilePx; py++) {
          for (var px = 0; px < tilePx; px++) {
            final argb = base[py * tilePx + px];
            final alpha = (argb >> 24) & 0xFF;
            final o = (((s * tilePx + py) * width) + (t * tilePx + px)) * 4;
            pixels[o] = (((argb >> 16) & 0xFF) * factor).round();
            pixels[o + 1] = (((argb >> 8) & 0xFF) * factor).round();
            pixels[o + 2] = ((argb & 0xFF) * factor).round();
            pixels[o + 3] = alpha;
          }
        }
      }
    }

    // Half a texel of inset: with nearest sampling it keeps the corners of a
    // triangle from landing on the neighbouring tile.
    const inset = 0.5;
    final uv = [
      for (var t = 0; t < tiles.length; t++)
        [
          for (var s = 0; s < shades.length; s++)
            TileUv(
              (t * tilePx + inset) / width,
              (s * tilePx + inset) / height,
              ((t + 1) * tilePx - inset) / width,
              ((s + 1) * tilePx - inset) / height,
            ),
        ],
    ];

    return TextureAtlas._(pixels, width, height, uv);
  }
}
