import 'dart:async';

import 'package:flutcraft/src/ui/providers/session_providers.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The event the HUD is currently showing, or `null` when the notice has
/// faded.
///
/// The simulation emits events and forgets them; deciding how long a message
/// stays on screen is a presentation question, so it is answered here rather
/// than by a timer inside the game.
final messageProvider = NotifierProvider<MessageNotifier, GameEvent?>(
  MessageNotifier.new,
);

class MessageNotifier extends Notifier<GameEvent?> {
  /// How long a message stays up before it fades.
  static const Duration visibleFor = Duration(milliseconds: 2400);

  Timer? _timer;

  @override
  GameEvent? build() {
    final events = ref.watch(gameSessionProvider).events.listen(show);
    ref.onDispose(() {
      events.cancel();
      _timer?.cancel();
    });
    return null;
  }

  void show(GameEvent event) {
    state = event;
    _timer?.cancel();
    _timer = Timer(visibleFor, () => state = null);
  }
}
