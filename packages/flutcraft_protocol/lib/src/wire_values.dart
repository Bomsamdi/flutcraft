import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:vector_math/vector_math.dart';

/// One block that changed, and what it changed to.
class BlockChange {
  const BlockChange(this.pos, this.block);

  final BlockPos pos;
  final BlockType block;
}

/// Where a mob is and what it is doing, as the server sees it.
///
/// Carries the id rather than the mob, because a client applies this by
/// writing into the mob it already has. Building a new one per packet would
/// make the renderer throw away and rebuild a component twenty times a
/// second, and the mobs would flicker.
class MobState {
  const MobState({
    required this.id,
    required this.kind,
    required this.position,
    required this.yaw,
    required this.health,
    required this.walkSpeed,
    required this.fuse,
  });

  final EntityId id;
  final MobKind kind;
  final Vector3 position;
  final double yaw;
  final double health;

  /// How fast the limbs should be moving; the client animates from this
  /// rather than guessing from successive positions.
  final double walkSpeed;

  /// A creeper's lit fuse, or a negative number when it is not lit.
  final double fuse;
}

/// An arrow in flight.
class ArrowState {
  const ArrowState({
    required this.id,
    required this.position,
    required this.yaw,
    required this.pitch,
  });

  final EntityId id;
  final Vector3 position;
  final double yaw;
  final double pitch;
}

/// Another player, as everyone else sees them.
///
/// Not a [SelfState]: what other people need is a body to draw, not the
/// inventory and the open screen that belong to whoever is playing them.
class RemotePlayerState {
  const RemotePlayerState({
    required this.id,
    required this.position,
    required this.yaw,
    required this.pitch,
    required this.health,
  });

  final PlayerId id;
  final Vector3 position;
  final double yaw;
  final double pitch;
  final int health;
}

/// A world, as a joining client needs it: a seed and what differs from it.
///
/// The same shape the save format uses, for the same reason — terrain is
/// deterministic, so a whole 128x48x128 world travels as a number and a few
/// hundred edits.
class WorldState {
  const WorldState({required this.seed, required this.edits});

  final int seed;
  final Map<BlockPos, BlockType> edits;
}

/// Why a server closed a connection.
///
/// A code rather than a sentence: the server has no business knowing which
/// language the player reads, exactly as it has no business formatting the
/// text for an event.
enum KickReason {
  /// The client speaks a version of the protocol this server does not.
  protocolMismatch,

  /// The world this client asked for is not the one the server is running.
  worldMismatch,

  /// The client stopped reading and its outbound queue overflowed.
  tooSlow,

  /// Somebody else is already playing as this player.
  alreadyConnected,

  /// The server is going away.
  shuttingDown,
}
