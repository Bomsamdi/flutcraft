import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:vector_math/vector_math.dart';

import 'wire_values.dart';

/// Anything a client says to a server.
///
/// Sealed, so adding a message forces every switch over it to be extended —
/// the same reason the simulation's commands and events are sealed. A message
/// the server does not handle is a compile error, not a silent drop.
sealed class ClientMessage {
  const ClientMessage();
}

/// The first thing a client says: who it is, and what proves it.
///
/// A name alone would do for a world among friends, and it is what this
/// started as. It stops working the moment two people want the same one, or
/// one of them wants the belongings that go with it: a name that anybody can
/// claim is not an account, it is a label.
///
/// The secret travels as the player typed it. Hashing it in the client would
/// look safer and would not be: whatever the client sends is what the server
/// compares, so a stolen copy of that is a password. The thing that actually
/// protects it on the way over is `wss://`, and that belongs to the transport.
final class SignIn extends ClientMessage {
  const SignIn(this.name, this.secret);

  final String name;
  final String secret;
}

/// A name nobody has taken yet, claimed with the secret that will hold it.
final class SignUp extends ClientMessage {
  const SignUp(this.name, this.secret);

  final String name;
  final String secret;
}

/// What one player wants to do during one simulation step.
///
/// Stamped with the tick it belongs to, which is what lets the server say
/// later "I have applied everything up to here" and the client replay the
/// rest.
final class InputTick extends ClientMessage {
  const InputTick(this.tick, this.input);

  final int tick;
  final InputFrame input;
}

/// A deliberate action: a slot clicked, a screen opened, a block used.
final class Command extends ClientMessage {
  const Command(this.command);

  final GameCommand command;
}

/// Answer to a [Ping], so the server can time the round trip.
final class Pong extends ClientMessage {
  const Pong(this.id);

  final int id;
}

/// Anything a server says to a client.
sealed class ServerMessage {
  const ServerMessage();
}

/// You are in. Here is who you are and what world this is.
final class Welcome extends ServerMessage {
  const Welcome({required this.you, required this.tick, required this.world});

  final PlayerId you;

  /// The server's current tick, so the client can start counting from it.
  final int tick;

  final WorldState world;
}

/// Blocks that changed, and the tick they changed on.
///
/// The tick matters more than it looks: a client that predicted its own
/// placement needs to know which of its guesses this delta has settled.
final class WorldDelta extends ServerMessage {
  const WorldDelta(this.tick, this.changes);

  final int tick;
  final List<BlockChange> changes;
}

/// Where the mobs and arrows are now, and which ones are gone.
final class EntityDelta extends ServerMessage {
  const EntityDelta({
    required this.tick,
    this.mobs = const [],
    this.arrows = const [],
    this.gone = const [],
  });

  final int tick;
  final List<MobState> mobs;
  final List<ArrowState> arrows;

  /// Entities that left the world — killed, spent, or too far away to matter.
  final List<EntityId> gone;
}

/// Where everybody else is.
final class PlayerStates extends ServerMessage {
  const PlayerStates(this.tick, this.players);

  final int tick;
  final List<RemotePlayerState> players;
}

/// Where the server says *you* are, and up to which of your inputs.
///
/// The client rewinds its own player to this and replays the input it has
/// sent since [ackTick]. Everything else in a client's world is somebody
/// else's business; this one message is the correction of its own.
final class SelfState extends ServerMessage {
  const SelfState({
    required this.ackTick,
    required this.position,
    required this.velocity,
    required this.yaw,
    required this.pitch,
    required this.onGround,
    required this.flying,
    required this.health,
  });

  /// The last tick of this player's input the server has applied.
  final int ackTick;

  final Vector3 position;
  final Vector3 velocity;
  final double yaw;
  final double pitch;
  final bool onGround;
  final bool flying;
  final int health;
}

/// What this player is carrying.
///
/// Sent when it changes rather than on a timer: an inventory is not something
/// a client may predict — a mispredicted craft would duplicate or destroy
/// items with nothing failing — so it is only ever the server's word.
final class InventoryState extends ServerMessage {
  const InventoryState({
    required this.revision,
    required this.slots,
    required this.selectedSlot,
    this.cursor,
  });

  /// Rises with every change, so a client can ignore one that arrived late.
  final int revision;

  final List<ItemStack?> slots;
  final int selectedSlot;
  final ItemStack? cursor;
}

/// A blast happened here.
///
/// Sent instead of the hundreds of block changes it causes: the crater is
/// pure integer arithmetic over a radius, so a client can work it out
/// itself and arrive at exactly the same holes.
final class ExplosionAt extends ServerMessage {
  const ExplosionAt(this.at, this.radius);

  final Vector3 at;
  final double radius;
}

/// Something worth telling this player about.
///
/// Carries the event, not a sentence. The server never knew which language
/// anybody reads, and this is where that rule would break first.
final class Notice extends ServerMessage {
  const Notice(this.event);

  final GameEvent event;
}

/// Are you still there?
final class Ping extends ServerMessage {
  const Ping(this.id);

  final int id;
}

/// You are out, and here is the code that says why.
final class Kick extends ServerMessage {
  const Kick(this.reason);

  final KickReason reason;
}
