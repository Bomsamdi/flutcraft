import '../actors/mob.dart';
import '../actors/player.dart';
import '../aiming/aim_result.dart';
import '../blocks/block_pos.dart';
import '../crafting/recipes.dart';
import '../inventory/inventory.dart';
import '../items/item_type.dart';
import '../machines/furnace_registry.dart';
import '../world/voxel_world.dart';
import 'ui_route.dart';

/// Everything the simulation knows.
///
/// One aggregate passed to every system, so that systems stay free functions
/// over state rather than methods on an object that owns half the game. It
/// holds no rendering, no textures and no widgets — those read from it.
class GameState {
  GameState({
    required this.world,
    required this.player,
    required this.inventory,
    int hotbarSlot = 0,
  }) : selectedSlot = hotbarSlot;

  final VoxelWorld world;
  final Player player;
  final Inventory inventory;

  final List<Mob> mobs = [];
  final List<Arrow> arrows = [];
  final FurnaceRegistry furnaces = FurnaceRegistry();

  /// 2x2 grid in the inventory, 3x3 at a crafting table.
  final CraftingGrid smallGrid = CraftingGrid(2);
  final CraftingGrid bigGrid = CraftingGrid(3);

  /// The stack the player is dragging between slots.
  ItemStack? cursor;

  /// Which hotbar slot is active.
  int selectedSlot;

  /// Where the player is in the interface.
  UiRoute route = UiRoute.none;

  /// The furnace whose screen is open, if any.
  BlockPos? openFurnace;

  /// What the player is looking at right now.
  AimResult aim = const NoTarget();

  /// Progress on breaking the aimed block, 0..1.
  double breakProgress = 0;

  /// The grid the player is currently working on.
  CraftingGrid get activeGrid =>
      route == UiRoute.craftingTable ? bigGrid : smallGrid;

  /// The item in the player's hand, or `null` for a bare fist.
  ItemType? get heldItem => inventory[selectedSlot]?.type;
}
