import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutcraft_atlas/flutcraft_atlas.dart';
import 'package:flutcraft_ui/flutcraft_ui.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_l10n/flutcraft_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

/// The real game without a GPU: world, player, systems and loop.
LoopGameSession headlessGame({int size = 32}) {
  final world = VoxelWorld(sizeX: size, sizeY: 16, sizeZ: size);
  for (var z = 0; z < size; z++) {
    for (var x = 0; x < size; x++) {
      world.setRaw(x, 0, z, BlockType.bedrock);
      world.setRaw(x, 1, z, BlockType.stone);
    }
  }
  final state = GameState.solo(
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
    atlas = await decodeAtlasImage(TextureAtlas.generate());
  });

  /// Renders the whole HUD — hotbar, screens and all — against a real game
  /// loop. The engine is never built, which is the entire point: if a widget
  /// needed the GPU, this would not compile, let alone pass.
  Future<LoopGameSession> pumpHud(
    WidgetTester tester, {
    LoopGameSession? session,
  }) async {
    final game = session ?? headlessGame();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameSessionProvider.overrideWithValue(game),
          atlasImageProvider.overrideWithValue(atlas),
          inputRouterProvider.overrideWithValue(InputRouter()),
          frameStatsProvider.overrideWithValue(
            ValueNotifier(const FrameStats(fps: 60)),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Hud(
              showTouchControls: false,
              helpVisible: false,
              onToggleTouchControls: _nothing,
              onToggleHelp: _nothing,
            ),
          ),
        ),
      ),
    );
    return game;
  }

  group('The HUD on a real game, without a GPU', () {
    testWidgets('renders, showing full health', (tester) async {
      await pumpHud(tester);

      expect(find.byType(Hud), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNWidgets(10));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the hotbar mirrors the inventory', (tester) async {
      final game = headlessGame();
      game.loop.state.solo.inventory
        ..add(ItemType.planks, 8)
        ..add(ItemType.coal, 3);
      await pumpHud(tester, session: game);

      expect(find.text('8'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('tapping a slot reaches the real simulation', (tester) async {
      final game = headlessGame();
      game.loop.state.solo.inventory
        ..add(ItemType.planks, 5)
        ..add(ItemType.coal, 5);
      await pumpHud(tester, session: game);

      expect(game.loop.state.solo.selectedSlot, 0);

      await tester.tap(find.text('2'));
      await tester.pump();

      expect(game.loop.state.solo.selectedSlot, 1);
      expect(game.loop.state.solo.heldItem, ItemType.coal);
    });

    testWidgets('the backpack icon opens the inventory screen', (tester) async {
      final game = await pumpHud(tester);

      await tester.tap(find.byIcon(Icons.backpack));
      await tester.pump();

      expect(game.loop.state.solo.route, UiRoute.inventory);
      expect(find.byType(CraftingScreen), findsOneWidget);
    });

    testWidgets('damage shows up on the next snapshot', (tester) async {
      final game = await pumpHud(tester);
      expect(find.byIcon(Icons.favorite), findsNWidgets(10));

      game.loop.state.solo.player.damage(6);
      game.dispatch(const SelectHotbarSlot(0));
      await tester.pump();

      expect(find.byIcon(Icons.favorite), findsNWidgets(7));
    });

    testWidgets('the crosshair turns hostile on a mob', (tester) async {
      final game = headlessGame();
      final state = game.loop.state;
      state.mobs.add(
        Mob(
          kind: MobKind.zombie,
          world: state.world,
          spawn: Vector3(16.5, 2, 14.0),
        ),
      );
      state.solo.player.yaw = 0; // looking down -Z
      game.tick(1 / 60, InputFrame.idle);
      game.dispatch(const SelectHotbarSlot(0));

      await pumpHud(tester, session: game);

      expect(find.text('Zombie'), findsOneWidget);
    });

    testWidgets('the game ticks under the HUD without throwing', (
      tester,
    ) async {
      final game = await pumpHud(tester);

      for (var i = 0; i < 120; i++) {
        game.tick(1 / 60, InputFrame.idle);
      }
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(game.loop.state.solo.player.position.y, closeTo(2, 0.2));
    });
  });

  group('Screens, also without a GPU', () {
    testWidgets('crafting in the inventory reaches the grid', (tester) async {
      final game = headlessGame();
      game.loop.state.solo.inventory.add(ItemType.log, 3);
      game.dispatch(const OpenRoute(UiRoute.inventory));
      await pumpHud(tester, session: game);

      // Move a log into the 2x2 grid: pick it up, put it down.
      game
        ..dispatch(const ClickSlot(InventorySlotRef(0)))
        ..dispatch(const ClickSlot(GridSlotRef(0)));
      await tester.pump();

      expect(game.loop.state.solo.smallGrid[0]?.type, ItemType.log);
      expect(find.byType(CraftingScreen), findsOneWidget);
    });

    testWidgets('the furnace screen shows what is inside', (tester) async {
      final game = headlessGame();
      final state = game.loop.state;
      state.world.setBlock(16, 2, 16, BlockType.furnace);
      state.furnaces.open(const BlockPos(16, 2, 16)).input = const ItemStack(
        ItemType.rawIron,
        12,
      );
      state.solo.openFurnace = const BlockPos(16, 2, 16);
      game.dispatch(const OpenRoute(UiRoute.furnace));

      await pumpHud(tester, session: game);

      expect(find.byType(FurnaceScreen), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('the death screen respawns the player', (tester) async {
      final game = headlessGame();
      game.loop.state.solo.player.damage(Player.maxHealth);
      // Snapshots are published at 20 Hz, so one frame is not enough for the
      // interface to have heard about it.
      for (var i = 0; i < 4; i++) {
        game.tick(1 / 60, InputFrame.idle);
      }

      await pumpHud(tester, session: game);
      expect(find.byType(DeathScreen), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(game.loop.state.solo.route, UiRoute.none);
      expect(game.loop.state.solo.player.isDead, isFalse);
    });

    testWidgets('the recipe book opens from the top bar', (tester) async {
      final game = await pumpHud(tester);

      await tester.tap(find.byIcon(Icons.menu_book));
      await tester.pump();

      expect(game.loop.state.solo.route, UiRoute.recipes);
      expect(find.byType(RecipeScreen), findsOneWidget);
    });
  });
}

void _nothing() {}
