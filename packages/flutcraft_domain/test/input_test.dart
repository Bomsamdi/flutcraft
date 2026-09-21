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
      expect(commandFor(GameAction.secondary, UiRoute.none), isNull);
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
}
