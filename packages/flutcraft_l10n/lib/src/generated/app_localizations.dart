import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pl'),
  ];

  /// block name: air
  ///
  /// In en, this message translates to:
  /// **'Air'**
  String get blockAir;

  /// block name: grass
  ///
  /// In en, this message translates to:
  /// **'Grass'**
  String get blockGrass;

  /// block name: dirt
  ///
  /// In en, this message translates to:
  /// **'Dirt'**
  String get blockDirt;

  /// block name: stone
  ///
  /// In en, this message translates to:
  /// **'Stone'**
  String get blockStone;

  /// block name: cobblestone
  ///
  /// In en, this message translates to:
  /// **'Cobblestone'**
  String get blockCobblestone;

  /// block name: sand
  ///
  /// In en, this message translates to:
  /// **'Sand'**
  String get blockSand;

  /// block name: gravel
  ///
  /// In en, this message translates to:
  /// **'Gravel'**
  String get blockGravel;

  /// block name: log
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get blockLog;

  /// block name: leaves
  ///
  /// In en, this message translates to:
  /// **'Leaves'**
  String get blockLeaves;

  /// block name: planks
  ///
  /// In en, this message translates to:
  /// **'Planks'**
  String get blockPlanks;

  /// block name: brick
  ///
  /// In en, this message translates to:
  /// **'Bricks'**
  String get blockBrick;

  /// block name: coalOre
  ///
  /// In en, this message translates to:
  /// **'Coal Ore'**
  String get blockCoalOre;

  /// block name: ironOre
  ///
  /// In en, this message translates to:
  /// **'Iron Ore'**
  String get blockIronOre;

  /// block name: craftingTable
  ///
  /// In en, this message translates to:
  /// **'Crafting Table'**
  String get blockCraftingTable;

  /// block name: furnace
  ///
  /// In en, this message translates to:
  /// **'Furnace'**
  String get blockFurnace;

  /// block name: furnaceLit
  ///
  /// In en, this message translates to:
  /// **'Furnace'**
  String get blockFurnaceLit;

  /// block name: bedrock
  ///
  /// In en, this message translates to:
  /// **'Bedrock'**
  String get blockBedrock;

  /// item name: stick
  ///
  /// In en, this message translates to:
  /// **'Stick'**
  String get itemStick;

  /// item name: coal
  ///
  /// In en, this message translates to:
  /// **'Coal'**
  String get itemCoal;

  /// item name: rawIron
  ///
  /// In en, this message translates to:
  /// **'Raw Iron'**
  String get itemRawIron;

  /// item name: ironIngot
  ///
  /// In en, this message translates to:
  /// **'Iron Ingot'**
  String get itemIronIngot;

  /// item name: bone
  ///
  /// In en, this message translates to:
  /// **'Bone'**
  String get itemBone;

  /// item name: string
  ///
  /// In en, this message translates to:
  /// **'String'**
  String get itemString;

  /// item name: gunpowder
  ///
  /// In en, this message translates to:
  /// **'Gunpowder'**
  String get itemGunpowder;

  /// item name: arrow
  ///
  /// In en, this message translates to:
  /// **'Arrow'**
  String get itemArrow;

  /// item name: woodenPickaxe
  ///
  /// In en, this message translates to:
  /// **'Wooden Pickaxe'**
  String get itemWoodenPickaxe;

  /// item name: stonePickaxe
  ///
  /// In en, this message translates to:
  /// **'Stone Pickaxe'**
  String get itemStonePickaxe;

  /// item name: ironPickaxe
  ///
  /// In en, this message translates to:
  /// **'Iron Pickaxe'**
  String get itemIronPickaxe;

  /// item name: woodenSword
  ///
  /// In en, this message translates to:
  /// **'Wooden Sword'**
  String get itemWoodenSword;

  /// item name: stoneSword
  ///
  /// In en, this message translates to:
  /// **'Stone Sword'**
  String get itemStoneSword;

  /// item name: ironSword
  ///
  /// In en, this message translates to:
  /// **'Iron Sword'**
  String get itemIronSword;

  /// mob name: zombie
  ///
  /// In en, this message translates to:
  /// **'Zombie'**
  String get mobZombie;

  /// mob name: skeleton
  ///
  /// In en, this message translates to:
  /// **'Skeleton'**
  String get mobSkeleton;

  /// mob name: spider
  ///
  /// In en, this message translates to:
  /// **'Spider'**
  String get mobSpider;

  /// mob name: creeper
  ///
  /// In en, this message translates to:
  /// **'Creeper'**
  String get mobCreeper;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Flutcraft'**
  String get appTitle;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Generating world…'**
  String get loadingWorld;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get screenInventory;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Crafting Table'**
  String get screenCraftingTable;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Furnace'**
  String get screenFurnace;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Recipe Book'**
  String get screenRecipes;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get recipesLink;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Place a crafting table to unlock the 3x3 grid'**
  String get craftingTableHint;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'input'**
  String get furnaceInput;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'fuel'**
  String get furnaceFuel;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'You died'**
  String get youDied;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Respawn'**
  String get respawn;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Target: ---'**
  String get noTarget;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Flying'**
  String get flying;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'MINE'**
  String get buttonMine;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'USE'**
  String get buttonUse;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'JUMP'**
  String get buttonJump;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'FLY'**
  String get buttonFly;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'In your inventory (2x2 grid)'**
  String get recipesInInventory;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'At a crafting table (3x3)'**
  String get recipesAtTable;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'You have the ingredients'**
  String get haveIngredients;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'You have the ingredients — use a table'**
  String get haveIngredientsTable;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Inventory full'**
  String get msgInventoryFull;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'That is not a block — pick one from the hotbar'**
  String get msgNotABlock;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'You cannot place a block inside yourself'**
  String get msgInsidePlayer;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'A mob is standing there'**
  String get msgInsideMob;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'A creeper exploded!'**
  String get msgCreeperExploded;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Flight: on'**
  String get msgFlightOn;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Flight: off'**
  String get msgFlightOff;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Respawned at the starting point'**
  String get msgRespawned;

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'You need a better pickaxe for {block}'**
  String msgToolTooWeak(String block);

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Defeated: {mob}'**
  String msgMobDefeated(String mob);

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Defeated: {mob} → {loot}'**
  String msgMobDefeatedWithLoot(String mob, String loot);

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'{item} x{count}'**
  String stackOf(String item, int count);

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'{fps} FPS'**
  String hudFps(String fps);

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Target: {name}'**
  String hudTarget(String name);

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Chunks: {done}/{total}'**
  String hudChunks(int done, int total);

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'Missing: {list}'**
  String missingIngredients(String list);

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No mobs} =1{1 mob} other{{count} mobs}}'**
  String hudMobs(int count);

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{and 1 more} other{and {count} more}}'**
  String andMore(int count);

  /// UI text
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 second each} other{{count} seconds each}}'**
  String smeltSeconds(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
