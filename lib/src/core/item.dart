// ignore_for_file: prefer_initializing_formals
import 'package:flutcraft/src/core/block.dart';
import 'package:flutcraft/src/core/tiles.dart';

/// Wszystko, co może leżeć w ekwipunku: bloki, surowce i narzędzia.
///
/// Przedmiot z ustawionym [block] da się postawić w świecie; pozostałe
/// służą tylko do craftingu albo walki.
enum ItemType {
  // --- bloki ---
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
  stick(label: 'Patyk', icon: Tile.stickIcon),
  coal(label: 'Węgiel', icon: Tile.coalIcon, burnTime: 8),
  rawIron(label: 'Surowe żelazo', icon: Tile.rawIronIcon),
  ironIngot(label: 'Sztabka żelaza', icon: Tile.ironIngotIcon),
  bone(label: 'Kość', icon: Tile.boneIcon),
  string(label: 'Nić', icon: Tile.stringIcon),
  gunpowder(label: 'Proch', icon: Tile.gunpowderIcon),
  arrow(label: 'Strzała', icon: Tile.arrowIcon),

  // --- narzędzia ---
  woodenPickaxe(
    label: 'Drewniany kilof',
    icon: Tile.woodPickIcon,
    tool: ToolType.pickaxe,
    tier: 1,
    damage: 2,
    maxStack: 1,
  ),
  stonePickaxe(
    label: 'Kamienny kilof',
    icon: Tile.stonePickIcon,
    tool: ToolType.pickaxe,
    tier: 2,
    damage: 3,
    maxStack: 1,
  ),
  ironPickaxe(
    label: 'Żelazny kilof',
    icon: Tile.ironPickIcon,
    tool: ToolType.pickaxe,
    tier: 3,
    damage: 4,
    maxStack: 1,
  ),
  woodenSword(
    label: 'Drewniany miecz',
    icon: Tile.woodSwordIcon,
    tool: ToolType.sword,
    tier: 1,
    damage: 5,
    maxStack: 1,
  ),
  stoneSword(
    label: 'Kamienny miecz',
    icon: Tile.stoneSwordIcon,
    tool: ToolType.sword,
    tier: 2,
    damage: 6,
    maxStack: 1,
  ),
  ironSword(
    label: 'Żelazny miecz',
    icon: Tile.ironSwordIcon,
    tool: ToolType.sword,
    tier: 3,
    damage: 8,
    maxStack: 1,
  );

  const ItemType({
    this.block,
    String? label,
    Tile? icon,
    this.tool = ToolType.none,
    this.tier = 0,
    this.damage = 1,
    this.maxStack = 64,
    this.burnTime = 0,
  }) : _label = label,
       _icon = icon;

  /// Blok, który ten przedmiot stawia; `null` dla surowców i narzędzi.
  final BlockType? block;

  final String? _label;
  final Tile? _icon;

  /// Narzędzie, jakim ten przedmiot jest (kilof, miecz...).
  final ToolType tool;

  /// Poziom materiału: 1 drewno, 2 kamień, 3 żelazo.
  final int tier;

  /// Obrażenia zadawane potworom.
  final int damage;

  final int maxStack;

  /// Ile sekund wytopu daje ten przedmiot jako paliwo (0 = nie pali się).
  final double burnTime;

  String get label => _label ?? block!.label;

  /// Kafelek używany jako ikona w ekwipunku.
  Tile get icon => _icon ?? block!.sideTile;

  bool get isBlock => block != null;

  bool get isTool => tool != ToolType.none;

  bool get isFuel => burnTime > 0;

  /// Przedmiot odpowiadający blokowi - do stawiania i podnoszenia.
  static ItemType? forBlock(BlockType block) {
    for (final item in ItemType.values) {
      if (item.block == block) return item;
    }
    return null;
  }
}

/// Stos przedmiotów w jednym slocie.
class ItemStack {
  ItemStack(this.type, [this.count = 1]);

  final ItemType type;
  int count;

  bool get isEmpty => count <= 0;

  int get space => type.maxStack - count;

  ItemStack copy() => ItemStack(type, count);

  @override
  String toString() => '${type.name} x$count';
}

/// Co wypada po zbiciu bloku danym narzędziem.
///
/// Zwraca `null`, gdy narzędzie jest za słabe (jak w Minecrafcie: kamień
/// bity ręką nie daje nic) albo blok nie ma dropu.
ItemStack? dropFor(BlockType block, ItemType? heldItem) {
  final tier = heldItem?.tool == ToolType.pickaxe ? heldItem!.tier : 0;
  if (block.requiredTier > tier) return null;

  return switch (block) {
    BlockType.stone => ItemStack(ItemType.cobblestone),
    BlockType.grass => ItemStack(ItemType.dirt),
    BlockType.coalOre => ItemStack(ItemType.coal),
    BlockType.ironOre => ItemStack(ItemType.rawIron),
    BlockType.furnaceLit => ItemStack(ItemType.furnace),
    BlockType.leaves => null,
    BlockType.bedrock => null,
    BlockType.air => null,
    _ => switch (ItemType.forBlock(block)) {
      final item? => ItemStack(item),
      _ => null,
    },
  };
}
