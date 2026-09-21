import 'package:meta/meta.dart';

import 'game_action.dart';

/// Which key triggers which action.
///
/// Keys are opaque integers, not `LogicalKeyboardKey` — the domain has no
/// Flutter to import. The platform layer knows how to turn a real key into
/// one of these ids, and nothing else about a keymap changes as a result.
@immutable
final class Keymap {
  const Keymap(this.bindings);

  /// Key id to action. One action may have several keys; one key has at
  /// most one action, which is why this map is keyed by the key.
  final Map<int, GameAction> bindings;

  /// Nothing bound. Useful as a starting point for a custom map.
  static const empty = Keymap({});

  GameAction? actionFor(int keyId) => bindings[keyId];

  /// Every key bound to [action], in binding order.
  List<int> keysFor(GameAction action) => [
    for (final entry in bindings.entries)
      if (entry.value == action) entry.key,
  ];

  /// Binds [keyId] to [action], dropping whatever that key did before.
  ///
  /// Other keys bound to the same action are left alone, so an action can
  /// keep both a letter and a gamepad button.
  Keymap bind(int keyId, GameAction action) =>
      Keymap({...bindings, keyId: action});

  /// Makes [keyId] the only key for [action] — what a rebinding screen does.
  Keymap rebind(int keyId, GameAction action) => Keymap({
    for (final entry in bindings.entries)
      if (entry.value != action) entry.key: entry.value,
    keyId: action,
  });

  Keymap unbind(int keyId) => Keymap({...bindings}..remove(keyId));

  /// Actions with no key at all — what a settings screen warns about.
  Set<GameAction> get unbound =>
      GameAction.values.toSet()..removeAll(bindings.values);

  Map<String, Object?> toJson() => {
    for (final entry in bindings.entries) '${entry.key}': entry.value.name,
  };

  /// Unknown actions and malformed keys are skipped: a keymap saved by a
  /// newer version should cost the player their custom keys, not the game.
  factory Keymap.fromJson(Map<String, Object?> json) {
    final actions = {for (final a in GameAction.values) a.name: a};
    return Keymap({
      for (final entry in json.entries)
        ?int.tryParse(entry.key): ?actions[entry.value],
    });
  }

  @override
  bool operator ==(Object other) =>
      other is Keymap &&
      other.bindings.length == bindings.length &&
      other.bindings.entries.every((e) => bindings[e.key] == e.value);

  @override
  int get hashCode => Object.hashAllUnordered([
    for (final entry in bindings.entries) Object.hash(entry.key, entry.value),
  ]);
}
