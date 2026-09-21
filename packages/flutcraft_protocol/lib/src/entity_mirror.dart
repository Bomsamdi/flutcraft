import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:vector_math/vector_math.dart';

import 'messages.dart';
import 'wire_values.dart';

/// Keeps a client's mobs and arrows in step with the server's.
///
/// The one rule that matters: an entity already known is **written into**,
/// never rebuilt. The renderer keeps one component per entity in a map keyed
/// by the object itself, so a mirror that constructed a fresh `Mob` for every
/// packet would make it drop and re-add every component twenty times a
/// second. The mobs would flicker and nothing could be smoothed.
class EntityMirror {
  EntityMirror({this.smoothing = 0.05});

  /// How long a mob takes to slide to a newly reported position, in seconds.
  ///
  /// One snapshot period, which leaves what is drawn trailing the truth by
  /// about that much. Extrapolating instead would be worse: a player who
  /// stops walking would carry on through a wall and then snap back.
  final double smoothing;

  final Map<EntityId, Mob> _mobs = {};
  final Map<EntityId, Arrow> _arrows = {};
  final Map<EntityId, _Glide> _glides = {};

  /// How many mobs the mirror is holding. Useful in tests.
  int get length => _mobs.length + _arrows.length;

  /// Applies what the server said about the entities.
  void apply(EntityDelta delta, GameState state) {
    for (final reported in delta.mobs) {
      final mob = _mobs[reported.id];
      if (mob == null) {
        _addMob(reported, state);
        continue;
      }
      mob
        ..yaw = reported.yaw
        ..health = reported.health
        ..walkSpeed = reported.walkSpeed
        ..fuse = reported.fuse;
      _glides[reported.id] = _Glide(mob.position.clone(), reported.position);
    }

    for (final reported in delta.arrows) {
      final arrow = _arrows[reported.id];
      if (arrow == null) {
        _addArrow(reported, state);
        continue;
      }
      arrow
        ..yaw = reported.yaw
        ..pitch = reported.pitch;
      _glides[reported.id] = _Glide(arrow.position.clone(), reported.position);
    }

    for (final id in delta.gone) {
      final mob = _mobs.remove(id);
      if (mob != null) state.mobs.remove(mob);
      final arrow = _arrows.remove(id);
      if (arrow != null) state.arrows.remove(arrow);
      _glides.remove(id);
    }
  }

  /// Slides every mirrored entity a little further towards where the server
  /// last said it was.
  void advance(double dt) {
    for (final entry in _glides.entries) {
      final body = _mobs[entry.key] ?? _arrows[entry.key];
      if (body == null) continue;
      entry.value.advance(dt / smoothing, body.position);
    }
  }

  void _addMob(MobState reported, GameState state) {
    final mob =
        Mob(kind: reported.kind, world: state.world, spawn: reported.position)
          ..id = reported.id
          ..yaw = reported.yaw
          ..health = reported.health
          ..walkSpeed = reported.walkSpeed
          ..fuse = reported.fuse;
    _mobs[reported.id] = mob;
    state.mobs.add(mob);
  }

  void _addArrow(ArrowState reported, GameState state) {
    final arrow =
        Arrow(
            world: state.world,
            spawn: reported.position,
            direction: Vector3(0, 0, 1),
          )
          ..id = reported.id
          ..yaw = reported.yaw
          ..pitch = reported.pitch;
    _arrows[reported.id] = arrow;
    state.arrows.add(arrow);
  }
}

/// A slide from where something was drawn to where it turned out to be.
class _Glide {
  _Glide(this.from, this.to);

  final Vector3 from;
  final Vector3 to;
  double t = 0;

  void advance(double step, Vector3 into) {
    t = (t + step).clamp(0.0, 1.0);
    into.setFrom(from + (to - from) * t);
  }
}
