import 'dart:ui' as ui;

import 'package:flame_3d/resources.dart';
import 'package:flutcraft_atlas/flutcraft_atlas.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';

/// The atlas as the renderer needs it: the generated pixels plus the GPU
/// texture built from them, once.
///
/// This is the only place where atlas bytes meet flame_3d, which is what
/// lets [TextureAtlas] itself stay pure Dart and be tested byte for byte.
class EngineAtlas {
  EngineAtlas(this.atlas)
    : texture = Texture(
        atlas.pixels.buffer.asByteData(),
        width: atlas.width,
        height: atlas.height,
        format: ui.PixelFormat.rgba8888,
      );

  final TextureAtlas atlas;
  final Texture texture;

  TileUv uv(Tile tile, Shade shade) => atlas.uv(tile, shade);
}
