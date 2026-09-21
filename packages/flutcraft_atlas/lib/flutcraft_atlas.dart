/// The procedural texture atlas.
///
/// Pure Dart on purpose: painting tiles is a function from a [Tile] to
/// pixels, and a function that touches no GPU can be tested by comparing
/// bytes.
library;

export 'src/atlas.dart';
export 'src/tile_painter.dart';
export 'src/tile_uv.dart';
