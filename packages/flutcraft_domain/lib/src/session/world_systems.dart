import 'dart:math';

import '../actors/mob.dart';
import '../save/save_sink.dart';
import 'systems/autosave_system.dart';
import 'systems/entity_separation_system.dart';
import 'systems/explosion_system.dart';
import 'systems/furnace_system.dart';
import 'systems/mob_ai_system.dart';
import 'systems/projectile_system.dart';

/// The systems that decide what is true in the world.
///
/// A server has these. A client does not, and that absence is the whole
/// difference between a loop that predicts and one that rules:
///
/// * Mobs. A client that ran the AI would have its own opinion about where
///   the zombie is, and the difference would show up as a zombie in two
///   places at once.
/// * Furnaces. Smelting progress is not something two machines can be
///   trusted to agree on, and every flip of a lit furnace writes a block.
/// * Projectiles, explosions, separation. All of them move or destroy things
///   that belong to everybody.
/// * The autosave. There is one world to write down, and the client is not
///   holding it.
///
/// The order they run in is not in here — that stays written out in the loop,
/// where it can be read. This is only the question of who owns them.
class WorldSystems {
  WorldSystems({
    required MobSpawner spawner,
    required Random random,
    SaveSink? saveSink,
    double autosaveInterval = 60,
    this.pausesWhenEveryoneSteppedAway = true,
  }) : mobs = MobAiSystem(spawner: spawner, random: random),
       autosave = saveSink == null
           ? null
           : AutosaveSystem(sink: saveSink, interval: autosaveInterval);

  /// Whether time stops while nobody is looking at the world.
  ///
  /// True for a game on one machine: opening the inventory freezes the world,
  /// which is what a single player expects and what makes a pause a pause.
  ///
  /// False for a server. Two people sorting their bags is not a reason for
  /// everybody else's zombies to stand still, and a world nobody is currently
  /// looking at still has furnaces running in it.
  final bool pausesWhenEveryoneSteppedAway;

  final MobAiSystem mobs;
  final AutosaveSystem? autosave;
  final ProjectileSystem projectiles = const ProjectileSystem();
  final FurnaceSystem furnaces = const FurnaceSystem();
  final ExplosionSystem explosions = const ExplosionSystem();
  final EntitySeparationSystem separation = const EntitySeparationSystem();
}
