import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';
import '../world/voxel_world.dart';

/// An AABB body moving through the voxel grid.
///
/// [position] is the centre of the base — the feet — not the centre of the
/// box, which makes standing on ground trivial. Movement is resolved one
/// axis at a time, so a body slides along a wall instead of sticking to it.
class VoxelBody {
  VoxelBody({
    required this.world,
    required Vector3 spawn,
    required this.width,
    required this.height,
  }) : position = spawn.clone(),
       velocity = Vector3.zero();

  final VoxelWorld world;
  final Vector3 position;
  final Vector3 velocity;

  final double width;
  final double height;

  bool onGround = false;

  /// Whether the body hit something horizontally this frame; mobs read it
  /// as "time to jump".
  bool blockedHorizontally = false;

  static const double _eps = 1e-3;

  double get halfWidth => width / 2;

  Vector3 get center =>
      Vector3(position.x, position.y + height / 2, position.z);

  /// Moves the body by a vector, resolving collisions.
  void moveBy(double dx, double dy, double dz) {
    blockedHorizontally = false;
    _axis(0, dx);
    _axis(1, dy);
    _axis(2, dz);
  }

  /// The usual physics step: gravity, then movement.
  void stepPhysics(double dt, {double gravity = 28, double terminal = 60}) {
    velocity.y -= gravity * dt;
    if (velocity.y < -terminal) velocity.y = -terminal;
    onGround = false;
    moveBy(velocity.x * dt, velocity.y * dt, velocity.z * dt);
  }

  /// Whether the box occupies the cell (x, y, z).
  bool occupies(int bx, int by, int bz) {
    return bx + 1 > position.x - halfWidth &&
        bx < position.x + halfWidth &&
        by + 1 > position.y &&
        by < position.y + height &&
        bz + 1 > position.z - halfWidth &&
        bz < position.z + halfWidth;
  }

  void _axis(int axis, double delta) {
    if (delta == 0) return;

    // Long moves are split, so a thin wall cannot be skipped over.
    final steps = math.max(1, (delta.abs() / 0.45).ceil());
    final part = delta / steps;

    for (var i = 0; i < steps; i++) {
      _set(axis, _get(axis) + part);
      if (!collides()) continue;

      // Snap exactly to the block's edge.
      if (part > 0) {
        final maxEdge = _get(axis) + (axis == 1 ? height : halfWidth);
        _set(
          axis,
          maxEdge.floorToDouble() - (axis == 1 ? height : halfWidth) - _eps,
        );
      } else {
        final minEdge = _get(axis) - (axis == 1 ? 0 : halfWidth);
        _set(
          axis,
          minEdge.floorToDouble() + 1 + (axis == 1 ? 0 : halfWidth) + _eps,
        );
        if (axis == 1) onGround = true;
      }

      switch (axis) {
        case 0:
          velocity.x = 0;
          blockedHorizontally = true;
        case 1:
          velocity.y = 0;
        default:
          velocity.z = 0;
          blockedHorizontally = true;
      }
      return;
    }
  }

  double _get(int axis) => switch (axis) {
    0 => position.x,
    1 => position.y,
    _ => position.z,
  };

  void _set(int axis, double value) {
    switch (axis) {
      case 0:
        position.x = value;
      case 1:
        position.y = value;
      default:
        position.z = value;
    }
  }

  /// Whether the box intersects any solid block.
  bool collides() {
    final minX = (position.x - halfWidth + _eps).floor();
    final maxX = (position.x + halfWidth - _eps).floor();
    final minY = (position.y + _eps).floor();
    final maxY = (position.y + height - _eps).floor();
    final minZ = (position.z - halfWidth + _eps).floor();
    final maxZ = (position.z + halfWidth - _eps).floor();

    for (var y = minY; y <= maxY; y++) {
      for (var z = minZ; z <= maxZ; z++) {
        for (var x = minX; x <= maxX; x++) {
          if (world.isSolid(x, y, z)) return true;
        }
      }
    }
    return false;
  }

  /// Ray against box (slab test); `null` when it misses.
  double? rayDistance(Vector3 origin, Vector3 dir, double maxDistance) {
    final minX = position.x - halfWidth;
    final maxX = position.x + halfWidth;
    final minY = position.y;
    final maxY = position.y + height;
    final minZ = position.z - halfWidth;
    final maxZ = position.z + halfWidth;

    var near = 0.0;
    var far = maxDistance;

    bool slab(double o, double d, double lo, double hi) {
      if (d.abs() < 1e-9) return o >= lo && o <= hi;
      final t1 = (lo - o) / d;
      final t2 = (hi - o) / d;
      final tMin = math.min(t1, t2);
      final tMax = math.max(t1, t2);
      if (tMin > near) near = tMin;
      if (tMax < far) far = tMax;
      return near <= far;
    }

    if (!slab(origin.x, dir.x, minX, maxX)) return null;
    if (!slab(origin.y, dir.y, minY, maxY)) return null;
    if (!slab(origin.z, dir.z, minZ, maxZ)) return null;
    return near;
  }
}
