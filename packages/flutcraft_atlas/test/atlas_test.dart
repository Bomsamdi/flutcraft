import 'package:flutcraft_atlas/flutcraft_atlas.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';

/// A cheap checksum over the whole atlas.
///
/// Stands in for a golden image: it is a single number, it needs no files and
/// no GPU, and it changes the moment a single pixel does.
int checksum(List<int> bytes) {
  var hash = 17;
  for (final byte in bytes) {
    hash = (hash * 31 + byte) & 0x7FFFFFFF;
  }
  return hash;
}

void main() {
  final atlas = TextureAtlas.generate();

  group('Layout', () {
    test('one column per tile, one row per shade', () {
      expect(atlas.width, Tile.values.length * TextureAtlas.tilePx);
      expect(atlas.height, Shade.values.length * TextureAtlas.tilePx);
      expect(atlas.pixels, hasLength(atlas.width * atlas.height * 4));
    });

    test('every tile has a rectangle in every shade', () {
      for (final tile in Tile.values) {
        for (final shade in Shade.values) {
          final uv = atlas.uv(tile, shade);
          expect(uv.u0, lessThan(uv.u1), reason: '${tile.name}/${shade.name}');
          expect(uv.v0, lessThan(uv.v1), reason: '${tile.name}/${shade.name}');
          expect(uv.u0, inInclusiveRange(0, 1));
          expect(uv.v1, inInclusiveRange(0, 1));
        }
      }
    });

    test('rectangles sit inside their own tile, never on the neighbour', () {
      final step = TextureAtlas.tilePx / atlas.width;

      for (var i = 0; i < Tile.values.length; i++) {
        final uv = atlas.uv(Tile.values[i], Shade.top);
        expect(uv.u0, greaterThan(i * step));
        expect(uv.u1, lessThan((i + 1) * step));
      }
    });
  });

  group('Pixels', () {
    test('painting is deterministic', () {
      expect(checksum(TextureAtlas.generate().pixels), checksum(atlas.pixels));
    });

    test('a tile does not depend on the ones painted before it', () {
      // Painted alone, out of order, the tile must come out identical.
      expect(paintTile(Tile.stone), paintTile(Tile.stone));
      expect(
        checksum(paintTile(Tile.logSide)),
        isNot(checksum(paintTile(Tile.stone))),
      );
    });

    test('every tile is painted — none is left blank', () {
      for (final tile in Tile.values) {
        final pixels = paintTile(tile);
        final opaque = pixels.where((argb) => (argb >> 24) & 0xFF > 0);

        expect(opaque, isNotEmpty, reason: tile.name);
      }
    });

    test('shading darkens, never brightens', () {
      final top = _averageBrightness(atlas, Tile.grassTop, Shade.top);
      final sideZ = _averageBrightness(atlas, Tile.grassTop, Shade.sideZ);
      final sideX = _averageBrightness(atlas, Tile.grassTop, Shade.sideX);
      final bottom = _averageBrightness(atlas, Tile.grassTop, Shade.bottom);

      expect(sideZ, lessThan(top));
      expect(sideX, lessThan(sideZ));
      expect(bottom, lessThan(sideX));
    });
  });
}

double _averageBrightness(TextureAtlas atlas, Tile tile, Shade shade) {
  final x0 = tile.index * TextureAtlas.tilePx;
  final y0 = shade.index * TextureAtlas.tilePx;
  var total = 0;

  for (var y = 0; y < TextureAtlas.tilePx; y++) {
    for (var x = 0; x < TextureAtlas.tilePx; x++) {
      final o = ((y0 + y) * atlas.width + x0 + x) * 4;
      total += atlas.pixels[o] + atlas.pixels[o + 1] + atlas.pixels[o + 2];
    }
  }
  return total / (TextureAtlas.tilePx * TextureAtlas.tilePx * 3);
}
