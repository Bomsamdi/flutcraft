// ignore_for_file: prefer_initializing_formals
import 'tile.dart';

/// Rodzaj narzędzia, które przyspiesza kopanie danego bloku.
enum ToolType { none, pickaxe, axe, shovel, sword }

/// Wszystkie bloki prototypu. `air` jest blokiem "pustym" i nigdy nie
/// trafia do siatki.
enum BlockType {
  air(
    label: 'Powietrze',
    solid: false,
    hardness: 0,
    tool: ToolType.none,
    top: Tile.stone,
  ),
  grass(
    label: 'Trawa',
    hardness: 0.6,
    tool: ToolType.shovel,
    top: Tile.grassTop,
    side: Tile.grassSide,
    bottom: Tile.dirt,
  ),
  dirt(
    label: 'Ziemia',
    hardness: 0.5,
    tool: ToolType.shovel,
    top: Tile.dirt,
  ),
  stone(
    label: 'Kamień',
    hardness: 1.5,
    tool: ToolType.pickaxe,
    requiredTier: 1,
    top: Tile.stone,
  ),
  cobblestone(
    label: 'Bruk',
    hardness: 2,
    tool: ToolType.pickaxe,
    requiredTier: 1,
    top: Tile.cobblestone,
  ),
  sand(
    label: 'Piasek',
    hardness: 0.5,
    tool: ToolType.shovel,
    top: Tile.sand,
  ),
  gravel(
    label: 'Żwir',
    hardness: 0.6,
    tool: ToolType.shovel,
    top: Tile.gravel,
  ),
  log(
    label: 'Kłoda',
    hardness: 2,
    tool: ToolType.axe,
    top: Tile.logTop,
    side: Tile.logSide,
  ),
  leaves(
    label: 'Liście',
    hardness: 0.2,
    tool: ToolType.none,
    top: Tile.leaves,
  ),
  planks(
    label: 'Deski',
    hardness: 2,
    tool: ToolType.axe,
    top: Tile.planks,
  ),
  brick(
    label: 'Cegły',
    hardness: 2,
    tool: ToolType.pickaxe,
    requiredTier: 1,
    top: Tile.brick,
  ),
  coalOre(
    label: 'Ruda węgla',
    hardness: 3,
    tool: ToolType.pickaxe,
    requiredTier: 1,
    top: Tile.coalOre,
  ),
  ironOre(
    label: 'Ruda żelaza',
    hardness: 3,
    tool: ToolType.pickaxe,
    requiredTier: 2,
    top: Tile.ironOre,
  ),
  craftingTable(
    label: 'Stół rzemieślniczy',
    hardness: 2.5,
    tool: ToolType.axe,
    top: Tile.craftingTableTop,
    side: Tile.craftingTableSide,
    bottom: Tile.planks,
  ),
  furnace(
    label: 'Piec',
    hardness: 3.5,
    tool: ToolType.pickaxe,
    requiredTier: 1,
    top: Tile.furnaceTop,
    side: Tile.furnaceSide,
    front: Tile.furnaceFront,
  ),
  furnaceLit(
    label: 'Piec',
    hardness: 3.5,
    tool: ToolType.pickaxe,
    requiredTier: 1,
    top: Tile.furnaceTop,
    side: Tile.furnaceSide,
    front: Tile.furnaceFrontLit,
  ),
  bedrock(
    label: 'Skała macierzysta',
    hardness: -1,
    tool: ToolType.none,
    top: Tile.bedrock,
  );

  const BlockType({
    required this.label,
    required this.hardness,
    required this.tool,
    required Tile top,
    Tile? side,
    Tile? bottom,
    Tile? front,
    this.solid = true,
    this.requiredTier = 0,
  }) : _top = top,
       _side = side,
       _bottom = bottom,
       _front = front;

  /// Nazwa pokazywana w HUD.
  final String label;

  /// Czas bazowy kopania (sekundy). Ujemna wartość = bloku nie da się zbić.
  final double hardness;

  /// Narzędzie, które daje bonus prędkości.
  final ToolType tool;

  /// Czy blok blokuje ruch i zasłania sąsiadów.
  final bool solid;

  /// Minimalny poziom kilofa potrzebny, żeby blok cokolwiek upuścił.
  /// 0 = ręka wystarczy, 1 = drewniany, 2 = kamienny, 3 = żelazny.
  final int requiredTier;

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
  bool get interactive =>
      this == BlockType.craftingTable ||
      this == BlockType.furnace ||
      this == BlockType.furnaceLit;

  /// Czy to piec (w dowolnym stanie palenia).
  bool get isFurnace =>
      this == BlockType.furnace || this == BlockType.furnaceLit;

  static final List<BlockType> byId = BlockType.values;
}
