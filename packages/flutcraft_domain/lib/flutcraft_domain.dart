/// Pure Dart core of Flutcraft.
///
/// This package deliberately depends on neither Flutter nor Flame. Everything
/// here is plain Dart, which means the entire simulation runs under
/// `dart test` in milliseconds and cannot accidentally reach for a
/// `BuildContext` or a GPU resource.
library;

export 'src/actors/entity_id.dart';
export 'src/actors/mob.dart';
export 'src/actors/mob_behavior.dart';
export 'src/actors/player.dart';
export 'src/actors/player_id.dart';
export 'src/aiming/aim_result.dart';
export 'src/aiming/target_picker.dart';
export 'src/blocks/block_interaction.dart';
export 'src/blocks/block_pos.dart';
export 'src/blocks/block_type.dart';
export 'src/blocks/tile.dart';
export 'src/crafting/recipes.dart';
export 'src/diagnostics/frame_stats.dart';
export 'src/input/action_commands.dart';
export 'src/input/game_action.dart';
export 'src/input/input_frame.dart';
export 'src/input/input_router.dart';
export 'src/input/keymap.dart';
export 'src/inventory/inventory.dart';
export 'src/inventory/slot_container.dart';
export 'src/items/item_type.dart';
export 'src/loot/block_loot.dart';
export 'src/loot/loot_table.dart';
export 'src/machines/furnace_registry.dart';
export 'src/machines/furnace_state.dart';
export 'src/physics/voxel_body.dart';
export 'src/save/game_persistence.dart';
export 'src/save/save_codec.dart';
export 'src/save/save_data.dart';
export 'src/save/save_repository.dart';
export 'src/save/save_sink.dart';
export 'src/session/addressed_event.dart';
export 'src/session/game_command.dart';
export 'src/session/game_event.dart';
export 'src/session/game_loop.dart';
export 'src/session/game_session.dart';
export 'src/session/game_snapshot.dart';
export 'src/session/game_state.dart';
export 'src/session/loop_game_session.dart';
export 'src/session/systems/aiming_system.dart';
export 'src/session/systems/autosave_system.dart';
export 'src/session/systems/entity_separation_system.dart';
export 'src/session/systems/explosion_system.dart';
export 'src/session/systems/furnace_system.dart';
export 'src/session/systems/mining_system.dart';
export 'src/session/systems/mob_ai_system.dart';
export 'src/session/systems/placement_system.dart';
export 'src/session/systems/player_movement_system.dart';
export 'src/session/systems/projectile_system.dart';
export 'src/session/participant.dart';
export 'src/session/simulated_session.dart';
export 'src/session/tick_clock.dart';
export 'src/session/ui_route.dart';
export 'src/session/world_systems.dart';
export 'src/world/terrain_generator.dart';
export 'src/world/voxel_world.dart';
