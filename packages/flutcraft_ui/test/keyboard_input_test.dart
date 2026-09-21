import 'package:flutcraft_ui/flutcraft_ui.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

void main() {
  late InputRouter router;
  late KeyboardInputSource keyboard;

  setUp(() {
    router = InputRouter();
    keyboard = KeyboardInputSource(router: router);
  });

  test('a held key turns into its action', () {
    keyboard.onKeysChanged({LogicalKeyboardKey.keyW});

    expect(router.build(1 / 60).forward, 1);
  });

  test('a key nobody bound is ignored', () {
    keyboard.onKeysChanged({LogicalKeyboardKey.keyZ});

    expect(router.build(1 / 60).held, isEmpty);
  });

  test('releasing a key stops the movement', () {
    keyboard.onKeysChanged({LogicalKeyboardKey.keyW});
    router.build(1 / 60);

    keyboard.onKeysChanged({});

    expect(router.build(1 / 60).forward, 0);
  });

  test('the inventory key is reported as an edge, not as a hold', () {
    keyboard.onKeysChanged({LogicalKeyboardKey.keyE});

    expect(router.build(1 / 60).pressed, [GameAction.toggleInventory]);
    // Holding E must not open and close the inventory sixty times a second.
    expect(router.build(1 / 60).pressed, isEmpty);
  });

  test('rebinding a key changes the game without touching the game', () {
    keyboard.keymap = defaultKeymap.rebind(
      LogicalKeyboardKey.keyZ.keyId,
      GameAction.moveForward,
    );

    keyboard.onKeysChanged({LogicalKeyboardKey.keyZ});
    expect(router.build(1 / 60).forward, 1);

    keyboard.onKeysChanged({LogicalKeyboardKey.keyW});
    expect(router.build(1 / 60).forward, 0);
  });

  test('every default binding names a key the platform knows', () {
    final known = {
      for (final key in LogicalKeyboardKey.knownLogicalKeys) key.keyId,
    };

    expect(defaultKeymap.bindings.keys, everyElement(isIn(known)));
  });

  test('the keys a player needs to play are all bound', () {
    const essential = {
      GameAction.moveForward,
      GameAction.moveBack,
      GameAction.strafeLeft,
      GameAction.strafeRight,
      GameAction.jump,
      GameAction.secondary,
      GameAction.toggleInventory,
    };

    expect(defaultKeymap.unbound.intersection(essential), isEmpty);
  });
}
