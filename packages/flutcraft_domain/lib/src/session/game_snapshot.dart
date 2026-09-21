import '../actors/mob.dart';
import '../actors/player.dart';
import '../aiming/aim_result.dart';
import '../blocks/block_pos.dart';
import '../blocks/block_type.dart';
import '../items/item_type.dart';
import 'game_state.dart';
import 'ui_route.dart';

/// What the crosshair is on, in a form the UI can render.
sealed class AimView {
  const AimView();
}

final class NoAimView extends AimView {
  const NoAimView();
}

final class BlockAimView extends AimView {
  const BlockAimView(this.block);

  final BlockType block;
}

final class MobAimView extends AimView {
  const MobAimView(this.kind, this.health, this.maxHealth);

  final MobKind kind;
  final double health;
  final int maxHealth;

  double get fraction => (health / maxHealth).clamp(0.0, 1.0);
}

/// An immutable picture of the game at one instant.
///
/// Every field is a value, so a widget that holds an old snapshot genuinely
/// sees the old game. That is what replaces the hand-maintained revision
/// counter: equality is now enough to decide whether anything changed.
class GameSnapshot {
  GameSnapshot({
    required this.hotbar,
    required this.selectedSlot,
    required this.health,
    required this.maxHealth,
    required this.hurtFlash,
    required this.breakProgress,
    required this.aim,
    required this.position,
    required this.route,
    required this.mobCount,
    required this.flying,
  });

  /// Builds a snapshot from live state, copying everything it needs.
  factory GameSnapshot.of(GameState state) => GameSnapshot(
    hotbar: List<ItemStack?>.unmodifiable(state.inventory.hotbar),
    selectedSlot: state.selectedSlot,
    health: state.player.health,
    maxHealth: Player.maxHealth,
    hurtFlash: state.player.hurtFlash,
    breakProgress: state.breakProgress.clamp(0.0, 1.0),
    aim: switch (state.aim) {
      NoTarget() => const NoAimView(),
      BlockTarget(:final hit) => BlockAimView(hit.block),
      MobTarget(:final mob) => MobAimView(
        mob.kind,
        mob.health,
        mob.kind.maxHealth,
      ),
    },
    position: BlockPos.of(state.player.position),
    route: state.route,
    mobCount: state.mobs.length,
    flying: state.player.flying,
  );

  final List<ItemStack?> hotbar;
  final int selectedSlot;
  final int health;
  final int maxHealth;
  final double hurtFlash;
  final double breakProgress;
  final AimView aim;
  final BlockPos position;
  final UiRoute route;
  final int mobCount;
  final bool flying;
}
