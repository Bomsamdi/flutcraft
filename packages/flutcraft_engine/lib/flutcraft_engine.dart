/// The renderer and the Flame game that drives it.
///
/// Depends on the domain and the atlas, never on the interface or the
/// translations: the engine draws the world and emits events, it does not
/// decide what the player is told.
library;

export 'src/game/flutcraft_game.dart';
export 'src/game/held_item.dart';
export 'src/render/atlas_texture.dart';
export 'src/render/chunk_renderer.dart';
export 'src/render/mesh_builder.dart';
export 'src/render/mob_renderer.dart';
export 'src/render/overlay_meshes.dart';
