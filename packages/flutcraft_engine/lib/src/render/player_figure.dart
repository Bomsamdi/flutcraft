import 'dart:math' as math;

import 'package:flame_3d/components.dart';
import 'package:flame_3d/core.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_engine/src/render/mob_renderer.dart';

/// Somebody else, seen across the world.
///
/// Not the player this client is playing — that one is the camera and has no
/// body to draw. This is everybody in the world through somebody else's eyes,
/// built from the same humanoid the mobs use so that a change to how a body
/// is put together shows up on people too.
class PlayerFigure extends Component3D {
  PlayerFigure({required this.participant, required MobModel model}) {
    for (final part in model.parts) {
      final component = MeshComponent(
        mesh: part.mesh,
        position: part.anchor.clone(),
      );
      _parts.add((part, component));
      add(component);
    }
  }

  final Participant participant;
  final List<(MobPart, MeshComponent)> _parts = [];

  double _phase = 0;

  /// Copies the other player's state onto the component transforms.
  void sync(double dt) {
    final player = participant.player;
    position.setValues(player.position.x, player.position.y, player.position.z);
    rotation.setFrom(Quaternion.axisAngle(Vector3(0, 1, 0), player.yaw));

    // A player's body has no walk cycle of its own — the simulation never
    // needed one, because a player is normally the camera. Speed on the
    // ground is enough to drive the legs.
    final speed = math.sqrt(
      player.velocity.x * player.velocity.x +
          player.velocity.z * player.velocity.z,
    );
    _phase += speed * dt * 3.2;

    final damping = speed > 0.2 ? 1.0 : 0.15;
    for (final (part, component) in _parts) {
      if (part.axis == SwingAxis.none) continue;
      final angle = math.sin(_phase + part.phase) * part.amount * damping;
      component.rotation.setFrom(
        Quaternion.axisAngle(
          part.axis == SwingAxis.pitch ? Vector3(1, 0, 0) : Vector3(0, 0, 1),
          angle,
        ),
      );
    }
  }
}
