import '../../physics/voxel_body.dart';
import '../game_state.dart';

/// Keeps bodies out of one another.
///
/// The voxel physics only ever knew about blocks, so mobs walked straight
/// through the player and through each other: four zombies could occupy one
/// square, and the one hitting you was inside your head. Fighting something
/// you cannot see the front of is the problem this solves.
///
/// Overlaps are resolved by moving the bodies apart along whichever
/// horizontal axis they overlap least — the cheapest way out — and through
/// [VoxelBody.moveBy], so a wall still stops the push instead of letting a
/// crowd shove someone into the stone.
class EntitySeparationSystem {
  const EntitySeparationSystem({this.playerShare = 0.25});

  /// How much of a mob-versus-player overlap the player absorbs.
  ///
  /// Not a half: a player standing their ground should feel the shove but
  /// keep their footing, and it is the mob that walked into them.
  final double playerShare;

  /// Bodies closer than this count as touching rather than overlapping, and
  /// the push clears them by this much.
  ///
  /// A tenth of a millimetre, which is both invisible and comfortably above
  /// the precision of the 32-bit vectors these positions live in: resolving
  /// to *exactly* touching would land a rounding error back inside.
  static const double _slack = 1e-3;

  void update(GameState state) {
    for (final mob in state.mobs) {
      if (mob.isDead) continue;
      _separate(mob, state.player, share: playerShare);
    }

    // Mobs push each other apart evenly: neither has a claim on the spot.
    for (var i = 0; i < state.mobs.length; i++) {
      for (var j = i + 1; j < state.mobs.length; j++) {
        _separate(state.mobs[i], state.mobs[j], share: 0.5);
      }
    }
  }

  /// Pushes [a] and [b] apart, with [b] taking [share] of the correction.
  void _separate(VoxelBody a, VoxelBody b, {required double share}) {
    if (!_verticallyOverlapping(a, b)) return;

    final dx = a.position.x - b.position.x;
    final dz = a.position.z - b.position.z;
    final reach = a.halfWidth + b.halfWidth;

    final overlapX = reach - dx.abs();
    final overlapZ = reach - dz.abs();
    if (overlapX <= _slack || overlapZ <= _slack) return;

    if (overlapX < overlapZ) {
      final push = (overlapX + _slack) * _signOf(dx);
      a.moveBy(push * (1 - share), 0, 0);
      b.moveBy(-push * share, 0, 0);
    } else {
      final push = (overlapZ + _slack) * _signOf(dz);
      a.moveBy(0, 0, push * (1 - share));
      b.moveBy(0, 0, -push * share);
    }
  }

  /// Whether the two boxes share any height at all.
  ///
  /// A mob on a roof is directly above the player and overlaps them on both
  /// horizontal axes; pushing it sideways there would be nonsense.
  static bool _verticallyOverlapping(VoxelBody a, VoxelBody b) =>
      a.position.y < b.position.y + b.height &&
      b.position.y < a.position.y + a.height;

  /// The sign to push along, treating dead centre as "push east".
  ///
  /// Two bodies spawned on exactly the same spot have no direction to
  /// separate along, and picking one is better than leaving them merged.
  static double _signOf(double delta) => delta < 0 ? -1 : 1;
}
