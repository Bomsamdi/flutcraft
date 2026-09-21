// ignore_for_file: prefer_initializing_formals
import 'package:meta/meta.dart';
import '../blocks/block_type.dart';
import '../blocks/tile.dart';

/// Anything that can sit in the inventory: blocks, materials and tools.
///
/// An item with a [block] can be placed in the world; the rest are only
/// good for crafting or fighting.
enum ItemType {
  // --- blocks ---
  grass(block: BlockType.grass),
  dirt(block: BlockType.dirt),
  stone(block: BlockType.stone),
  cobblestone(block: BlockType.cobblestone),
  sand(block: BlockType.sand),
  gravel(block: BlockType.gravel),
  log(block: BlockType.log),
  leaves(block: BlockType.leaves),
  planks(block: BlockType.planks),
  brick(block: BlockType.brick),
  coalOre(block: BlockType.coalOre),
  ironOre(block: BlockType.ironOre),
  craftingTable(block: BlockType.craftingTable),
  furnace(block: BlockType.furnace),

  // --- surowce ---
  stick(icon: Tile.stickIcon),
  coal(icon: Tile.coalIcon, burnTime: 8),
  rawIron(icon: Tile.rawIronIcon),
  ironIngot(icon: Tile.ironIngotIcon),
  bone(icon: Tile.boneIcon),
  string(icon: Tile.stringIcon),
  gunpowder(icon: Tile.gunpowderIcon),
  arrow(icon: Tile.arrowIcon),

  // --- tools ---
  woodenPickaxe(
    icon: Tile.woodPickIcon,
    tool: ToolType.pickaxe,
    tier: 1,
    damage: 2,
    maxStack: 1,
  ),
  stonePickaxe(
    icon: Tile.stonePickIcon,
    tool: ToolType.pickaxe,
    tier: 2,
    damage: 3,
    maxStack: 1,
  ),
  ironPickaxe(
    icon: Tile.ironPickIcon,
    tool: ToolType.pickaxe,
    tier: 3,
    damage: 4,
    maxStack: 1,
  ),
  woodenSword(
    icon: Tile.woodSwordIcon,
    tool: ToolType.sword,
    tier: 1,
    damage: 5,
    maxStack: 1,
  ),
  stoneSword(
    icon: Tile.stoneSwordIcon,
    tool: ToolType.sword,
    tier: 2,
    damage: 6,
    maxStack: 1,
  ),
  ironSword(
    icon: Tile.ironSwordIcon,
    tool: ToolType.sword,
    tier: 3,
    damage: 8,
    maxStack: 1,
  );

  const ItemType({
    this.block,
    Tile? icon,
    this.tool = ToolType.none,
    this.tier = 0,
    this.damage = 1,
    this.maxStack = 64,
    this.burnTime = 0,
  }) : _icon = icon;

  /// The block this item places; `null` for materials and tools.
  final BlockType? block;
  final Tile? _icon;

  /// Which kind of tool this item is, if any.
  final ToolType tool;

  /// Material tier: 1 wood, 2 stone, 3 iron.
  final int tier;

  /// Damage dealt to mobs.
  final int damage;

  final int maxStack;

  /// Seconds of smelting this item gives as fuel; 0 means it does not burn.
  final double burnTime;

  /// The tile used as its inventory icon.
  Tile get icon => _icon ?? block!.sideTile;

  bool get isBlock => block != null;

  bool get isTool => tool != ToolType.none;

  bool get isFuel => burnTime > 0;

  /// The item that corresponds to a block, for placing and picking up.
  static ItemType? forBlock(BlockType block) {
    for (final item in ItemType.values) {
      if (item.block == block) return item;
    }
    return null;
  }
}

/// A stack of items in one slot.
///
/// Immutable on purpose. While a stack could be changed in place, the
/// snapshot handed to the UI was not really a snapshot: a revision counter
/// had to be bumped by hand in eight places, and forgetting one left a stale
/// inventory on screen with nothing to signal it.
@immutable
final class ItemStack {
  const ItemStack(this.type, [this.count = 1]);

  final ItemType type;
  final int count;

  bool get isEmpty => count <= 0;

  /// How many more items fit in this stack.
  int get space => type.maxStack - count;

  /// The same item, a different count.
  ItemStack withCount(int value) => ItemStack(type, value);

  /// The same item, count changed by [delta], which may be negative.
  ItemStack plus(int delta) => ItemStack(type, count + delta);

  @override
  bool operator ==(Object other) =>
      other is ItemStack && other.type == type && other.count == count;

  @override
  int get hashCode => Object.hash(type, count);

  @override
  String toString() => '${type.name} x$count';
}
