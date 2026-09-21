// ignore_for_file: prefer_initializing_formals
import 'package:meta/meta.dart';
import '../blocks/block_type.dart';
import '../blocks/tile.dart';

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
  stick(icon: Tile.stickIcon),
  coal(icon: Tile.coalIcon, burnTime: 8),
  rawIron(icon: Tile.rawIronIcon),
  ironIngot(icon: Tile.ironIngotIcon),
  bone(icon: Tile.boneIcon),
  string(icon: Tile.stringIcon),
  gunpowder(icon: Tile.gunpowderIcon),
  arrow(icon: Tile.arrowIcon),

  // --- narzędzia ---
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

  /// Blok, który ten przedmiot stawia; `null` dla surowców i narzędzi.
  final BlockType? block;
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
///
/// Niemutowalny celowo. Gdy stos można było zmieniać w miejscu, migawka
/// stanu dla UI nie była migawką — trzeba było ręcznie podbijać licznik
/// zmian w ośmiu miejscach, a zapomnienie jednego dawało nieaktualny
/// ekwipunek bez żadnego sygnału.
@immutable
final class ItemStack {
  const ItemStack(this.type, [this.count = 1]);

  final ItemType type;
  final int count;

  bool get isEmpty => count <= 0;

  /// Ile jeszcze sztuk zmieści się w tym stosie.
  int get space => type.maxStack - count;

  /// Ten sam przedmiot w innej ilości.
  ItemStack withCount(int value) => ItemStack(type, value);

  /// Ten sam przedmiot, ilość zmieniona o [delta] (może być ujemna).
  ItemStack plus(int delta) => ItemStack(type, count + delta);

  @override
  bool operator ==(Object other) =>
      other is ItemStack && other.type == type && other.count == count;

  @override
  int get hashCode => Object.hash(type, count);

  @override
  String toString() => '${type.name} x$count';
}
