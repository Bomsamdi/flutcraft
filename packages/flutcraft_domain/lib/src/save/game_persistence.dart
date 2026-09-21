import 'package:vector_math/vector_math.dart';

import '../actors/player.dart';
import '../inventory/inventory.dart';
import '../items/item_type.dart';
import '../session/game_state.dart';
import '../session/participant.dart';
import '../world/terrain_generator.dart';
import '../world/voxel_world.dart';
import 'save_data.dart';

/// Maps between live game state and the saved form.
///
/// Mobs, arrows, the crafting grid and the cursor are deliberately not saved.
/// Grid and cursor contents are folded into the saved inventory instead, so
/// quitting mid-craft cannot lose items — and because autosave runs while the
/// player is still arranging that grid, [capture] must not touch live state.
class GamePersistence {
  const GamePersistence();

  /// Reads [state] into a save. Pure: nothing in the running game changes.
  ///
  /// Everyone in the world is saved, not only whoever happens to be first.
  SaveData capture(GameState state) => SaveData(
    world: captureWorld(state),
    players: [
      for (final participant in state.participants.values)
        capturePlayer(participant),
    ],
  );

  /// The world alone — what a server rewrites on its own schedule.
  WorldSave captureWorld(GameState state) => WorldSave(
    seed: state.world.seed,
    edits: Map.of(state.world.edits),
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

  /// One player alone — what a server writes when that player leaves.
  PlayerSave capturePlayer(Participant it) => PlayerSave(
    id: it.id,
    x: it.player.position.x,
    y: it.player.position.y,
    z: it.player.position.z,
    yaw: it.player.yaw,
    pitch: it.player.pitch,
    health: it.player.health,
    flying: it.player.flying,
    inventory: _inventoryWithLooseItems(it),
    selectedSlot: it.selectedSlot,
  );

  /// Rebuilds a game from a save: regenerate the terrain from the seed, then
  /// replay the recorded edits on top.
  GameState restore(SaveData data) {
    final world = restoreWorld(data.world);
    final state = GameState(
      world: world,
      players: [for (final saved in data.players) restorePlayer(saved, world)],
    );

    for (final furnace in data.world.furnaces) {
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

  /// Regenerates the terrain and replays the edits on top of it.
  VoxelWorld restoreWorld(WorldSave saved) {
    final world = VoxelWorld();
    TerrainGenerator(seed: saved.seed).generate(world);
    for (final entry in saved.edits.entries) {
      final pos = entry.key;
      world.setRaw(pos.x, pos.y, pos.z, entry.value);
    }
    return world
      ..edits.addAll(saved.edits)
      ..markAllDirty();
  }

  /// Puts one player back in [world] with what they were carrying.
  Participant restorePlayer(PlayerSave saved, VoxelWorld world) {
    final player = Player(world: world, spawn: _spawnOf(saved))
      ..yaw = saved.yaw
      ..pitch = saved.pitch
      ..health = saved.health
      ..flying = saved.flying;

    // Loading must never drop the player onto the death screen with nothing
    // to do but respawn. Current versions refuse to save a dead player, but
    // an older file — or a hand-edited one — can still say so.
    if (player.isDead) player.respawn();

    final inventory = Inventory();
    for (var i = 0; i < saved.inventory.length && i < inventory.length; i++) {
      inventory[i] = saved.inventory[i];
    }

    return Participant(
      id: saved.id,
      player: player,
      inventory: inventory,
      selectedSlot: saved.selectedSlot,
    );
  }

  /// The inventory as it should be saved: a copy, with whatever sits in the
  /// crafting grids or on the cursor merged back in.
  List<ItemStack?> _inventoryWithLooseItems(Participant participant) {
    final inventory = participant.inventory;
    final copy = Inventory(
      hotbarSize: inventory.hotbarSize,
      backpackSize: inventory.backpackSize,
    );
    for (var i = 0; i < inventory.length; i++) {
      copy[i] = inventory[i];
    }

    for (final grid in [participant.smallGrid, participant.bigGrid]) {
      for (var i = 0; i < grid.length; i++) {
        final stack = grid[i];
        if (stack != null) copy.add(stack.type, stack.count);
      }
    }
    final held = participant.cursor;
    if (held != null) copy.add(held.type, held.count);

    return List.of(copy.slots);
  }

  static Vector3 _spawnOf(PlayerSave saved) =>
      Vector3(saved.x, saved.y, saved.z);
}
