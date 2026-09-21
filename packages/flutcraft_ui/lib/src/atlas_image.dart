import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutcraft_atlas/flutcraft_atlas.dart';

/// Decodes the generated atlas into an image the HUD can draw from.
///
/// The atlas itself is plain bytes, which is what keeps that package free of
/// Flutter; turning those bytes into a `ui.Image` is a Flutter concern and
/// therefore lives here.
Future<ui.Image> decodeAtlasImage(TextureAtlas atlas) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    atlas.pixels,
    atlas.width,
    atlas.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
