import 'package:flutcraft/src/ui/messages/event_messages.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('describeEvent', () {
    test('każde zdarzenie ma komunikat albo świadomie go nie ma', () {
      final events = <GameEvent>[
        const BlockBroken(BlockPos(0, 0, 0), BlockType.stone, []),
        const ToolTooWeak(BlockType.ironOre),
        const InventoryFull(ItemType.dirt),
        const PlacementRejected(PlacementRejection.notABlock),
        const PlacementRejected(PlacementRejection.insidePlayer),
        const PlacementRejected(PlacementRejection.insideMob),
        const MobKilled(MobKind.zombie, []),
        const CreeperExploded(),
        const FlightToggled(true),
        const PlayerRespawned(),
      ];
      for (final event in events) {
        expect(() => describeEvent(event), returnsNormally);
      }
    });

    test('zbicie bloku nie zaśmieca HUD', () {
      expect(
        describeEvent(const BlockBroken(BlockPos(1, 2, 3), BlockType.dirt, [])),
        isEmpty,
      );
    });

    test('nazwa bloku trafia do komunikatu o słabym narzędziu', () {
      expect(
        describeEvent(const ToolTooWeak(BlockType.ironOre)),
        contains(BlockType.ironOre.label),
      );
    });

    test('każdy powód odrzucenia ma osobny tekst', () {
      final texts = PlacementRejection.values
          .map((r) => describeEvent(PlacementRejected(r)))
          .toSet();
      expect(texts, hasLength(PlacementRejection.values.length));
    });

    test('pokonanie potwora bez łupu i z łupem brzmi inaczej', () {
      const bare = MobKilled(MobKind.skeleton, []);
      const withLoot = MobKilled(MobKind.skeleton, [
        ItemStack(ItemType.bone, 2),
      ]);
      expect(describeEvent(bare), isNot(contains('→')));
      expect(describeEvent(withLoot), contains('Kość x2'));
    });

    test('lista łupów jest rozdzielona przecinkami', () {
      const event = MobKilled(MobKind.skeleton, [
        ItemStack(ItemType.bone, 1),
        ItemStack(ItemType.arrow, 2),
      ]);
      expect(describeEvent(event), contains('Kość x1, Strzała x2'));
    });

    test('latanie ma dwa różne komunikaty', () {
      expect(
        describeEvent(const FlightToggled(true)),
        isNot(describeEvent(const FlightToggled(false))),
      );
    });
  });
}
