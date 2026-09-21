import 'dart:math';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';

void main() {
  group('LootEntry', () {
    test('pewny wpis zawsze daje ten sam stos', () {
      final rng = Random(1);
      final stack = const LootEntry(ItemType.coal).roll(rng);
      expect(stack?.type, ItemType.coal);
      expect(stack?.count, 1);
    });

    test('zakres trzyma się granic', () {
      final rng = Random(7);
      for (var i = 0; i < 200; i++) {
        final stack = const LootEntry(ItemType.bone, min: 1, max: 3).roll(rng);
        expect(stack!.count, inInclusiveRange(1, 3));
      }
    });

    test('szansa poniżej jedynki czasem nie daje nic', () {
      final rng = Random(3);
      final rolls = List.generate(
        400,
        (_) => const LootEntry(ItemType.ironIngot, chance: 0.12).roll(rng),
      );
      final hits = rolls.whereType<ItemStack>().length;
      expect(hits, greaterThan(0));
      expect(hits, lessThan(rolls.length));
    });

    test('odrzuca bezsensowne konfiguracje', () {
      expect(() => LootEntry(ItemType.coal, min: 0), throwsA(isA<AssertionError>()));
      expect(
        () => LootEntry(ItemType.coal, min: 3, max: 1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => LootEntry(ItemType.coal, chance: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('LootTable', () {
    test('pusta tabela nie daje nic', () {
      expect(LootTable.empty.roll(Random(1)), isEmpty);
      expect(LootTable.empty.isEmpty, isTrue);
    });

    test('single daje dokładnie jedną sztukę', () {
      final drops = LootTable.single(ItemType.planks).roll(Random(1));
      expect(drops, hasLength(1));
      expect(drops.single.count, 1);
    });

    test('kilka wpisów rzuca się niezależnie', () {
      final table = LootTable([
        const LootEntry(ItemType.bone),
        const LootEntry(ItemType.arrow, chance: 0.001),
      ]);
      final drops = table.roll(Random(5));
      expect(drops.map((d) => d.type), contains(ItemType.bone));
    });
  });

  group('Dropy potworów i bloków dzielą jeden typ', () {
    test('każdy gatunek ma tabelę lootu', () {
      for (final kind in MobKind.values) {
        expect(kind.loot, isA<LootTable>(), reason: kind.name);
      }
    });

    test('szkielet gubi kości, pająk nić', () {
      final rng = Random(2);
      final bones = MobKind.skeleton.loot.roll(rng).map((d) => d.type);
      expect(bones, contains(ItemType.bone));
      expect(
        MobKind.spider.loot.roll(rng).map((d) => d.type),
        contains(ItemType.string),
      );
    });

    test('zombie gubi żelazo rzadko, ale gubi', () {
      final rng = Random(11);
      final drops = [
        for (var i = 0; i < 400; i++) ...MobKind.zombie.loot.roll(rng),
      ];
      expect(drops, isNotEmpty);
      expect(drops.length, lessThan(120), reason: 'szansa ma być niska');
      expect(drops.every((d) => d.type == ItemType.ironIngot), isTrue);
    });
  });
}
