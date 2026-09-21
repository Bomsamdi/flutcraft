// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get blockAir => 'Powietrze';

  @override
  String get blockGrass => 'Trawa';

  @override
  String get blockDirt => 'Ziemia';

  @override
  String get blockStone => 'Kamień';

  @override
  String get blockCobblestone => 'Bruk';

  @override
  String get blockSand => 'Piasek';

  @override
  String get blockGravel => 'Żwir';

  @override
  String get blockLog => 'Kłoda';

  @override
  String get blockLeaves => 'Liście';

  @override
  String get blockPlanks => 'Deski';

  @override
  String get blockBrick => 'Cegły';

  @override
  String get blockCoalOre => 'Ruda węgla';

  @override
  String get blockIronOre => 'Ruda żelaza';

  @override
  String get blockCraftingTable => 'Stół rzemieślniczy';

  @override
  String get blockFurnace => 'Piec';

  @override
  String get blockFurnaceLit => 'Piec';

  @override
  String get blockBedrock => 'Skała macierzysta';

  @override
  String get itemStick => 'Patyk';

  @override
  String get itemCoal => 'Węgiel';

  @override
  String get itemRawIron => 'Surowe żelazo';

  @override
  String get itemIronIngot => 'Sztabka żelaza';

  @override
  String get itemBone => 'Kość';

  @override
  String get itemString => 'Nić';

  @override
  String get itemGunpowder => 'Proch';

  @override
  String get itemArrow => 'Strzała';

  @override
  String get itemWoodenPickaxe => 'Drewniany kilof';

  @override
  String get itemStonePickaxe => 'Kamienny kilof';

  @override
  String get itemIronPickaxe => 'Żelazny kilof';

  @override
  String get itemWoodenSword => 'Drewniany miecz';

  @override
  String get itemStoneSword => 'Kamienny miecz';

  @override
  String get itemIronSword => 'Żelazny miecz';

  @override
  String get mobZombie => 'Zombie';

  @override
  String get mobSkeleton => 'Szkielet';

  @override
  String get mobSpider => 'Pająk';

  @override
  String get mobCreeper => 'Creeper';

  @override
  String get appTitle => 'Flutcraft';

  @override
  String get loadingWorld => 'Generowanie świata…';

  @override
  String get screenInventory => 'Ekwipunek';

  @override
  String get screenCraftingTable => 'Stół rzemieślniczy';

  @override
  String get screenFurnace => 'Piec';

  @override
  String get screenRecipes => 'Księga przepisów';

  @override
  String get recipesLink => 'Przepisy';

  @override
  String get craftingTableHint =>
      'Postaw stół rzemieślniczy, aby odblokować siatkę 3x3';

  @override
  String get furnaceInput => 'wsad';

  @override
  String get furnaceFuel => 'paliwo';

  @override
  String get youDied => 'Zginąłeś';

  @override
  String get respawn => 'Odrodź się';

  @override
  String get noTarget => 'Cel: ---';

  @override
  String get flying => 'Latanie';

  @override
  String get buttonMine => 'KOP';

  @override
  String get buttonUse => 'UŻYJ';

  @override
  String get buttonJump => 'SKOK';

  @override
  String get buttonFly => 'LOT';

  @override
  String get recipesInInventory => 'W ekwipunku (siatka 2x2)';

  @override
  String get recipesAtTable => 'Na stole rzemieślniczym (3x3)';

  @override
  String get haveIngredients => 'Masz składniki';

  @override
  String get haveIngredientsTable => 'Masz składniki - ułóż na stole';

  @override
  String get msgInventoryFull => 'Ekwipunek pełny';

  @override
  String get msgNotABlock => 'To nie jest blok - wybierz blok z paska';

  @override
  String get msgInsidePlayer => 'Nie postawisz bloku w sobie';

  @override
  String get msgInsideMob => 'Potwór stoi w tym miejscu';

  @override
  String get msgCreeperExploded => 'Creeper wybuchł!';

  @override
  String get msgFlightOn => 'Latanie: włączone';

  @override
  String get msgFlightOff => 'Latanie: wyłączone';

  @override
  String get msgRespawned => 'Odrodzono w punkcie startowym';

  @override
  String msgToolTooWeak(String block) {
    return 'Potrzebujesz lepszego kilofa: $block';
  }

  @override
  String msgMobDefeated(String mob) {
    return 'Pokonano: $mob';
  }

  @override
  String msgMobDefeatedWithLoot(String mob, String loot) {
    return 'Pokonano: $mob → $loot';
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
    return 'Cel: $name';
  }

  @override
  String hudChunks(int done, int total) {
    return 'Chunki: $done/$total';
  }

  @override
  String missingIngredients(String list) {
    return 'Brakuje: $list';
  }

  @override
  String hudMobs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count potworów',
      few: '$count potwory',
      one: '1 potwór',
      zero: 'Brak potworów',
    );
    return '$_temp0';
  }

  @override
  String andMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'i jeszcze $count',
      few: 'i jeszcze $count',
      one: 'i jeszcze 1',
    );
    return '$_temp0';
  }

  @override
  String smeltSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sekund za sztukę',
      few: '$count sekundy za sztukę',
      one: '1 sekunda za sztukę',
    );
    return '$_temp0';
  }

  @override
  String get cursorEmptyHint =>
      'Stuknij, aby podnieść. Przytrzymaj lub kliknij prawym, aby wziąć połowę stosu.';

  @override
  String cursorHolding(String stack) {
    return 'Trzymasz: $stack (przytrzymaj slot, aby położyć jedną sztukę)';
  }

  @override
  String get helpTitle => 'Sterowanie';

  @override
  String get helpCombatTitle => 'Walka';

  @override
  String get helpRecipesHint =>
      'Pełna lista przepisów jest w księdze (klawisz B albo ikona książki).';

  @override
  String get helpCombatBody =>
      'Wyceluj w potwora: celownik zmieni się w czerwony krzyżyk, a nad nim pojawi się pasek życia. Wtedy przytrzymaj ten sam przycisk co przy kopaniu. Miecz bije mocniej niż kilof, a kilof mocniej niż ręka.';

  @override
  String get helpFooter =>
      'Kamienny kilof jest potrzebny do rudy żelaza. Uważaj na creepery — wybuch niszczy teren. Dotknij ekranu, aby zamknąć.';

  @override
  String get helpMove => 'WSAD / joystick';

  @override
  String get helpMoveAction => 'chodzenie';

  @override
  String get helpLook => 'Przeciągnij palcem lub myszą';

  @override
  String get helpLookAction => 'rozglądanie';

  @override
  String get helpMineKey => 'Przytrzymaj / KOP';

  @override
  String get helpMineAction => 'kopanie i bicie potworów';

  @override
  String get helpUseKey => 'Prawy przycisk / UŻYJ / R';

  @override
  String get helpUseAction => 'stawianie i otwieranie';

  @override
  String get helpInventoryKey => 'E / ikona plecaka';

  @override
  String get helpInventoryAction => 'ekwipunek i crafting';

  @override
  String get helpRecipesKey => 'B / ikona książki';

  @override
  String get helpRecipesAction => 'księga przepisów';

  @override
  String get helpHotbarKey => '1-9, scroll';

  @override
  String get helpHotbarAction => 'wybór przedmiotu';

  @override
  String get helpSplitKey => 'Prawy przycisk / przytrzymanie slotu';

  @override
  String get helpSplitAction => 'podział stosu na pół';

  @override
  String get helpJumpKey => 'Spacja / SKOK';

  @override
  String get helpJumpAction => 'skok';

  @override
  String get helpSprintKey => 'Shift';

  @override
  String get helpSprintAction => 'sprint (lub w dół w locie)';

  @override
  String get helpFlyKey => 'F / LOT';

  @override
  String get helpFlyAction => 'tryb latania';

  @override
  String get furnaceHint =>
      'Paliwo: węgiel. Wytop: surowe żelazo, piasek, kłody.';

  @override
  String get respawnWithKey => 'Odrodź się  (R)';

  @override
  String get buttonMineHit => 'KOP/BIJ';
}
