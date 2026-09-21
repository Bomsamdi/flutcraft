import 'dart:math' as math;
import 'dart:ui' show Canvas;

import 'package:flame_3d/components.dart';
import 'package:flame_3d/core.dart';
import 'package:flame_3d/graphics.dart';
import 'package:flame_3d/resources.dart';

/// Przedmiot trzymany w ręce, rysowany tuż przed kamerą.
///
/// Nie przechodzi przez frustum culling - zawsze jest w kadrze, więc
/// [renderTree] od razu zgłasza go do rysowania (jako najbliższy obiekt
/// trafia na koniec posortowanej listy).
class HeldItem extends Object3D {
  HeldItem();

  Mesh? mesh;

  /// Postęp zamachu 0..1; 0 = ręka w spoczynku.
  double swing = 0;

  @override
  void renderTree(Canvas canvas) {
    if (mesh == null) return;
    world.context.submitDraw(this, worldTransformMatrix);
  }

  @override
  void draw(covariant RenderContext3D context) {
    context
      ..model.setFrom(worldTransformMatrix)
      ..drawMesh(mesh!);
  }

  /// Ustawia przedmiot względem kamery opisanej przez oko i kierunek patrzenia.
  void follow(Vector3 eye, Vector3 forward) {
    final right = forward.cross(Vector3(0, 1, 0))..normalize();
    final up = right.cross(forward)..normalize();
    final back = -forward;

    // Zamach: przedmiot cofa się i opada, po czym wraca.
    final s = math.sin(swing * math.pi);
    final offsetRight = 0.34 - s * 0.10;
    final offsetUp = -0.32 - s * 0.10;
    final offsetFwd = 0.52 + s * 0.06;

    position.setValues(
      eye.x + right.x * offsetRight + up.x * offsetUp + forward.x * offsetFwd,
      eye.y + right.y * offsetRight + up.y * offsetUp + forward.y * offsetFwd,
      eye.z + right.z * offsetRight + up.z * offsetUp + forward.z * offsetFwd,
    );

    final basis = Quaternion.fromRotation(
      Matrix3(
        right.x, right.y, right.z, //
        up.x, up.y, up.z, //
        back.x, back.y, back.z,
      ),
    );

    final tilt = Quaternion.axisAngle(Vector3(0, 0, 1), -0.55);
    final lean = Quaternion.axisAngle(Vector3(1, 0, 0), 0.30 - s * 1.25);

    rotation.setFrom((basis * tilt * lean)..normalize());
  }
}
