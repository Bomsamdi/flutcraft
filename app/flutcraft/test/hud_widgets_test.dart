import 'package:flutcraft/src/game/hud_state.dart';
import 'package:flutcraft/src/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('Celownik', () {
    testWidgets('rysuje się w trybie zwykłym i bojowym', (tester) async {
      await tester.pumpWidget(
        wrap(const Crosshair(progress: 0, hasTarget: true)),
      );
      expect(find.byType(Crosshair), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        wrap(const Crosshair(progress: 0, hasTarget: true, hostile: true)),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('pierścień postępu nie wywraca się na skrajnych wartościach',
        (tester) async {
      for (final progress in [0.0, 0.5, 1.0, 1.5]) {
        await tester.pumpWidget(
          wrap(Crosshair(progress: progress, hasTarget: true)),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Pasek życia potwora', () {
    testWidgets('pokazuje nazwę potwora', (tester) async {
      await tester.pumpWidget(
        wrap(
          const TargetHealthBar(
            target: TargetMob(label: 'Creeper', health: 9, maxHealth: 18),
          ),
        ),
      );
      expect(find.text('Creeper'), findsOneWidget);
    });

    testWidgets('szerokość paska odpowiada ułamkowi życia', (tester) async {
      await tester.pumpWidget(
        wrap(
          const TargetHealthBar(
            target: TargetMob(label: 'Zombie', health: 5, maxHealth: 20),
          ),
        ),
      );

      final box = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(box.widthFactor, closeTo(0.25, 1e-9));
    });

    testWidgets('ujemne życie nie daje ujemnej szerokości', (tester) async {
      await tester.pumpWidget(
        wrap(
          const TargetHealthBar(
            target: TargetMob(label: 'Pająk', health: -3, maxHealth: 14),
          ),
        ),
      );
      final box = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(box.widthFactor, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('Serca', () {
    testWidgets('rysuje dziesięć ikon dla dwudziestu punktów życia',
        (tester) async {
      await tester.pumpWidget(
        wrap(const HeartsBar(health: 20, maxHealth: 20)),
      );
      expect(find.byIcon(Icons.favorite), findsNWidgets(10));
    });

    testWidgets('połowa życia to pięć pełnych serc', (tester) async {
      await tester.pumpWidget(
        wrap(const HeartsBar(health: 10, maxHealth: 20)),
      );
      expect(find.byIcon(Icons.favorite), findsNWidgets(5));
      expect(find.byIcon(Icons.favorite_border), findsNWidgets(5));
    });

    testWidgets('nieparzyste życie pokazuje pęknięte serce', (tester) async {
      await tester.pumpWidget(
        wrap(const HeartsBar(health: 9, maxHealth: 20)),
      );
      expect(find.byIcon(Icons.favorite), findsNWidgets(4));
      expect(find.byIcon(Icons.heart_broken), findsOneWidget);
    });
  });
}
