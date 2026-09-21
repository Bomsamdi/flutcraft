import 'dart:math';

import '../../actors/mob.dart';
import '../../actors/mob_behavior.dart';
import '../game_event.dart';
import '../game_state.dart';

/// Spawning, ticking and retiring mobs.
///
/// Owns the population: the spawner only proposes a mob, this system decides
/// whether it joins the world and cleans up the ones that died, banking their
/// loot on the way out.
class MobAiSystem {
  MobAiSystem({required this.spawner, required this.random});

  final MobSpawner spawner;
  final Random random;

  List<GameEvent> update(
    GameState state,
    double dt,
    MobTickContext context,
  ) {
    final events = <GameEvent>[];

    final spawned = spawner.maybeSpawn(dt, state.player, state.mobs.length);
    if (spawned != null) state.mobs.add(spawned);

    for (final mob in List<Mob>.from(state.mobs)) {
      mob.update(dt, state.player, context);
      if (!mob.isDead) continue;

      state.mobs.remove(mob);
      final loot = mob.kind.loot.roll(random);
      for (final drop in loot) {
        state.inventory.add(drop.type, drop.count);
      }
      events.add(MobKilled(mob.kind, loot));
    }
    return events;
  }

  /// Clears the world of mobs — used on respawn.
  void despawnAll(GameState state) => state.mobs.clear();
}
