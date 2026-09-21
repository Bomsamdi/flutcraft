import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutcraft_atlas/flutcraft_atlas.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_l10n/flutcraft_l10n.dart';
import 'package:flutcraft_ui/flutcraft_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

/// The shortest way round from [from] to [to], in radians.
///
/// Yaw wraps at a full circle, so a small turn right can land just under 2*pi
/// and look enormous to a plain subtraction.
double turnBetween(double from, double to) {
  final delta = to - from;
  return atan2(sin(delta), cos(delta));
}

/// An iPhone 15 held sideways, in logical points.
const Size kPhoneLandscape = Size(852, 393);

LoopGameSession headlessGame() {
  final world = VoxelWorld(sizeX: 32, sizeY: 16, sizeZ: 32);
  for (var z = 0; z < 32; z++) {
    for (var x = 0; x < 32; x++) {
      world.setRaw(x, 0, z, BlockType.stone);
    }
  }
  return LoopGameSession(
    GameLoop(
      state: GameState(
        world: world,
        player: Player(world: world, spawn: Vector3(16.5, 1, 16.5)),
        inventory: Inventory(),
      ),
      spawner: MobSpawner(world: world, seed: 1, maxMobs: 0),
      random: Random(1),
    ),
  );
}

void main() {
  late ui.Image atlasImage;

  setUpAll(() async {
    atlasImage = await decodeAtlasImage(TextureAtlas.generate());
  });

  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..physicalSize = kPhoneLandscape * 3
      ..devicePixelRatio = 3;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .resetPhysicalSize();
  });

  /// The HUD with the touch controls showing, over a real game loop.
  Future<(LoopGameSession, InputRouter)> pumpTouchHud(
    WidgetTester tester,
  ) async {
    final game = headlessGame();
    final router = InputRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameSessionProvider.overrideWithValue(game),
          atlasImageProvider.overrideWithValue(atlasImage),
          inputRouterProvider.overrideWithValue(router),
          frameStatsProvider.overrideWithValue(
            ValueNotifier(const FrameStats(fps: 60)),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Hud(
              showTouchControls: true,
              helpVisible: false,
              onToggleTouchControls: () {},
              onToggleHelp: () {},
            ),
          ),
        ),
      ),
    );
    return (game, router);
  }

  /// Runs the game for [seconds] the way the engine does: build a frame from
  /// the router, hand it to the loop.
  void play(LoopGameSession game, InputRouter router, {double seconds = 0.5}) {
    for (var i = 0; i < seconds * 60; i++) {
      game.tick(1 / 60, router.build(1 / 60));
    }
  }

  group('Two sticks, as on a gamepad', () {
    testWidgets('both sticks fit a phone held sideways', (tester) async {
      await pumpTouchHud(tester);

      expect(find.byType(VirtualJoystick), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the move stick is on the left, the look stick on the right', (
      tester,
    ) async {
      await pumpTouchHud(tester);

      final sticks = tester
          .widgetList<VirtualJoystick>(find.byType(VirtualJoystick))
          .toList();
      final left = tester.getCenter(find.byWidget(sticks.first));
      final right = tester.getCenter(find.byWidget(sticks.last));

      expect(left.dx, lessThan(kPhoneLandscape.width / 2));
      expect(right.dx, greaterThan(kPhoneLandscape.width / 2));
    });

    testWidgets('the controls sit along the bottom, not in the sky', (
      tester,
    ) async {
      await pumpTouchHud(tester);

      // A non-positioned child of a Stack is pinned to the top-left, which is
      // where these used to render: two sticks and four buttons across the
      // horizon, over the world the player is trying to see.
      for (final stick in find.byType(VirtualJoystick).evaluate()) {
        final centre = tester.getCenter(find.byWidget(stick.widget));
        expect(centre.dy, greaterThan(kPhoneLandscape.height / 2));
      }
      for (final button in find.byType(HoldButton).evaluate()) {
        final centre = tester.getCenter(find.byWidget(button.widget));
        expect(centre.dy, greaterThan(kPhoneLandscape.height / 2));
      }
    });

    testWidgets('all four action buttons are still there', (tester) async {
      await pumpTouchHud(tester);

      expect(find.byType(HoldButton), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing on the thumb row covers the hotbar', (tester) async {
      await pumpTouchHud(tester);

      final hotbar = tester.getRect(find.byIcon(Icons.backpack));
      final controls = [
        ...find.byType(HoldButton).evaluate(),
        ...find.byType(VirtualJoystick).evaluate(),
      ];

      for (final control in controls) {
        final rect = tester.getRect(find.byWidget(control.widget));
        expect(
          rect.top,
          greaterThanOrEqualTo(hotbar.bottom),
          reason: 'a control reaches up into the hotbar',
        );
      }
    });

    testWidgets('the controls fit across the width without overlapping', (
      tester,
    ) async {
      await pumpTouchHud(tester);

      final rects =
          [
              ...find.byType(VirtualJoystick).evaluate(),
              ...find.byType(HoldButton).evaluate(),
            ].map((e) => tester.getRect(find.byWidget(e.widget))).toList()
            ..sort((a, b) => a.left.compareTo(b.left));

      for (var i = 1; i < rects.length; i++) {
        expect(
          rects[i].left,
          greaterThanOrEqualTo(rects[i - 1].right),
          reason: 'controls overlap horizontally',
        );
      }
      expect(rects.last.right, lessThanOrEqualTo(kPhoneLandscape.width));
    });
  });

  group('The look stick turns the player', () {
    testWidgets('pushing it right turns right', (tester) async {
      final (game, router) = await pumpTouchHud(tester);
      final player = game.loop.state.player;
      final before = player.yaw;

      // Held, not dragged: a released stick springs back to centre, and the
      // whole point of it is what happens while a thumb stays on it.
      final stick = find.byType(VirtualJoystick).last;
      final gesture = await tester.startGesture(tester.getCenter(stick));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      play(game, router);

      // Turning right lowers yaw, exactly as dragging the screen right does.
      expect(turnBetween(before, player.yaw), lessThan(-0.2));
      await gesture.up();
    });

    testWidgets('pushing it up looks up', (tester) async {
      final (game, router) = await pumpTouchHud(tester);
      final player = game.loop.state.player;
      final before = player.pitch;

      final stick = find.byType(VirtualJoystick).last;
      final gesture = await tester.startGesture(tester.getCenter(stick));
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      play(game, router);

      expect(player.pitch, greaterThan(before));
      await gesture.up();
    });

    testWidgets('holding it keeps turning, frame after frame', (tester) async {
      final (game, router) = await pumpTouchHud(tester);
      final player = game.loop.state.player;

      final stick = find.byType(VirtualJoystick).last;
      final gesture = await tester.startGesture(tester.getCenter(stick));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();

      play(game, router, seconds: 0.5);
      final afterHalfSecond = player.yaw;
      play(game, router, seconds: 0.5);
      final afterOneSecond = player.yaw;

      // A drag would have stopped at the edge of the screen by now.
      expect(
        turnBetween(afterHalfSecond, afterOneSecond).abs(),
        greaterThan(0.2),
      );
      await gesture.up();
    });

    testWidgets('letting go stops the turn', (tester) async {
      final (game, router) = await pumpTouchHud(tester);
      final player = game.loop.state.player;

      final stick = find.byType(VirtualJoystick).last;
      await tester.dragFrom(tester.getCenter(stick), const Offset(60, 0));
      play(game, router);

      final settled = player.yaw;
      play(game, router, seconds: 1);

      expect(turnBetween(settled, player.yaw), closeTo(0, 1e-9));
    });

    testWidgets('the move stick walks and does not turn', (tester) async {
      final (game, router) = await pumpTouchHud(tester);
      final player = game.loop.state.player;
      final yaw = player.yaw;
      final position = player.position.clone();

      final stick = find.byType(VirtualJoystick).first;
      final gesture = await tester.startGesture(tester.getCenter(stick));
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      play(game, router);

      expect(turnBetween(yaw, player.yaw), closeTo(0, 1e-9));
      expect(player.position.distanceTo(position), greaterThan(0.2));
      await gesture.up();
    });
  });
}
