import '../actors/mob.dart';
import '../actors/player.dart';
import '../aiming/aim_result.dart';
import '../blocks/block_pos.dart';
import '../blocks/block_type.dart';
import '../items/item_type.dart';
import '../crafting/recipes.dart';
import 'game_state.dart';
import 'participant.dart';
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

/// The furnace the player has open, as values.
class FurnaceView {
  const FurnaceView({
    required this.input,
    required this.fuel,
    required this.output,
    required this.progress,
    required this.fuelFraction,
    required this.isLit,
  });

  final ItemStack? input;
  final ItemStack? fuel;
  final ItemStack? output;

  /// Smelting progress of the current item, 0..1.
  final double progress;

  /// How much of the current fuel portion is left, 0..1.
  final double fuelFraction;

  final bool isLit;
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
    required this.inventory,
    required this.grid,
    required this.gridSize,
    required this.cursor,
    required this.craftPreview,
    required this.furnace,
  });

  /// Builds a snapshot for the only player of a single-player game.
  factory GameSnapshot.of(GameState state) =>
      GameSnapshot.forPlayer(state, state.solo);

  /// Builds the snapshot one player sees, copying everything it needs.
  ///
  /// A snapshot belongs to a player, not to the world: the hotbar, the open
  /// screen and the crosshair are theirs. What is shared — mobs, blocks —
  /// looks the same in everyone's.
  factory GameSnapshot.forPlayer(GameState state, Participant it) =>
      GameSnapshot(
        hotbar: List<ItemStack?>.unmodifiable(it.inventory.hotbar),
        selectedSlot: it.selectedSlot,
        health: it.player.health,
        maxHealth: Player.maxHealth,
        hurtFlash: it.player.hurtFlash,
        breakProgress: it.breakProgress.clamp(0.0, 1.0),
        aim: switch (it.aim) {
          NoTarget() => const NoAimView(),
          BlockTarget(:final hit) => BlockAimView(hit.block),
          MobTarget(:final mob) => MobAimView(
            mob.kind,
            mob.health,
            mob.kind.maxHealth,
          ),
        },
        position: BlockPos.of(it.player.position),
        route: it.route,
        mobCount: state.mobs.length,
        flying: it.player.flying,
        inventory: List<ItemStack?>.unmodifiable(it.inventory.slots),
        grid: List<ItemStack?>.unmodifiable(it.activeGrid.slots),
        gridSize: it.activeGrid.size,
        cursor: it.cursor,
        craftPreview: _previewOf(it),
        furnace: _furnaceOf(state, it),
      );

  static ItemStack? _previewOf(Participant it) {
    final recipe = matchRecipe(it.activeGrid);
    return recipe == null ? null : ItemStack(recipe.output, recipe.outputCount);
  }

  static FurnaceView? _furnaceOf(GameState state, Participant it) {
    final pos = it.openFurnace;
    if (pos == null) return null;
    final furnace = state.furnaces[pos];
    if (furnace == null) return null;
    return FurnaceView(
      input: furnace.input,
      fuel: furnace.fuel,
      output: furnace.output,
      progress: furnace.progress,
      fuelFraction: furnace.fuelFraction,
      isLit: furnace.isLit,
    );
  }

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

  /// All 36 slots: hotbar first, then the backpack.
  final List<ItemStack?> inventory;

  /// The crafting grid the player is working on.
  final List<ItemStack?> grid;

  /// Side length of [grid]: 2 in the inventory, 3 at a table.
  final int gridSize;

  /// What the player is dragging between slots.
  final ItemStack? cursor;

  /// What [grid] would produce right now.
  final ItemStack? craftPreview;

  /// The open furnace, or `null` when none is.
  final FurnaceView? furnace;

  /// How many slots the hotbar has.
  int get hotbarSize => hotbar.length;
}
