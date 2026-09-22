import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';

void main() {
  group('GameAction', () {
    test('hotbar actions map to slots 0..8, others to nothing', () {
      expect(GameAction.hotbar1.hotbarIndex, 0);
      expect(GameAction.hotbar9.hotbarIndex, 8);
      expect(GameAction.jump.hotbarIndex, isNull);
    });
  });

  group('Keymap', () {
    const w = 0x77;
    const up = 0x100000304;

    test('an unbound key means nothing', () {
      expect(Keymap.empty.actionFor(w), isNull);
    });

    test('binding a key leaves other keys for the same action alone', () {
      final map = Keymap.empty
          .bind(w, GameAction.moveForward)
          .bind(up, GameAction.moveForward);

      expect(map.keysFor(GameAction.moveForward), [w, up]);
    });

    test('rebinding makes the new key the only one', () {
      final map = Keymap.empty
          .bind(w, GameAction.moveForward)
          .rebind(up, GameAction.moveForward);

      expect(map.keysFor(GameAction.moveForward), [up]);
      expect(map.actionFor(w), isNull);
    });

    test('binding a key that was busy takes it over', () {
      final map = Keymap.empty
          .bind(w, GameAction.moveForward)
          .bind(w, GameAction.jump);

      expect(map.actionFor(w), GameAction.jump);
      expect(map.keysFor(GameAction.moveForward), isEmpty);
    });

    test('reports which actions have no key at all', () {
      final map = Keymap.empty.bind(w, GameAction.moveForward);

      expect(map.unbound, isNot(contains(GameAction.moveForward)));
      expect(map.unbound, contains(GameAction.jump));
    });

    test('survives a trip through JSON', () {
      final map = Keymap.empty
          .bind(w, GameAction.moveForward)
          .bind(up, GameAction.lookUp);

      expect(Keymap.fromJson(map.toJson()), map);
    });

    test('an action this version does not know is dropped, not fatal', () {
      final restored = Keymap.fromJson({
        '$w': 'moveForward',
        '$up': 'timeTravel',
        'not-a-key': 'jump',
      });

      expect(restored.bindings, {w: GameAction.moveForward});
    });
  });

  group('InputRouter', () {
    test('a held key becomes an axis', () {
      final router = InputRouter()..press(GameAction.moveForward);

      expect(router.build(1 / 60).forward, 1);
    });

    test('opposite keys cancel out', () {
      final router = InputRouter()
        ..press(GameAction.moveForward)
        ..press(GameAction.moveBack);

      expect(router.build(1 / 60).forward, 0);
    });

    test('joystick and keys together still never exceed full speed', () {
      final router = InputRouter()
        ..setStick(forward: 1, strafe: 0)
        ..press(GameAction.moveForward);

      // The old code added the two and let the player move at double speed.
      expect(router.build(1 / 60).forward, 1);
    });

    test('a press is reported once, holding is reported every frame', () {
      final router = InputRouter()..press(GameAction.toggleInventory);

      expect(router.build(1 / 60).pressed, [GameAction.toggleInventory]);
      expect(router.build(1 / 60).pressed, isEmpty);
      expect(router.build(1 / 60).held, contains(GameAction.toggleInventory));
    });

    test('pressing again after a release reports a new edge', () {
      final router = InputRouter()..press(GameAction.jump);
      router.build(1 / 60);

      router
        ..release(GameAction.jump)
        ..press(GameAction.jump);

      expect(router.build(1 / 60).pressed, [GameAction.jump]);
    });

    test('setHeld releases whatever is no longer down', () {
      final router = InputRouter()..setHeld({GameAction.moveForward});
      router.build(1 / 60);

      router.setHeld({GameAction.jump});
      final frame = router.build(1 / 60);

      expect(frame.held, {GameAction.jump});
      expect(frame.pressed, [GameAction.jump]);
    });

    test('look deltas accumulate and are consumed once', () {
      final router = InputRouter()
        ..look(0.1, 0.2)
        ..look(0.1, 0);

      expect(router.build(1 / 60).lookYaw, closeTo(0.2, 1e-9));
      expect(router.build(1 / 60).lookYaw, 0);
    });

    test('look keys turn at a rate, so frame time matters', () {
      final router = InputRouter(keyboardLookSpeed: 2)
        ..press(GameAction.lookLeft);

      expect(router.build(0.5).lookYaw, closeTo(1, 1e-9));
    });

    test('the look stick turns right when pushed right', () {
      final router = InputRouter()..setLookStick(x: 1, y: 0);

      // Turning right means a falling yaw, the same as dragging right does.
      expect(router.build(0.5).lookYaw, lessThan(0));
    });

    test('the look stick keeps turning while it is held', () {
      final router = InputRouter()..setLookStick(x: 1, y: 0);

      final first = router.build(0.5).lookYaw;
      final second = router.build(0.5).lookYaw;

      // A drag stops at the edge of the screen; a stick does not.
      expect(second, closeTo(first, 1e-9));
    });

    test('a centred stick does not move the view', () {
      final router = InputRouter()..setLookStick(x: 0, y: 0);

      expect(router.build(0.5).lookYaw, 0);
      expect(router.build(0.5).lookPitch, 0);
    });

    test('pushing up looks up', () {
      final router = InputRouter()..setLookStick(x: 0, y: 1);

      expect(router.build(0.5).lookPitch, greaterThan(0));
    });

    test('turning is a rate, so a longer frame turns further', () {
      final slow = InputRouter()..setLookStick(x: 1, y: 0);
      final fast = InputRouter()..setLookStick(x: 1, y: 0);

      expect(
        fast.build(0.5).lookYaw,
        closeTo(slow.build(0.25).lookYaw * 2, 1e-9),
      );
    });

    test('a small push turns much slower than a full one', () {
      final gentle = InputRouter()..setLookStick(x: 0.5, y: 0);
      final full = InputRouter()..setLookStick(x: 1, y: 0);

      // Squared response: half the deflection is a quarter of the speed, so
      // aiming at a mob does not need the same thumb precision as spinning.
      expect(gentle.build(1).lookYaw, closeTo(full.build(1).lookYaw / 4, 1e-9));
    });

    test('the stick is clamped, however far the widget reports', () {
      final overshoot = InputRouter()..setLookStick(x: 4, y: 0);
      final full = InputRouter()..setLookStick(x: 1, y: 0);

      expect(overshoot.build(0.5).lookYaw, full.build(0.5).lookYaw);
    });

    test('a drag and the stick add up rather than fight', () {
      final router = InputRouter()
        ..setLookStick(x: 1, y: 0)
        ..look(-0.2, 0);

      final stickOnly = (InputRouter()..setLookStick(x: 1, y: 0))
          .build(0.5)
          .lookYaw;

      expect(router.build(0.5).lookYaw, closeTo(stickOnly - 0.2, 1e-9));
    });

    test('releasing everything centres the look stick too', () {
      final router = InputRouter()
        ..setLookStick(x: 1, y: 1)
        ..releaseAll();

      expect(router.build(0.5).lookYaw, 0);
      expect(router.build(0.5).lookPitch, 0);
    });

    test('releasing everything stops a key stuck down by lost focus', () {
      final router = InputRouter()
        ..press(GameAction.moveForward)
        ..setStick(forward: 1, strafe: 1)
        ..releaseAll();

      final frame = router.build(1 / 60);
      expect(frame.held, isEmpty);
      expect(frame.forward, 0);
    });
  });

  group('InputFrame', () {
    test('sprint means run on the ground and descend in the air', () {
      const frame = InputFrame(held: {GameAction.sprint});

      expect(frame.moveFor(flying: false).sprint, isTrue);
      expect(frame.moveFor(flying: false).crouch, isFalse);
      expect(frame.moveFor(flying: true).crouch, isTrue);
      expect(frame.moveFor(flying: true).sprint, isFalse);
    });
  });

  group('Actions become commands in context', () {
    test('the inventory key opens, then closes', () {
      expect(
        commandFor(GameAction.toggleInventory, UiRoute.none),
        isA<OpenRoute>(),
      );
      expect(
        commandFor(GameAction.toggleInventory, UiRoute.inventory),
        isA<CloseRoute>(),
      );
    });

    test('a dead player cannot open the inventory', () {
      expect(commandFor(GameAction.toggleInventory, UiRoute.dead), isNull);
    });

    test('escape does nothing when there is nothing to close', () {
      expect(commandFor(GameAction.closeScreen, UiRoute.none), isNull);
      expect(commandFor(GameAction.closeScreen, UiRoute.dead), isNull);
      expect(
        commandFor(GameAction.closeScreen, UiRoute.furnace),
        isA<CloseRoute>(),
      );
    });

    test('hotbar keys are ignored while a screen is open', () {
      expect(
        commandFor(GameAction.hotbar3, UiRoute.none),
        isA<SelectHotbarSlot>().having((c) => c.index, 'index', 2),
      );
      expect(commandFor(GameAction.hotbar3, UiRoute.inventory), isNull);
    });

    test('the use key respawns on the death screen', () {
      expect(commandFor(GameAction.secondary, UiRoute.dead), isA<Respawn>());
    });

    test('the use key uses or places while playing', () {
      expect(
        commandFor(GameAction.secondary, UiRoute.none),
        isA<UseOrPlace>(),
      );
    });

    test('the use key is ignored while a screen is open', () {
      expect(commandFor(GameAction.secondary, UiRoute.inventory), isNull);
      expect(commandFor(GameAction.secondary, UiRoute.craftingTable), isNull);
      expect(commandFor(GameAction.secondary, UiRoute.furnace), isNull);
    });

    test('flying cannot be toggled from a menu', () {
      expect(
        commandFor(GameAction.toggleFlight, UiRoute.none),
        isA<ToggleFlight>(),
      );
      expect(
        commandFor(GameAction.toggleFlight, UiRoute.craftingTable),
        isNull,
      );
    });

    test('saving works from anywhere', () {
      for (final route in UiRoute.values) {
        expect(commandFor(GameAction.saveGame, route), isA<SaveGame>());
      }
    });
  });

  group('Two frames that arrive together', () {
    test('a state is taken from the newer one', () {
      const first = InputFrame(forward: 1, held: {GameAction.moveForward});
      const second = InputFrame(strafe: -1, held: {GameAction.strafeLeft});

      final merged = first.mergedWith(second);

      expect(merged.forward, 0);
      expect(merged.strafe, -1);
      expect(merged.held, {GameAction.strafeLeft});
    });

    test('an amount is added up', () {
      const first = InputFrame(lookYaw: 0.3, lookPitch: -0.1);
      const second = InputFrame(lookYaw: 0.4, lookPitch: -0.2);

      final merged = first.mergedWith(second);

      // Each is a slice of one continuous turn. Keeping only the newer one
      // is how most of a fast look ends up thrown away.
      expect(merged.lookYaw, closeTo(0.7, 1e-9));
      expect(merged.lookPitch, closeTo(-0.3, 1e-9));
    });

    test('no tap is lost, and none is invented', () {
      const first = InputFrame(pressed: [GameAction.toggleInventory]);
      const second = InputFrame(pressed: [GameAction.toggleFlight]);

      final merged = first.mergedWith(second);

      // A dropped press is a block that was never placed.
      expect(merged.pressed, [
        GameAction.toggleInventory,
        GameAction.toggleFlight,
      ]);
    });

    test('the same tap twice is two taps', () {
      const tap = InputFrame(pressed: [GameAction.toggleInventory]);

      expect(tap.mergedWith(tap).pressed, hasLength(2));
    });

    test('a whole turn survives being cut up and put back together', () {
      // What a client does to a rendered frame, undone by what a server does
      // to a burst of them.
      const frame = InputFrame(lookYaw: 1.2, forward: 1);
      var rebuilt = InputFrame.idle;
      for (var i = 0; i < 6; i++) {
        rebuilt = rebuilt.mergedWith(frame.asStep(i, 6));
      }

      expect(rebuilt.lookYaw, closeTo(1.2, 1e-9));
      expect(rebuilt.forward, 1);
    });
  });
}
