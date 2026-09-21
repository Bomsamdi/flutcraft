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

/// What one tick of holding the primary button came to.
///
/// The swing itself — the cooldown, the progress bar — is something a client
/// may work out for itself; breaking the block and hurting the mob are not.
/// Splitting the answer from the act is what lets the same system run on both
/// sides of a connection, with only the loop deciding which half to carry out.
sealed class Swing {
  const Swing();
}

/// Nothing yet: no target, or still chipping away.
final class SwingContinues extends Swing {
  const SwingContinues();
}

/// The block has taken enough and is ready to go.
final class BlockGivesWay extends Swing {
  const BlockGivesWay(this.hit);

  final RayHit hit;
}

/// The swing connected with a mob.
final class MobStruck extends Swing {
  const MobStruck(this.mob);

  final Mob mob;
}

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

  /// Advances one player's swing and says what it came to.
  ///
  /// Touches only that player's own timers and progress bar, so a client can
  /// run it and show a progress ring without waiting for a round trip.
  /// [active] is true while they hold the button.
  Swing accumulate(Participant participant, double dt, {required bool active}) {
    if (participant.attackTimer > 0) participant.attackTimer -= dt;

    if (!active) {
      participant.breakProgress = 0;
      return const SwingContinues();
    }

    switch (participant.aim) {
      case NoTarget():
        return const SwingContinues();

      case MobTarget(:final mob):
        if (participant.attackTimer > 0) return const SwingContinues();
        participant.attackTimer = attackCooldown;
        return MobStruck(mob);

      case BlockTarget(:final hit):
        if (!hit.block.breakable) return const SwingContinues();
        participant.breakProgress +=
            dt / breakTime(hit.block, participant.heldItem);
        if (participant.breakProgress < 1) return const SwingContinues();
        participant.breakProgress = 0;
        return BlockGivesWay(hit);
    }
  }

  /// Hurts a mob. Only a server may say how much health anything has left.
  void strike(Participant participant, Mob mob) {
    final damage = (participant.heldItem?.damage ?? 1).toDouble();
    mob.damage(damage, source: participant.player.position, by: participant.id);
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
