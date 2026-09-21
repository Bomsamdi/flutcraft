// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get blockAir => 'Air';

  @override
  String get blockGrass => 'Grass';

  @override
  String get blockDirt => 'Dirt';

  @override
  String get blockStone => 'Stone';

  @override
  String get blockCobblestone => 'Cobblestone';

  @override
  String get blockSand => 'Sand';

  @override
  String get blockGravel => 'Gravel';

  @override
  String get blockLog => 'Log';

  @override
  String get blockLeaves => 'Leaves';

  @override
  String get blockPlanks => 'Planks';

  @override
  String get blockBrick => 'Bricks';

  @override
  String get blockCoalOre => 'Coal Ore';

  @override
  String get blockIronOre => 'Iron Ore';

  @override
  String get blockCraftingTable => 'Crafting Table';

  @override
  String get blockFurnace => 'Furnace';

  @override
  String get blockFurnaceLit => 'Furnace';

  @override
  String get blockBedrock => 'Bedrock';

  @override
  String get itemStick => 'Stick';

  @override
  String get itemCoal => 'Coal';

  @override
  String get itemRawIron => 'Raw Iron';

  @override
  String get itemIronIngot => 'Iron Ingot';

  @override
  String get itemBone => 'Bone';

  @override
  String get itemString => 'String';

  @override
  String get itemGunpowder => 'Gunpowder';

  @override
  String get itemArrow => 'Arrow';

  @override
  String get itemWoodenPickaxe => 'Wooden Pickaxe';

  @override
  String get itemStonePickaxe => 'Stone Pickaxe';

  @override
  String get itemIronPickaxe => 'Iron Pickaxe';

  @override
  String get itemWoodenSword => 'Wooden Sword';

  @override
  String get itemStoneSword => 'Stone Sword';

  @override
  String get itemIronSword => 'Iron Sword';

  @override
  String get mobZombie => 'Zombie';

  @override
  String get mobSkeleton => 'Skeleton';

  @override
  String get mobSpider => 'Spider';

  @override
  String get mobCreeper => 'Creeper';

  @override
  String get appTitle => 'Flutcraft';

  @override
  String get loadingWorld => 'Generating world…';

  @override
  String get screenInventory => 'Inventory';

  @override
  String get screenCraftingTable => 'Crafting Table';

  @override
  String get screenFurnace => 'Furnace';

  @override
  String get screenRecipes => 'Recipe Book';

  @override
  String get recipesLink => 'Recipes';

  @override
  String get craftingTableHint =>
      'Place a crafting table to unlock the 3x3 grid';

  @override
  String get furnaceInput => 'input';

  @override
  String get furnaceFuel => 'fuel';

  @override
  String get youDied => 'You died';

  @override
  String get respawn => 'Respawn';

  @override
  String get noTarget => 'Target: ---';

  @override
  String get flying => 'Flying';

  @override
  String get buttonMine => 'MINE';

  @override
  String get buttonUse => 'USE';

  @override
  String get buttonJump => 'JUMP';

  @override
  String get buttonFly => 'FLY';

  @override
  String get recipesInInventory => 'In your inventory (2x2 grid)';

  @override
  String get recipesAtTable => 'At a crafting table (3x3)';

  @override
  String get haveIngredients => 'You have the ingredients';

  @override
  String get haveIngredientsTable => 'You have the ingredients — use a table';

  @override
  String get msgInventoryFull => 'Inventory full';

  @override
  String get msgNotABlock => 'That is not a block — pick one from the hotbar';

  @override
  String get msgInsidePlayer => 'You cannot place a block inside yourself';

  @override
  String get msgInsideMob => 'A mob is standing there';

  @override
  String get msgCreeperExploded => 'A creeper exploded!';

  @override
  String get msgFlightOn => 'Flight: on';

  @override
  String get msgFlightOff => 'Flight: off';

  @override
  String get msgRespawned => 'Respawned at the starting point';

  @override
  String msgToolTooWeak(String block) {
    return 'You need a better pickaxe for $block';
  }

  @override
  String msgMobDefeated(String mob) {
    return 'Defeated: $mob';
  }

  @override
  String msgMobDefeatedWithLoot(String mob, String loot) {
    return 'Defeated: $mob → $loot';
  }

  @override
  String stackOf(String item, int count) {
    return '$item x$count';
  }

  @override
  String hudFps(String fps) {
    return '$fps FPS';
  }

  @override
  String hudTarget(String name) {
    return 'Target: $name';
  }

  @override
  String hudChunks(int done, int total) {
    return 'Chunks: $done/$total';
  }

  @override
  String missingIngredients(String list) {
    return 'Missing: $list';
  }

  @override
  String hudMobs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mobs',
      one: '1 mob',
      zero: 'No mobs',
    );
    return '$_temp0';
  }

  @override
  String andMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count more',
      one: 'and 1 more',
    );
    return '$_temp0';
  }

  @override
  String smeltSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds each',
      one: '1 second each',
    );
    return '$_temp0';
  }

  @override
  String get cursorEmptyHint =>
      'Tap to pick up. Hold or right-click to take half a stack.';

  @override
  String cursorHolding(String stack) {
    return 'Holding: $stack (hold a slot to place one)';
  }

  @override
  String get helpTitle => 'Controls';

  @override
  String get helpCombatTitle => 'Combat';

  @override
  String get helpRecipesHint =>
      'The full recipe list is in the book (press B or the book icon).';

  @override
  String get helpCombatBody =>
      'Aim at a mob: the crosshair turns into a red cross and a health bar appears above it. Then hold the same button you use for mining. A sword hits harder than a pickaxe, a pickaxe harder than a fist.';

  @override
  String get helpFooter =>
      'A stone pickaxe is required for iron ore. Beware of creepers — the blast destroys terrain. Tap anywhere to close.';

  @override
  String get helpMove => 'WASD / joystick';

  @override
  String get helpMoveAction => 'walk';

  @override
  String get helpLook => 'Drag with finger or mouse';

  @override
  String get helpLookAction => 'look around';

  @override
  String get helpMineKey => 'Hold / MINE';

  @override
  String get helpMineAction => 'mine blocks and hit mobs';

  @override
  String get helpUseKey => 'Right click / USE / R';

  @override
  String get helpUseAction => 'place and open';

  @override
  String get helpInventoryKey => 'E / backpack icon';

  @override
  String get helpInventoryAction => 'inventory and crafting';

  @override
  String get helpRecipesKey => 'B / book icon';

  @override
  String get helpRecipesAction => 'recipe book';

  @override
  String get helpHotbarKey => '1-9, scroll';

  @override
  String get helpHotbarAction => 'select item';

  @override
  String get helpSplitKey => 'Right click / hold a slot';

  @override
  String get helpSplitAction => 'split a stack in half';

  @override
  String get helpJumpKey => 'Space / JUMP';

  @override
  String get helpJumpAction => 'jump';

  @override
  String get helpSprintKey => 'Shift';

  @override
  String get helpSprintAction => 'sprint (or descend while flying)';

  @override
  String get helpFlyKey => 'F / FLY';

  @override
  String get helpFlyAction => 'flight mode';

  @override
  String get furnaceHint => 'Fuel: coal. Smelts: raw iron, sand, logs.';

  @override
  String get respawnWithKey => 'Respawn  (R)';

  @override
  String get buttonMineHit => 'MINE/HIT';
}
