import 'package:flutcraft_domain/flutcraft_domain.dart';

/// Turns a [GameEvent] into the line shown in the HUD.
///
/// The single place in the app where a game event becomes text. When
/// localisation lands this function moves into the l10n package and starts
/// taking an `AppLocalizations` — nothing in the simulation has to change,
/// because the simulation never produced a string in the first place.
///
/// The switch is deliberately exhaustive: a new event variant will not
/// compile until it has a message.
String describeEvent(GameEvent event) => switch (event) {
  BlockBroken() => '',
  ToolTooWeak(:final block) =>
    'Potrzebujesz lepszego kilofa: ${block.label}',
  InventoryFull(:final item) => 'Ekwipunek pełny: ${item.label}',
  PlacementRejected(:final reason) => switch (reason) {
    PlacementRejection.notABlock => 'To nie jest blok - wybierz blok z paska',
    PlacementRejection.insidePlayer => 'Nie postawisz bloku w sobie',
    PlacementRejection.insideMob => 'Potwór stoi w tym miejscu',
  },
  MobKilled(:final kind, :final loot) => loot.isEmpty
      ? 'Pokonano: ${kind.label}'
      : 'Pokonano: ${kind.label} → ${_describeLoot(loot)}',
  CreeperExploded() => 'Creeper wybuchł!',
  FlightToggled(:final enabled) =>
    enabled ? 'Latanie: włączone' : 'Latanie: wyłączone',
  PlayerRespawned() => 'Odrodzono w punkcie startowym',
};

String _describeLoot(List<ItemStack> loot) =>
    loot.map((drop) => '${drop.type.label} x${drop.count}').join(', ');
