import 'dart:ui' as ui;

import 'package:flutcraft/src/render/atlas.dart';
import 'package:flutcraft/src/ui/recipe_book.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutcraft_l10n/flutcraft_l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ui.Image atlasImage;

  setUpAll(() async {
    atlasImage = await TextureAtlas.generate().toImage();
  });

  Widget book(Inventory inventory, {Locale locale = const Locale('en')}) =>
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecipeBook(image: atlasImage, inventory: inventory),
          ),
        ),
      );

  testWidgets('księga rysuje wszystkie sekcje', (tester) async {
    await tester.pumpWidget(book(Inventory()));

    expect(find.text('In your inventory (2x2 grid)'), findsOneWidget);
    expect(find.text('At a crafting table (3x3)'), findsOneWidget);
    expect(find.textContaining('seconds each'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pokazuje wyniki przepisów wraz z liczbą sztuk', (tester) async {
    await tester.pumpWidget(book(Inventory()));

    expect(find.text('Planks x4'), findsOneWidget);
    expect(find.text('Stick x4'), findsOneWidget);
    expect(find.text('Crafting Table'), findsOneWidget);
  });

  testWidgets('bez składników wszystko jest oznaczone jako niedostępne',
      (tester) async {
    await tester.pumpWidget(book(Inventory()));

    expect(find.text('You have the ingredients'), findsNothing);
    expect(find.textContaining('Missing:'), findsWidgets);
  });

  testWidgets('podpowiada konkretnie, czego i ile brakuje', (tester) async {
    final inventory = Inventory()..add(ItemType.cobblestone, 3);
    await tester.pumpWidget(book(inventory));

    // Do kamiennego kilofa zostają tylko patyki.
    expect(find.text('Missing: Stick x2'), findsWidgets);
  });

  testWidgets('przepis ze stołu mówi, gdzie go ułożyć', (tester) async {
    final inventory = Inventory()..add(ItemType.cobblestone, 8);
    await tester.pumpWidget(book(inventory));

    expect(
      find.text('You have the ingredients — use a table'),
      findsOneWidget,
    );
  });

  testWidgets('kłoda w ekwipunku odblokowuje desk i tylko je', (tester) async {
    final inventory = Inventory()..add(ItemType.log, 1);
    await tester.pumpWidget(book(inventory));

    expect(find.text('You have the ingredients'), findsOneWidget);
  });

  testWidgets('materiały na kilof podświetlają przepisy ze stołu',
      (tester) async {
    final inventory = Inventory()
      ..add(ItemType.cobblestone, 8)
      ..add(ItemType.stick, 2);
    await tester.pumpWidget(book(inventory));

    // Kamienny kilof, kamienny miecz i piec naraz stają się dostępne.
    expect(
      find.text('You have the ingredients — use a table'),
      findsNWidgets(3),
    );
  });

  testWidgets('polski przełącza całą księgę', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecipeBook(image: atlasImage, inventory: Inventory()),
          ),
        ),
      ),
    );

    expect(find.text('W ekwipunku (siatka 2x2)'), findsOneWidget);
    expect(find.text('Deski x4'), findsOneWidget);
    expect(find.text('Surowe żelazo → Sztabka żelaza'), findsOneWidget);
  });

  testWidgets('wytop pokazuje kierunek przemiany', (tester) async {
    await tester.pumpWidget(book(Inventory()));

    expect(find.text('Raw Iron → Iron Ingot'), findsOneWidget);
    expect(find.text('Sand → Bricks'), findsOneWidget);
  });
}

