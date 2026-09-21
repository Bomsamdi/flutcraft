import 'dart:ui' as ui;

import 'package:flutcraft/src/render/atlas.dart';
import 'package:flutcraft/src/ui/slots.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ui.Image atlasImage;

  setUpAll(() async {
    atlasImage = await TextureAtlas.generate().toImage();
  });

  Widget slot({
    required VoidCallback onTap,
    required VoidCallback onSplit,
  }) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: ItemSlot(
          image: atlasImage,
          stack: ItemStack(ItemType.planks, 8),
          onTap: onTap,
          onSplit: onSplit,
        ),
      ),
    ),
  );

  testWidgets('zwykłe stuknięcie podnosi cały stos', (tester) async {
    var taps = 0;
    var splits = 0;
    await tester.pumpWidget(
      slot(onTap: () => taps++, onSplit: () => splits++),
    );

    await tester.tap(find.byType(ItemSlot));
    expect(taps, 1);
    expect(splits, 0);
  });

  testWidgets('przytrzymanie dzieli stos', (tester) async {
    var taps = 0;
    var splits = 0;
    await tester.pumpWidget(
      slot(onTap: () => taps++, onSplit: () => splits++),
    );

    await tester.longPress(find.byType(ItemSlot));
    expect(splits, 1);
    expect(taps, 0);
  });

  testWidgets('prawy przycisk myszy dzieli stos', (tester) async {
    var taps = 0;
    var splits = 0;
    await tester.pumpWidget(
      slot(onTap: () => taps++, onSplit: () => splits++),
    );

    await tester.tap(find.byType(ItemSlot), buttons: kSecondaryButton);
    await tester.pump();
    expect(splits, 1);
    expect(taps, 0);
  });

  testWidgets('slot pokazuje licznik sztuk', (tester) async {
    await tester.pumpWidget(slot(onTap: () {}, onSplit: () {}));
    expect(find.text('8'), findsOneWidget);
  });
}
