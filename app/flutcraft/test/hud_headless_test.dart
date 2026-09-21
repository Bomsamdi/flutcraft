import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutcraft/src/render/atlas.dart';
import 'package:flutcraft/src/ui/hud/hud_overlay.dart';
import 'package:flutcraft/src/ui/providers/session_providers.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_l10n/flutcraft_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

/// Prawdziwa gra bez GPU: świat, gracz, systemy i pętla.
LoopGameSession headlessGame({int size = 32}) {
  final world = VoxelWorld(sizeX: size, sizeY: 16, sizeZ: size);
  for (var z = 0; z < size; z++) {
    for (var x = 0; x < size; x++) {
      world.setRaw(x, 0, z, BlockType.bedrock);
      world.setRaw(x, 1, z, BlockType.stone);
    }
  }
  final state = GameState(
    world: world,
    player: Player(world: world, spawn: Vector3(16.5, 2, 16.5)),
    inventory: Inventory(),
  );
  return LoopGameSession(
    GameLoop(
      state: state,
      spawner: MobSpawner(world: world, seed: 1, maxMobs: 0),
      random: Random(1),
    ),
  );
}

void main() {
  late ui.Image atlas;

  setUpAll(() async {
    atlas = await TextureAtlas.generate().toImage();
  });

  Future<LoopGameSession> pumpHud(
    WidgetTester tester, {
    LoopGameSession? session,
  }) async {
    final game = session ?? headlessGame();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameSessionProvider.overrideWithValue(game)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: HudOverlay(atlas: atlas)),
        ),
      ),
    );
    return game;
  }

  group('HUD na prawdziwej grze, bez GPU', () {
    testWidgets('rysuje się i pokazuje pełne życie', (tester) async {
      await pumpHud(tester);

      expect(find.byType(HudOverlay), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNWidgets(10));
      expect(tester.takeException(), isNull);
    });

    testWidgets('pasek odzwierciedla ekwipunek gry', (tester) async {
      final game = headlessGame();
      game.loop.state.inventory
        ..add(ItemType.planks, 8)
        ..add(ItemType.coal, 3);
      await pumpHud(tester, session: game);

      expect(find.text('8'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('kliknięcie slotu wysyła komendę do prawdziwej gry', (
      tester,
    ) async {
      final game = headlessGame();
      game.loop.state.inventory
        ..add(ItemType.planks, 5)
        ..add(ItemType.coal, 5);
      await pumpHud(tester, session: game);

      expect(game.loop.state.selectedSlot, 0);

      // Drugi slot paska.
      await tester.tap(find.text('2'));
      await tester.pump();

      expect(game.loop.state.selectedSlot, 1);
      expect(game.loop.state.heldItem, ItemType.coal);
    });

    testWidgets('ikona plecaka otwiera ekwipunek w symulacji', (tester) async {
      final game = await pumpHud(tester);

      await tester.tap(find.byIcon(Icons.backpack));
      await tester.pump();

      expect(game.loop.state.route, UiRoute.inventory);
    });

    testWidgets('obrażenia gracza widać w HUD po następnej migawce', (
      tester,
    ) async {
      final game = await pumpHud(tester);
      expect(find.byIcon(Icons.favorite), findsNWidgets(10));

      game.loop.state.player.damage(6);
      game.dispatch(const SelectHotbarSlot(0));
      await tester.pump();

      expect(find.byIcon(Icons.favorite), findsNWidgets(7));
    });

    testWidgets('celownik staje się wrogi, gdy na muszce jest potwór', (
      tester,
    ) async {
      final game = headlessGame();
      final state = game.loop.state;
      state.mobs.add(
        Mob(
          kind: MobKind.zombie,
          world: state.world,
          spawn: Vector3(16.5, 2, 14.0),
        ),
      );
      state.player.yaw = 0; // patrzy w -Z
      game.tick(1 / 60, InputFrame.idle);
      game.dispatch(const SelectHotbarSlot(0));

      await pumpHud(tester, session: game);

      expect(find.text('Zombie'), findsOneWidget);
    });

    testWidgets('gra tyka pod HUD bez wyjątków', (tester) async {
      final game = await pumpHud(tester);

      for (var i = 0; i < 120; i++) {
        game.tick(1 / 60, InputFrame.idle);
      }
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(game.loop.state.player.position.y, closeTo(2, 0.2));
    });
  });
}
