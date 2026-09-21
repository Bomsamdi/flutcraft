import 'package:vector_math/vector_math.dart';

import '../actors/player.dart';
import '../inventory/inventory.dart';
import '../session/game_state.dart';
import '../world/terrain_generator.dart';
import '../world/voxel_world.dart';
import 'save_data.dart';

/// Maps between live game state and the saved form.
///
/// Mobs, arrows, the crafting grid and the cursor are deliberately not saved:
/// grid and cursor contents go back to the inventory on save, exactly as they
/// do when the player closes a screen, so nothing can be lost by quitting.
class GamePersistence {
  const GamePersistence();

  SaveData capture(GameState state, {required int seed}) {
    _returnGridAndCursor(state);

    return SaveData(
      seed: seed,
      edits: Map.of(state.world.edits),
      player: SavedPlayer(
        x: state.player.position.x,
        y: state.player.position.y,
        z: state.player.position.z,
        yaw: state.player.yaw,
        pitch: state.player.pitch,
        health: state.player.health,
        flying: state.player.flying,
      ),
      inventory: List.of(state.inventory.slots),
      selectedSlot: state.selectedSlot,
      furnaces: [
        for (final entry in state.furnaces.entries)
          SavedFurnace(
            pos: entry.key,
            input: entry.value.input,
            fuel: entry.value.fuel,
            output: entry.value.output,
            burnLeft: entry.value.burnLeft,
            burnTotal: entry.value.burnTotal,
            progress: entry.value.progress,
          ),
      ],
    );
  }

  /// Rebuilds a game from a save: regenerate the terrain from the seed, then
  /// replay the recorded edits on top.
  GameState restore(SaveData data) {
    final world = VoxelWorld();
    TerrainGenerator(seed: data.seed).generate(world);
    for (final entry in data.edits.entries) {
      final pos = entry.key;
      world.setRaw(pos.x, pos.y, pos.z, entry.value);
    }
    world
      ..edits.addAll(data.edits)
      ..markAllDirty();

    final player = Player(world: world, spawn: _spawnOf(data))
      ..yaw = data.player.yaw
      ..pitch = data.player.pitch
      ..health = data.player.health
      ..flying = data.player.flying;

    final inventory = Inventory();
    for (var i = 0; i < data.inventory.length && i < inventory.length; i++) {
      inventory[i] = data.inventory[i];
    }

    final state = GameState(
      world: world,
      player: player,
      inventory: inventory,
      hotbarSlot: data.selectedSlot,
    );

    for (final furnace in data.furnaces) {
      if (!world
          .blockAt(furnace.pos.x, furnace.pos.y, furnace.pos.z)
          .hasLitVariant) {
        continue;
      }
      state.furnaces.open(furnace.pos)
        ..input = furnace.input
        ..fuel = furnace.fuel
        ..output = furnace.output
        ..burnLeft = furnace.burnLeft
        ..burnTotal = furnace.burnTotal
        ..progress = furnace.progress;
    }
    return state;
  }

  void _returnGridAndCursor(GameState state) {
    for (final grid in [state.smallGrid, state.bigGrid]) {
      for (var i = 0; i < grid.length; i++) {
        final stack = grid[i];
        if (stack == null) continue;
        state.inventory.add(stack.type, stack.count);
        grid[i] = null;
      }
    }
    final held = state.cursor;
    if (held != null) {
      state.inventory.add(held.type, held.count);
      state.cursor = null;
    }
  }

  static Vector3 _spawnOf(SaveData data) =>
      Vector3(data.player.x, data.player.y, data.player.z);
}
