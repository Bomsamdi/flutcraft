import 'package:flame_3d/camera.dart';
import 'package:flame_3d/core.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';

/// A camera with sensible near and far planes.
///
/// [CameraComponent3D] hard-codes near = 0.01 and far = 1000, which in a
/// voxel world means visible z-fighting, so the projection is overridden
/// here.
class VoxelCamera extends CameraComponent3D {
  VoxelCamera({required super.world, super.fovY = 70});

  static const double near = 0.06;
  static const double far = 260;

  final Matrix4 _projection = Matrix4.zero();

  /// Sits the camera in the player's eyes and looks where they look.
  void followPlayer(Player player) {
    final eye = player.eye;
    final dir = player.lookDirection;
    position.setFrom(eye);
    target.setValues(eye.x + dir.x, eye.y + dir.y, eye.z + dir.z);
  }

  @override
  Matrix4 get projectionMatrix => _projection
    ..setAsPerspective(
      fovY,
      viewport.virtualSize.x / viewport.virtualSize.y,
      near,
      far,
    );
}
