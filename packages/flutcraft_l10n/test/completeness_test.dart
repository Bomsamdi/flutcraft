import 'dart:convert';
import 'dart:io';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_l10n/flutcraft_l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every event variant the game can produce.
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
  group('Every language is complete', () {
    for (final locale in AppLocalizations.supportedLocales) {
      group(locale.languageCode, () {
        late GameStrings strings;

        setUpAll(() async {
          strings = GameStrings(await AppLocalizations.delegate.load(locale));
        });

        test('every block has a name', () {
          for (final block in BlockType.values) {
            expect(strings.blockName(block), isNotEmpty, reason: block.name);
          }
        });

        test('every item has a name', () {
          for (final item in ItemType.values) {
            expect(strings.itemName(item), isNotEmpty, reason: item.name);
          }
        });

        test('every mob species has a name', () {
          for (final kind in MobKind.values) {
            expect(strings.mobName(kind), isNotEmpty, reason: kind.name);
          }
        });

        test('every event can be worded', () {
          for (final event in sampleEvents) {
            expect(
              () => strings.event(event),
              returnsNormally,
              reason: event.runtimeType.toString(),
            );
          }
        });

        test('every route but the game itself has a title', () {
          for (final route in UiRoute.values) {
            if (route == UiRoute.none) continue;
            expect(strings.route(route), isNotEmpty, reason: route.name);
          }
        });

        test('block items are named the same as their blocks', () {
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

  group('ARB hygiene', () {
    Map<String, dynamic> arb(String lang) =>
        json.decode(File('lib/l10n/app_$lang.arb').readAsStringSync())
            as Map<String, dynamic>;

    Set<String> keysOf(Map<String, dynamic> data) =>
        data.keys.where((k) => !k.startsWith('@')).toSet();

    test('Polish has exactly the same keys as English', () {
      final en = keysOf(arb('en'));
      final pl = keysOf(arb('pl'));
      expect(pl.difference(en), isEmpty, reason: 'nadmiarowe w pl');
      expect(en.difference(pl), isEmpty, reason: 'missing from pl');
    });

    test('no string contains a hard line break', () {
      // A break tuned to one language falls apart in the other.
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

    test('English is the template and carries the descriptions', () {
      final en = arb('en');
      for (final key in keysOf(en)) {
        expect(en, contains('@$key'), reason: 'no metadata for $key');
      }
    });

    test('every declared placeholder appears in both languages', () {
      // Declarations come from the metadata, not the text: a {name} pattern
      // would also match words inside plural forms, such as =0{No mobs}.
      final en = arb('en');
      final pl = arb('pl');
      for (final key in keysOf(en)) {
        final meta = en['@$key'] as Map<String, dynamic>?;
        final declared =
            (meta?['placeholders'] as Map<String, dynamic>?)?.keys ?? const [];
        for (final name in declared) {
          expect(en[key] as String, contains('{$name'), reason: 'en/$key');
          expect(pl[key] as String, contains('{$name'), reason: 'pl/$key');
        }
      }
    });
  });

  group('Liczba mnoga', () {
    test('Polish declines mobs through three forms', () async {
      final t = await AppLocalizations.delegate.load(const Locale('pl'));
      expect(t.hudMobs(1), contains('potwór')); // polish-ok
      expect(t.hudMobs(2), contains('potwory')); // polish-ok
      expect(t.hudMobs(5), contains('potworów')); // polish-ok
    });

    test('angielski ma dwie formy', () async {
      final t = await AppLocalizations.delegate.load(const Locale('en'));
      expect(t.hudMobs(1), contains('1 mob'));
      expect(t.hudMobs(5), contains('5 mobs'));
    });
  });
}
