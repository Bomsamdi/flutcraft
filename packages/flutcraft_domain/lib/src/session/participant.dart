import '../actors/player.dart';
import '../aiming/aim_result.dart';
import '../blocks/block_pos.dart';
import '../crafting/recipes.dart';
import '../inventory/inventory.dart';
import '../items/item_type.dart';
import 'ui_route.dart';

/// Who a piece of state belongs to.
///
/// An extension type rather than a bare `String`: it costs nothing at run
/// time and makes it impossible to pass a block name, a save slot or any
/// other string where a player was meant.
extension type const PlayerId(String value) {}

/// One player and everything that is theirs alone.
///
/// The world, the mobs and the furnaces are shared; a hotbar, a cursor and
/// an open screen are not. Splitting them apart is what lets a second player
/// exist at all — before this, "the inventory" meant exactly one inventory.
final class Participant {
  Participant({
    required this.id,
    required this.player,
    Inventory? inventory,
    this.selectedSlot = 0,
  }) : inventory = inventory ?? Inventory();

  final PlayerId id;
  final Player player;
  final Inventory inventory;

  /// 2x2 grid in the inventory, 3x3 at a crafting table.
  final CraftingGrid smallGrid = CraftingGrid(2);
  final CraftingGrid bigGrid = CraftingGrid(3);

  /// The stack this player is dragging between slots.
  ItemStack? cursor;

  /// Which hotbar slot is active.
  int selectedSlot;

  /// Where this player is in the interface.
  UiRoute route = UiRoute.none;

  /// The furnace whose screen this player has open, if any.
  ///
  /// Two players can have the same furnace open: the furnace itself is
  /// shared, the screen showing it is not.
  BlockPos? openFurnace;

  /// What this player is looking at right now.
  AimResult aim = const NoTarget();

  /// Seconds until this player may swing again.
  ///
  /// Used to live inside the mining system as a private field. With one
  /// player nobody noticed; with two, a single timer meant one player's
  /// swing put the other's on cooldown. Timers belong to whoever is waiting.
  double attackTimer = 0;

  /// Seconds until this player may place another block.
  double placeTimer = 0;

  /// Progress on breaking the aimed block, 0..1.
  ///
  /// Per player on purpose: two people hitting the same block each make their
  /// own progress, which is also how the original behaves.
  double breakProgress = 0;

  /// The grid this player is currently working on.
  CraftingGrid get activeGrid =>
      route == UiRoute.craftingTable ? bigGrid : smallGrid;

  /// The item in this player's hand, or `null` for a bare fist.
  ItemType? get heldItem => inventory[selectedSlot]?.type;
}
