import 'dart:ui' as ui;

import 'package:flutcraft/src/render/atlas.dart';
import 'package:flutcraft/src/ui/recipe_book.dart';
import 'package:flutcraft_l10n/flutcraft_l10n.dart';
import 'package:flutcraft/src/ui/slots.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// iPhone 15 w poziomie (punkty logiczne).
const Size kPhoneLandscape = Size(852, 393);

void main() {
  late ui.Image atlasImage;

  setUpAll(() async {
    atlasImage = await TextureAtlas.generate().toImage();
  });

  setUp(() {
    // Testy sprawdzają, czy UI mieści się w niskim, szerokim kadrze.
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..physicalSize = kPhoneLandscape * 3
      ..devicePixelRatio = 3;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .resetPhysicalSize();
  });

  testWidgets('pasek 9 slotów mieści się w szerokości ekranu',
      (tester) async {
    final inventory = Inventory()..add(ItemType.planks, 5);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SlotGrid(
              image: atlasImage,
              count: inventory.hotbarSize,
              columns: 9,
              size: 42,
              stackAt: (i) => inventory[i],
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );

    final width = tester.getSize(find.byType(SlotGrid)).width;
    expect(width, lessThan(kPhoneLandscape.width));
    expect(tester.takeException(), isNull);
  });

  testWidgets('księga przepisów przewija się zamiast przepełniać',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecipeBook(image: atlasImage, inventory: Inventory()),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    // Treść jest wyższa niż ekran, więc musi dać się przewinąć.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('księga jest węższa niż poziomy kadr telefonu', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecipeBook(image: atlasImage, inventory: Inventory()),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(RecipeBook)).width,
      lessThanOrEqualTo(kPhoneLandscape.width),
    );
  });
}
