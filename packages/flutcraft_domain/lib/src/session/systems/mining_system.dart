import 'dart:math';

import '../../actors/mob.dart';
import '../../aiming/aim_result.dart';
import '../../blocks/block_type.dart';
import '../../items/item_type.dart';
import '../../loot/block_loot.dart';
import '../../world/voxel_world.dart';
import '../game_event.dart';
import '../game_state.dart';
import '../participant.dart';

/// Breaking blocks and hitting mobs — both are "the player holds the
/// primary button while aiming at something".
///
/// Extracted from the game class so the timing rules can be tested without
/// a GPU: how long a block takes, which tool helps, and what happens when
/// the aim moves to a different block mid-swing.
class MiningSystem {
  MiningSystem({required this.random});

  final Random random;

  /// Seconds between melee swings.
  static const double attackCooldown = 0.42;

  /// Multiplier applied when the held tool matches the block's preference.
  static const double matchingToolBonus = 2;

  /// Runs one frame for one player. [active] is true while they hold the
  /// button.
  ///
  /// Returns the events produced this frame.
  List<GameEvent> update(
    GameState state,
    Participant participant,
    double dt, {
    required bool active,
  }) {
    if (participant.attackTimer > 0) participant.attackTimer -= dt;

    if (!active) {
      participant.breakProgress = 0;
      return const [];
    }

    return switch (participant.aim) {
      NoTarget() => const [],
      MobTarget(:final mob) => _hitMob(participant, mob),
      BlockTarget(:final hit) => _mineBlock(state, participant, dt, hit),
    };
  }

  List<GameEvent> _hitMob(Participant participant, Mob mob) {
    if (participant.attackTimer > 0) return const [];
    participant.attackTimer = attackCooldown;
    final damage = (participant.heldItem?.damage ?? 1).toDouble();
    mob.damage(damage, source: participant.player.position, by: participant.id);
    return const [];
  }

  List<GameEvent> _mineBlock(
    GameState state,
    Participant participant,
    double dt,
    RayHit hit,
  ) {
    final block = hit.block;
    if (!block.breakable) return const [];

    participant.breakProgress += dt / breakTime(block, participant.heldItem);
    if (participant.breakProgress < 1) return const [];

    participant.breakProgress = 0;
    return breakBlockAt(state, participant, hit);
  }

  /// Removes the block, banks the drops and reports what happened.
  List<GameEvent> breakBlockAt(
    GameState state,
    Participant participant,
    RayHit hit,
  ) {
    final block = hit.block;
    final pos = hit.pos;
    final events = <GameEvent>[];

    if (block.hasLitVariant) state.furnaces.remove(pos);
    state.world.setBlock(pos.x, pos.y, pos.z, BlockType.air);

    final drops = blockDrops(block, participant.heldItem, random);
    if (drops.isEmpty) {
      if (block.requiredTier > 0) events.add(ToolTooWeak(block));
    } else {
      for (final drop in drops) {
        if (participant.inventory.add(drop.type, drop.count) > 0) {
          events.add(InventoryFull(drop.type));
        }
      }
    }

    participant.aim = const NoTarget();
    events.add(BlockBroken(pos, block, drops));
    return events;
  }

  /// How long [block] takes to break while holding [tool].
  ///
  /// A matching tool speeds things up proportionally to its tier, which is
  /// what makes an iron pickaxe worth crafting.
  static double breakTime(BlockType block, ItemType? tool) {
    final matches = tool != null && tool.tool == block.tool;
    final speed = matches ? matchingToolBonus + tool.tier * 2.0 : 1.0;
    return max(0.08, block.hardness * 1.2 / speed);
  }
}
