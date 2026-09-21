import '../actors/player_id.dart';
import 'game_event.dart';

/// A [GameEvent] and who it is for.
///
/// The loop used to return one flat list of everything that happened, which
/// was right while there was one player to tell. With company it means Bob's
/// screen announces that *his* inventory is full because Alice's is, and the
/// notice that a skeleton died goes to somebody who never swung at it.
///
/// An addressee is not something an interface layer can add after the fact —
/// only the simulation knows whose swing produced which event — so it is part
/// of what the loop returns.
class AddressedEvent {
  /// An event for one player: the one who caused it, or suffered it.
  const AddressedEvent(this.event, this.to);

  /// An event for everybody in the world. An explosion is heard by all.
  const AddressedEvent.everyone(this.event) : to = null;

  final GameEvent event;

  /// Who should hear it; `null` means everyone.
  final PlayerId? to;

  /// Whether [who] is among the recipients.
  bool reaches(PlayerId who) => to == null || to == who;

  @override
  String toString() => to == null ? '$event (all)' : '$event -> $to';
}

/// Reading a list of addressed events.
extension AddressedEvents on Iterable<AddressedEvent> {
  /// The events themselves, whoever they were for.
  ///
  /// Right where the addressee genuinely does not matter: a log, or a game
  /// with one player in it.
  List<GameEvent> get events => [for (final it in this) it.event];

  /// The events [who] is meant to hear — theirs, plus everyone's.
  List<GameEvent> forPlayer(PlayerId who) => [
    for (final it in this)
      if (it.reaches(who)) it.event,
  ];
}

/// Addresses every event in [events] to [to].
///
/// Used where a system reports what one player's action caused: the system
/// answers *what happened*, the loop knows *whose turn it was*.
List<AddressedEvent> addressedTo(PlayerId to, List<GameEvent> events) => [
  for (final event in events) AddressedEvent(event, to),
];
