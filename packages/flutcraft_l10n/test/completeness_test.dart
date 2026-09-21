import 'dart:convert';
import 'dart:io';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_l10n/flutcraft_l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wszystkie warianty zdarzeń, jakie gra potrafi wyprodukować.
const sampleEvents = <GameEvent>[
  BlockBroken(BlockPos(0, 0, 0), BlockType.stone, []),
  ToolTooWeak(BlockType.ironOre),
  InventoryFull(ItemType.dirt),
  PlacementRejected(PlacementRejection.notABlock),
  PlacementRejected(PlacementRejection.insidePlayer),
  PlacementRejected(PlacementRejection.insideMob),
  MobKilled(MobKind.zombie, []),
  MobKilled(MobKind.skeleton, [ItemStack(ItemType.bone, 2)]),
  CreeperExploded(),
  FlightToggled(true),
  FlightToggled(false),
  PlayerRespawned(),
];

void main() {
  group('Każdy język ma komplet tłumaczeń', () {
    for (final locale in AppLocalizations.supportedLocales) {
      group(locale.languageCode, () {
        late GameStrings strings;

        setUpAll(() async {
          strings = GameStrings(await AppLocalizations.delegate.load(locale));
        });

        test('każdy blok ma nazwę', () {
          for (final block in BlockType.values) {
            expect(strings.blockName(block), isNotEmpty, reason: block.name);
          }
        });

        test('każdy przedmiot ma nazwę', () {
          for (final item in ItemType.values) {
            expect(strings.itemName(item), isNotEmpty, reason: item.name);
          }
        });

        test('każdy gatunek potwora ma nazwę', () {
          for (final kind in MobKind.values) {
            expect(strings.mobName(kind), isNotEmpty, reason: kind.name);
          }
        });

        test('każde zdarzenie da się opisać', () {
          for (final event in sampleEvents) {
            expect(
              () => strings.event(event),
              returnsNormally,
              reason: event.runtimeType.toString(),
            );
          }
        });

        test('każda trasa poza grą ma tytuł', () {
          for (final route in UiRoute.values) {
            if (route == UiRoute.none) continue;
            expect(strings.route(route), isNotEmpty, reason: route.name);
          }
        });

        test('nazwy przedmiotów-bloków zgadzają się z nazwami bloków', () {
          for (final item in ItemType.values) {
            final block = item.block;
            if (block == null) continue;
            expect(
              strings.itemName(item),
              strings.blockName(block),
              reason: '${item.name} vs ${block.name}',
            );
          }
        });
      });
    }
  });

  group('Higiena plików ARB', () {
    Map<String, dynamic> arb(String lang) =>
        json.decode(File('lib/l10n/app_$lang.arb').readAsStringSync())
            as Map<String, dynamic>;

    Set<String> keysOf(Map<String, dynamic> data) =>
        data.keys.where((k) => !k.startsWith('@')).toSet();

    test('polski ma dokładnie te same klucze co angielski', () {
      final en = keysOf(arb('en'));
      final pl = keysOf(arb('pl'));
      expect(pl.difference(en), isEmpty, reason: 'nadmiarowe w pl');
      expect(en.difference(pl), isEmpty, reason: 'brakujące w pl');
    });

    test('żaden tekst nie zawiera twardego łamania linii', () {
      // Łamanie dopasowane do jednego języka rozjeżdża się w drugim.
      for (final lang in ['en', 'pl']) {
        for (final entry in arb(lang).entries) {
          if (entry.key.startsWith('@')) continue;
          expect(
            entry.value as String,
            isNot(contains('\n')),
            reason: '$lang / ${entry.key}',
          );
        }
      }
    });

    test('angielski jest szablonem i ma opisy', () {
      final en = arb('en');
      for (final key in keysOf(en)) {
        expect(en, contains('@$key'), reason: 'brak metadanych dla $key');
      }
    });

    test('każdy zadeklarowany placeholder występuje w obu językach', () {
      // Czytamy deklaracje z metadanych, a nie z treści: wzorzec {nazwa}
      // łapałby też słowa wewnątrz form liczby mnogiej, np. =0{No mobs}.
      final en = arb('en');
      final pl = arb('pl');
      for (final key in keysOf(en)) {
        final meta = en['@\$key'] as Map<String, dynamic>?;
        final declared =
            (meta?['placeholders'] as Map<String, dynamic>?)?.keys ?? const [];
        for (final name in declared) {
          expect(en[key] as String, contains('{\$name'), reason: 'en/\$key');
          expect(pl[key] as String, contains('{\$name'), reason: 'pl/\$key');
        }
      }
    });
  });

  group('Liczba mnoga', () {
    test('polski odmienia potwory przez trzy formy', () async {
      final t = await AppLocalizations.delegate.load(const Locale('pl'));
      expect(t.hudMobs(1), contains('potwór'));
      expect(t.hudMobs(2), contains('potwory'));
      expect(t.hudMobs(5), contains('potworów'));
    });

    test('angielski ma dwie formy', () async {
      final t = await AppLocalizations.delegate.load(const Locale('en'));
      expect(t.hudMobs(1), contains('1 mob'));
      expect(t.hudMobs(5), contains('5 mobs'));
    });
  });
}
