/// Pure Dart core of Flutcraft.
///
/// This package deliberately depends on neither Flutter nor Flame. Everything
/// here is plain Dart, which means the entire simulation runs under
/// `dart test` in milliseconds and cannot accidentally reach for a
/// `BuildContext` or a GPU resource.
library;

export 'src/actors/mob.dart';
export 'src/actors/player.dart';
export 'src/aiming/aim_result.dart';
export 'src/aiming/target_picker.dart';
export 'src/blocks/block_pos.dart';
export 'src/blocks/block_type.dart';
export 'src/blocks/tile.dart';
export 'src/crafting/recipes.dart';
export 'src/inventory/inventory.dart';
export 'src/items/item_type.dart';
export 'src/loot/block_loot.dart';
export 'src/loot/loot_table.dart';
export 'src/machines/furnace_registry.dart';
export 'src/machines/furnace_state.dart';
export 'src/physics/voxel_body.dart';
export 'src/world/terrain_generator.dart';
export 'src/world/voxel_world.dart';
