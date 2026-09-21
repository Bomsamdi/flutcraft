import 'dart:ui' as ui;

import 'package:flutcraft_atlas/flutcraft_atlas.dart';
import 'package:flutcraft_ui/flutcraft_ui.dart';
import 'package:flutcraft_l10n/flutcraft_l10n.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// An iPhone 15 held sideways, in logical points.
const Size kPhoneLandscape = Size(852, 393);

void main() {
  late ui.Image atlasImage;

  setUpAll(() async {
    atlasImage = await decodeAtlasImage(TextureAtlas.generate());
  });

  setUp(() {
    // These tests check the interface fits a short, wide frame.
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..physicalSize = kPhoneLandscape * 3
      ..devicePixelRatio = 3;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .resetPhysicalSize();
  });

  testWidgets('a nine-slot bar fits the width of the screen', (tester) async {
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

  testWidgets('the recipe book scrolls instead of overflowing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecipeBook(image: atlasImage, inventory: Inventory().slots),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    // The content is taller than the screen, so it has to scroll.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the book is narrower than a phone held sideways', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecipeBook(image: atlasImage, inventory: Inventory().slots),
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
