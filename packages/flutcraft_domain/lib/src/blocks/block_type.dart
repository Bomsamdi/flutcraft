// ignore_for_file: prefer_initializing_formals
import 'tile.dart';

/// Rodzaj narzędzia, które przyspiesza kopanie danego bloku.
enum ToolType { none, pickaxe, axe, shovel, sword }

/// Wszystkie bloki prototypu. `air` jest blokiem "pustym" i nigdy nie
/// trafia do siatki.
enum BlockType {
  air(solid: false, hardness: 0, tool: ToolType.none, top: Tile.stone),
  grass(
    hardness: 0.6,
    tool: ToolType.shovel,
    top: Tile.grassTop,
    side: Tile.grassSide,
    bottom: Tile.dirt,
  ),
  dirt(hardness: 0.5, tool: ToolType.shovel, top: Tile.dirt),
  stone(
    hardness: 1.5,
    tool: ToolType.pickaxe,
    requiredTier: 1,
    top: Tile.stone,
  ),
  cobblestone(
    hardness: 2,
    tool: ToolType.pickaxe,
    requiredTier: 1,
    top: Tile.cobblestone,
  ),
  sand(hardness: 0.5, tool: ToolType.shovel, top: Tile.sand),
  gravel(hardness: 0.6, tool: ToolType.shovel, top: Tile.gravel),
  log(hardness: 2, tool: ToolType.axe, top: Tile.logTop, side: Tile.logSide),
  leaves(hardness: 0.2, tool: ToolType.none, top: Tile.leaves),
  planks(hardness: 2, tool: ToolType.axe, top: Tile.planks),
  brick(hardness: 2, tool: ToolType.pickaxe, requiredTier: 1, top: Tile.brick),
  coalOre(
    hardness: 3,
    tool: ToolType.pickaxe,
    requiredTier: 1,
    top: Tile.coalOre,
  ),
  ironOre(
    hardness: 3,
    tool: ToolType.pickaxe,
    requiredTier: 2,
    top: Tile.ironOre,
  ),
  craftingTable(
    hardness: 2.5,
    tool: ToolType.axe,
    top: Tile.craftingTableTop,
    side: Tile.craftingTableSide,
    bottom: Tile.planks,
  ),
  furnace(
    hardness: 3.5,
    tool: ToolType.pickaxe,
    requiredTier: 1,
    top: Tile.furnaceTop,
    side: Tile.furnaceSide,
    front: Tile.furnaceFront,
    litVariantName: 'furnaceLit',
  ),
  furnaceLit(
    hardness: 3.5,
    tool: ToolType.pickaxe,
    requiredTier: 1,
    top: Tile.furnaceTop,
    side: Tile.furnaceSide,
    front: Tile.furnaceFrontLit,
    unlitVariantName: 'furnace',
  ),
  bedrock(hardness: -1, tool: ToolType.none, top: Tile.bedrock);

  const BlockType({
    required this.hardness,
    required this.tool,
    required Tile top,
    Tile? side,
    Tile? bottom,
    Tile? front,
    this.solid = true,
    this.requiredTier = 0,
    String? litVariantName,
    String? unlitVariantName,
  }) : _litVariantName = litVariantName,
       _unlitVariantName = unlitVariantName,
       _top = top,
       _side = side,
       _bottom = bottom,
       _front = front;

  /// Czas bazowy kopania (sekundy). Ujemna wartość = bloku nie da się zbić.
  final double hardness;

  /// Narzędzie, które daje bonus prędkości.
  final ToolType tool;

  /// Czy blok blokuje ruch i zasłania sąsiadów.
  final bool solid;

  /// Minimalny poziom kilofa potrzebny, żeby blok cokolwiek upuścił.
  /// 0 = ręka wystarczy, 1 = drewniany, 2 = kamienny, 3 = żelazny.
  final int requiredTier;

  // Warianty trzymamy po nazwie, bo enum nie może odwoływać się do własnych
  // wartości w konstruktorze const.
  final String? _litVariantName;
  final String? _unlitVariantName;

  final Tile _top;
  final Tile? _side;
  final Tile? _bottom;
  final Tile? _front;

  Tile get topTile => _top;
  Tile get sideTile => _side ?? _top;
  Tile get bottomTile => _bottom ?? _side ?? _top;

  /// Wyróżniona ściana (front pieca); `null` gdy blok wygląda tak samo
  /// ze wszystkich stron.
  Tile? get frontTile => _front;

  bool get breakable => hardness >= 0;

  /// Czy blok otwiera jakiś interfejs po kliknięciu.
  /// Wariant tego bloku z zapalonym paleniskiem; `null`, gdy blok nie płonie.
  BlockType? get litVariant => _byName(_litVariantName);

  /// Wariant wygaszony; `null`, gdy blok nie ma takiego stanu.
  BlockType? get unlitVariant => _byName(_unlitVariantName);

  /// Czy blok ma dwa stany palenia (czyli jest piecem).
  bool get hasLitVariant =>
      _litVariantName != null || _unlitVariantName != null;

  static BlockType? _byName(String? name) =>
      name == null ? null : BlockType.values.firstWhere((b) => b.name == name);

  static final List<BlockType> byId = BlockType.values;
}
