import '../blocks/block_pos.dart';

/// Which block a player says their crosshair is on.
///
/// A server works out its own aim, but a tick later than the client does:
/// the input has to travel, and prediction means the client has already
/// simulated that tick. While the crosshair is moving that is regularly a
/// different block — and since mining only finishes after dwelling on one
/// target, the block that breaks is reliably the one the player has just
/// looked away from. The crosshair says one block, the hole appears in its
/// neighbour.
///
/// So the client says which block it means, and the server checks the claim
/// instead of recomputing it. The server still decides *whether* the block
/// goes; the client only says *which*.
final class AimClaim {
  const AimClaim({required this.at, required this.against});

  /// The block under the crosshair.
  final BlockPos at;

  /// The cell on the near side of the face that was hit — where a block
  /// placed against it would go.
  final BlockPos against;

  @override
  bool operator ==(Object other) =>
      other is AimClaim && other.at == at && other.against == against;

  @override
  int get hashCode => Object.hash(at, against);

  @override
  String toString() => 'AimClaim($at against $against)';
}
