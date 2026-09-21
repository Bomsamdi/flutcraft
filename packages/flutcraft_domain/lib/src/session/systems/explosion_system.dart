import 'dart:math';

import 'package:vector_math/vector_math.dart';

import '../../actors/mob.dart';
import '../../blocks/block_pos.dart';
import '../../blocks/block_type.dart';
import '../game_event.dart';
import '../game_state.dart';

/// Blowing a hole in the world.
///
/// Damage falls off with distance for both the player and other mobs, which
/// is why standing one block further back is worth it — and why a creeper
/// can clear out its own neighbours.
class ExplosionSystem {
  const ExplosionSystem();

  /// Destroys terrain and hurts everything near [at].
  List<GameEvent> explode(
    GameState state,
    Vector3 at,
    double radius,
    int maxDamage,
  ) {
    _destroyTerrain(state, at, radius);
    _hurtPlayer(state, at, radius, maxDamage);
    _hurtMobs(state, at, radius, maxDamage);
    return const [CreeperExploded()];
  }

  void _destroyTerrain(GameState state, Vector3 at, double radius) {
    final reach = radius.ceil();
    final centre = BlockPos.of(at);

    for (var y = centre.y - reach; y <= centre.y + reach; y++) {
      for (var z = centre.z - reach; z <= centre.z + reach; z++) {
        for (var x = centre.x - reach; x <= centre.x + reach; x++) {
          final dx = x + 0.5 - at.x;
          final dy = y + 0.5 - at.y;
          final dz = z + 0.5 - at.z;
          if (dx * dx + dy * dy + dz * dz > radius * radius) continue;

          final block = state.world.blockAt(x, y, z);
          // Bedrock survives, as does anything already empty.
          if (!block.solid || !block.breakable) continue;
          if (block.hasLitVariant) state.furnaces.remove(BlockPos(x, y, z));
          state.world.setBlock(x, y, z, BlockType.air);
        }
      }
    }
  }

  void _hurtPlayer(GameState state, Vector3 at, double radius, int maxDamage) {
    final blastRadius = radius + 1;
    final distance = state.player.center.distanceTo(at);
    if (distance >= blastRadius) return;

    final falloff = 1 - (distance / blastRadius).clamp(0.0, 1.0);
    state.player.damage(max(1, (maxDamage * falloff).round()), source: at);
  }

  void _hurtMobs(GameState state, Vector3 at, double radius, int maxDamage) {
    final blastRadius = radius + 0.5;
    for (final mob in List<Mob>.from(state.mobs)) {
      final distance = mob.center.distanceTo(at);
      if (distance >= blastRadius) continue;
      mob.damage(maxDamage * (1 - distance / blastRadius), source: at);
    }
  }
}
