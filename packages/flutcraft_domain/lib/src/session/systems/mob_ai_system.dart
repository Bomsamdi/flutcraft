import 'dart:math';

import '../../actors/mob.dart';
import '../../actors/mob_behavior.dart';
import '../addressed_event.dart';
import '../game_event.dart';
import '../game_state.dart';
import '../participant.dart';

/// Spawning, ticking and retiring mobs.
///
/// Owns the population: the spawner only proposes a mob, this system decides
/// whether it joins the world and cleans up the ones that died, banking their
/// loot on the way out.
class MobAiSystem {
  MobAiSystem({required this.spawner, required this.random});

  final MobSpawner spawner;
  final Random random;

  List<AddressedEvent> update(
    GameState state,
    double dt,
    MobTickContext context,
  ) {
    final events = <AddressedEvent>[];

    // One spawn attempt per tick, around one player chosen at random.
    //
    // The spawner keeps its own clock, so calling it once per player would
    // advance that clock N times a frame: a world with four people in it
    // would breed four times as fast as one with a single player.
    final hosts = state.participants.values.toList();
    final host = hosts[random.nextInt(hosts.length)];
    final spawned = spawner.maybeSpawn(dt, host.player, state.mobs.length);
    if (spawned != null) state.spawn(spawned);

    for (final mob in List<Mob>.from(state.mobs)) {
      // A mob chases whoever is closest, not whoever happens to be first.
      final target = state.nearestLivingTo(mob.position);
      mob.update(
        dt,
        target?.player ?? state.participants.values.first.player,
        context,
      );
      if (!mob.isDead) continue;

      state.mobs.remove(mob);
      final loot = mob.kind.loot.roll(random);
      final claimant = _claimantFor(state, mob);
      for (final drop in loot) {
        claimant.inventory.add(drop.type, drop.count);
      }
      // The notice follows the loot: told to whoever earned it, so nobody
      // reads that they killed something they never touched.
      events.add(AddressedEvent(MobKilled(mob.kind, loot), claimant.id));
    }
    return events;
  }

  /// Who collects what a mob dropped.
  ///
  /// Whoever landed the killing blow. A mob that died to something other than
  /// a player — a creeper, a fall — has nobody to thank, so its drops go to
  /// the nearest living player rather than evaporating.
  Participant _claimantFor(GameState state, Mob mob) {
    final killer = mob.lastHitBy;
    if (killer != null) {
      final participant = state.participants[killer];
      if (participant != null) return participant;
    }
    return state.nearestLivingTo(mob.position) ??
        state.participants.values.first;
  }

  /// Clears the world of mobs — used on respawn.
  void despawnAll(GameState state) => state.mobs.clear();
}
