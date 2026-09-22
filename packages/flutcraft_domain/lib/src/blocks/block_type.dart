// ignore_for_file: prefer_initializing_formals
import 'tile.dart';

/// The kind of tool that speeds up mining a block.
enum ToolType { none, pickaxe, axe, shovel, sword }

/// Every block in the prototype. `air` is the empty one and is never
/// reaches the mesh.
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

  /// Base mining time in seconds; a negative value means unbreakable.
  final double hardness;

  /// The tool that gives a speed bonus.
  final ToolType tool;

  /// Whether the block stops movement and hides its neighbours.
  final bool solid;

  /// The lowest pickaxe tier that makes this block drop anything:
  /// 0 a bare hand, 1 wooden, 2 stone, 3 iron.
  final int requiredTier;

  // Variants are held by name, because an enum cannot refer to its own
  // values in a const constructor.
  final String? _litVariantName;
  final String? _unlitVariantName;

  final Tile _top;
  final Tile? _side;
  final Tile? _bottom;
  final Tile? _front;

  Tile get topTile => _top;
  Tile get sideTile => _side ?? _top;
  Tile get bottomTile => _bottom ?? _side ?? _top;

  /// The distinguished face, such as a furnace front; `null` when the block looks the same
  /// ze wszystkich stron.
  Tile? get frontTile => _front;

  bool get breakable => hardness >= 0;

  /// Whether using the block opens an interface.
  /// This block's lit variant; `null` when it does not burn.
  BlockType? get litVariant => _byName(_litVariantName);

  /// The unlit variant; `null` when the block has no such state.
  BlockType? get unlitVariant => _byName(_unlitVariantName);

  /// Whether the block has a lit and an unlit state — whether it is a furnace.
  bool get hasLitVariant =>
      _litVariantName != null || _unlitVariantName != null;

  static BlockType? _byName(String? name) =>
      name == null ? null : BlockType.values.firstWhere((b) => b.name == name);

  static final List<BlockType> byId = BlockType.values;
}
