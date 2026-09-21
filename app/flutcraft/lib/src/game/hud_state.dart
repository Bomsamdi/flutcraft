
import 'package:flutcraft_domain/flutcraft_domain.dart';

/// Migawka stanu gry dla warstwy HUD (Flutter).
///
/// Zawiera tylko wartości skalarne; żywe kolekcje (ekwipunek, siatka
/// craftingu, piec) UI czyta bezpośrednio z gry, a [revision] wymusza
/// przebudowę widgetów po każdej zmianie.
class HudSnapshot {
  const HudSnapshot({
    required this.hotbar,
    required this.selected,
    required this.breakProgress,
    required this.aim,
    required this.position,
    required this.fps,
    required this.flying,
    required this.chunksPending,
    required this.chunksTotal,
    required this.event,
    required this.health,
    required this.maxHealth,
    required this.hurtFlash,
    required this.mobCount,
    required this.screen,
    required this.revision,
    this.targetMob,
  });

  final List<ItemStack?> hotbar;
  final int selected;

  /// 0..1 - postęp rozbijania aktualnego bloku.
  final double breakProgress;

  /// Co jest pod celownikiem; tekst dobiera UI.
  final AimView aim;

  final (int, int, int) position;
  final double fps;
  final bool flying;
  final int chunksPending;
  final int chunksTotal;

  /// Ostatnie zdarzenie warte pokazania; tekst dobiera UI.
  final GameEvent? event;

  final int health;
  final int maxHealth;

  /// > 0 zaraz po otrzymaniu ciosu; HUD mruga wtedy na czerwono.
  final double hurtFlash;

  final int mobCount;
  final UiRoute screen;

  /// Potwór pod celownikiem - HUD pokazuje wtedy jego pasek życia.
  final MobAimView? targetMob;

  /// Licznik zmian stanu ekwipunku - klucz do odświeżania UI.
  final int revision;

  ItemStack? get held =>
      selected < hotbar.length ? hotbar[selected] : null;
}
