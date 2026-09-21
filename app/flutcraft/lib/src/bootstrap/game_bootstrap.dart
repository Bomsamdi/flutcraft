import 'dart:math';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:vector_math/vector_math.dart';

/// How often the game saves itself while being played.
const double kAutosaveInterval = 60;

/// Builds a fresh game: world, terrain, player, systems and session.
///
/// None of this needs a GPU, so the composition root can assemble the whole
/// simulation before the engine starts. The engine then renders something
/// that already exists, rather than owning it.
LoopGameSession createSession({int seed = 1337, SaveSink? saveSink}) {
  final world = VoxelWorld();
  TerrainGenerator(seed: seed).generate(world);
  world.markAllDirty();

  final player = Player(world: world, spawn: Vector3.zero())
    ..respawn()
    ..pitch = -0.25;

  final state = GameState(world: world, player: player, inventory: Inventory());
  _giveStartingItems(state.inventory);

  return _sessionFor(state, seed: seed, saveSink: saveSink);
}

/// Continues a saved game instead of generating a new one.
///
/// The player keeps whatever they had; no starting items are handed out
/// again, or every reload would be a small windfall.
LoopGameSession restoreSession(SaveData data, {SaveSink? saveSink}) {
  final state = const GamePersistence().restore(data);
  return _sessionFor(state, seed: data.seed, saveSink: saveSink);
}

LoopGameSession _sessionFor(
  GameState state, {
  required int seed,
  required SaveSink? saveSink,
}) => LoopGameSession(
  GameLoop(
    state: state,
    spawner: MobSpawner(world: state.world, seed: seed),
    random: Random(seed),
    saveSink: saveSink,
    autosaveInterval: kAutosaveInterval,
  ),
);

/// A handful of blocks so the first minute is not spent punching trees.
void _giveStartingItems(Inventory inventory) {
  inventory
    ..add(ItemType.log, 8)
    ..add(ItemType.planks, 8)
    ..add(ItemType.cobblestone, 16);
}
