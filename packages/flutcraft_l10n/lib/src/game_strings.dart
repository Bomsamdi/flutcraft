import 'package:flutcraft_domain/flutcraft_domain.dart';

import 'generated/app_localizations.dart';

/// Display names for domain values.
///
/// The domain enums carry no labels — their `name` is the technical key and
/// this is where it becomes something a player reads. Every switch below is
/// exhaustive on purpose: adding a block, item, mob or event will not compile
/// until it has a translation, which is a far better reminder than a code
/// review.
class GameStrings {
  const GameStrings(this._t);

  final AppLocalizations _t;

  String blockName(BlockType block) => switch (block) {
    BlockType.air => _t.blockAir,
    BlockType.grass => _t.blockGrass,
    BlockType.dirt => _t.blockDirt,
    BlockType.stone => _t.blockStone,
    BlockType.cobblestone => _t.blockCobblestone,
    BlockType.sand => _t.blockSand,
    BlockType.gravel => _t.blockGravel,
    BlockType.log => _t.blockLog,
    BlockType.leaves => _t.blockLeaves,
    BlockType.planks => _t.blockPlanks,
    BlockType.brick => _t.blockBrick,
    BlockType.coalOre => _t.blockCoalOre,
    BlockType.ironOre => _t.blockIronOre,
    BlockType.craftingTable => _t.blockCraftingTable,
    BlockType.furnace => _t.blockFurnace,
    BlockType.furnaceLit => _t.blockFurnaceLit,
    BlockType.bedrock => _t.blockBedrock,
  };

  String itemName(ItemType item) => switch (item) {
    ItemType.grass => _t.blockGrass,
    ItemType.dirt => _t.blockDirt,
    ItemType.stone => _t.blockStone,
    ItemType.cobblestone => _t.blockCobblestone,
    ItemType.sand => _t.blockSand,
    ItemType.gravel => _t.blockGravel,
    ItemType.log => _t.blockLog,
    ItemType.leaves => _t.blockLeaves,
    ItemType.planks => _t.blockPlanks,
    ItemType.brick => _t.blockBrick,
    ItemType.coalOre => _t.blockCoalOre,
    ItemType.ironOre => _t.blockIronOre,
    ItemType.craftingTable => _t.blockCraftingTable,
    ItemType.furnace => _t.blockFurnace,
    ItemType.stick => _t.itemStick,
    ItemType.coal => _t.itemCoal,
    ItemType.rawIron => _t.itemRawIron,
    ItemType.ironIngot => _t.itemIronIngot,
    ItemType.bone => _t.itemBone,
    ItemType.string => _t.itemString,
    ItemType.gunpowder => _t.itemGunpowder,
    ItemType.arrow => _t.itemArrow,
    ItemType.woodenPickaxe => _t.itemWoodenPickaxe,
    ItemType.stonePickaxe => _t.itemStonePickaxe,
    ItemType.ironPickaxe => _t.itemIronPickaxe,
    ItemType.woodenSword => _t.itemWoodenSword,
    ItemType.stoneSword => _t.itemStoneSword,
    ItemType.ironSword => _t.itemIronSword,
  };

  String mobName(MobKind kind) => switch (kind) {
    MobKind.zombie => _t.mobZombie,
    MobKind.skeleton => _t.mobSkeleton,
    MobKind.spider => _t.mobSpider,
    MobKind.creeper => _t.mobCreeper,
  };

  /// A stack as the player sees it, e.g. "Bone x2".
  String stack(ItemStack stack) =>
      _t.stackOf(itemName(stack.type), stack.count);

  /// The HUD line for an event, or an empty string when it is silent.
  String event(GameEvent event) => switch (event) {
    BlockBroken() => '',
    ToolTooWeak(:final block) => _t.msgToolTooWeak(blockName(block)),
    InventoryFull() => _t.msgInventoryFull,
    PlacementRejected(:final reason) => switch (reason) {
      PlacementRejection.notABlock => _t.msgNotABlock,
      PlacementRejection.insidePlayer => _t.msgInsidePlayer,
      PlacementRejection.insideMob => _t.msgInsideMob,
    },
    MobKilled(:final kind, :final loot) =>
      loot.isEmpty
          ? _t.msgMobDefeated(mobName(kind))
          : _t.msgMobDefeatedWithLoot(mobName(kind), _lootList(loot)),
    CreeperExploded() => _t.msgCreeperExploded,
    FlightToggled(:final enabled) => enabled ? _t.msgFlightOn : _t.msgFlightOff,
    PlayerRespawned() => _t.msgRespawned,
  };

  /// The title of a screen.
  String route(UiRoute route) => switch (route) {
    UiRoute.none => '',
    UiRoute.inventory => _t.screenInventory,
    UiRoute.craftingTable => _t.screenCraftingTable,
    UiRoute.furnace => _t.screenFurnace,
    UiRoute.recipes => _t.screenRecipes,
    UiRoute.dead => _t.youDied,
  };

  String _lootList(List<ItemStack> loot) => loot.map(stack).join(', ');

  AppLocalizations get raw => _t;
}
