import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';
import '../physics/voxel_body.dart';

/// Stan wejścia przekazywany do gracza w każdej klatce.
class MoveInput {
  MoveInput({
    this.forward = 0,
    this.strafe = 0,
    this.jump = false,
    this.crouch = false,
    this.sprint = false,
  });

  /// -1 (do tyłu) .. 1 (do przodu)
  final double forward;

  /// -1 (w lewo) .. 1 (w prawo)
  final double strafe;

  final bool jump;
  final bool crouch;
  final bool sprint;
}

/// Gracz: bryła AABB plus kamera, zdrowie i sterowanie.
class Player extends VoxelBody {
  Player({required super.world, required super.spawn})
    : super(width: 0.6, height: 1.8);

  static const double eyeHeight = 1.62;
  static const double walkSpeed = 4.6;
  static const double sprintSpeed = 7.2;
  static const double flySpeed = 11.0;
  static const double gravity = 28.0;
  static const double jumpSpeed = 8.6;

  static const int maxHealth = 20;

  /// Obrót w poziomie (radiany). 0 = patrzenie w -Z.
  double yaw = 0;

  /// Obrót w pionie, ograniczony do +/- 89 stopni.
  double pitch = 0;

  bool flying = false;

  int health = maxHealth;

  /// Chwilowa nietykalność po otrzymaniu ciosu (jak w oryginale).
  double hurtCooldown = 0;

  /// Rośnie przy trafieniu, żeby HUD mógł mrugnąć na czerwono.
  double hurtFlash = 0;

  /// Ile sekund minęło od ostatniego ciosu - po chwili spokoju gracz
  /// się regeneruje (w prototypie nie ma jedzenia).
  double timeSinceHurt = 999;

  double _regenTimer = 0;

  /// Po tylu sekundach bez obrażeń zaczyna się regeneracja.
  static const double regenDelay = 6.0;

  /// Co ile sekund wraca jeden punkt życia.
  static const double regenInterval = 3.0;

  bool get isDead => health <= 0;

  Vector3 get eye => Vector3(position.x, position.y + eyeHeight, position.z);

  /// Kierunek patrzenia (znormalizowany).
  Vector3 get lookDirection {
    final cp = math.cos(pitch);
    return Vector3(
      -math.sin(yaw) * cp,
      math.sin(pitch),
      -math.cos(yaw) * cp,
    )..normalize();
  }

  /// Kierunek "w prawo" w płaszczyźnie poziomej.
  Vector3 get rightDirection => Vector3(math.cos(yaw), 0, -math.sin(yaw));

  void look(double deltaYaw, double deltaPitch) {
    yaw = (yaw + deltaYaw) % (2 * math.pi);
    pitch = (pitch + deltaPitch).clamp(-1.5533, 1.5533);
  }

  void update(double dt, MoveInput input) {
    // Długie klatki (np. po przebudowie chunków) nie mogą przepchnąć
    // gracza przez ścianę.
    final step = math.min(dt, 1 / 30);

    if (hurtCooldown > 0) hurtCooldown -= dt;
    if (hurtFlash > 0) hurtFlash -= dt;
    _regenerate(dt);

    final speed = flying
        ? flySpeed
        : (input.sprint ? sprintSpeed : walkSpeed);

    final forward = Vector3(-math.sin(yaw), 0, -math.cos(yaw));
    final wish = forward * input.forward + rightDirection * input.strafe;
    if (wish.length2 > 1e-6) {
      wish
        ..normalize()
        ..scale(speed);
    }

    velocity
      ..x = wish.x
      ..z = wish.z;

    if (flying) {
      final vertical = (input.jump ? 1.0 : 0.0) - (input.crouch ? 1.0 : 0.0);
      velocity.y = vertical * flySpeed;
      onGround = false;
      moveBy(velocity.x * step, velocity.y * step, velocity.z * step);
    } else {
      if (input.jump && onGround) {
        velocity.y = jumpSpeed;
        onGround = false;
      }
      stepPhysics(step, gravity: gravity);
    }

    // Miękki mur na granicach mapy - świat jest skończony.
    position.x = position.x.clamp(halfWidth, world.sizeX - halfWidth);
    position.z = position.z.clamp(halfWidth, world.sizeZ - halfWidth);
    if (position.y < -20) {
      health = 0;
    }
  }

  void _regenerate(double dt) {
    timeSinceHurt += dt;
    if (isDead || health >= maxHealth || timeSinceHurt < regenDelay) {
      _regenTimer = 0;
      return;
    }
    _regenTimer += dt;
    if (_regenTimer < regenInterval) return;
    _regenTimer = 0;
    health++;
  }

  /// Zadaje graczowi obrażenia i odrzuca go od [source].
  ///
  /// Zwraca `false`, jeśli cios nie przeszedł przez nietykalność.
  bool damage(int amount, {Vector3? source}) {
    if (hurtCooldown > 0 || isDead) return false;
    health = math.max(0, health - amount);
    hurtCooldown = 0.55;
    hurtFlash = 0.35;
    timeSinceHurt = 0;
    _regenTimer = 0;

    if (source != null) {
      final push = Vector3(position.x - source.x, 0, position.z - source.z);
      if (push.length2 > 1e-6) {
        push
          ..normalize()
          ..scale(6.5);
        velocity
          ..x = push.x
          ..z = push.z;
        if (onGround) velocity.y = 4.5;
      }
    }
    return true;
  }

  void heal(int amount) {
    health = math.min(maxHealth, health + amount);
  }

  void respawn() {
    final x = world.sizeX ~/ 2;
    final z = world.sizeZ ~/ 2;
    final h = world.surfaceHeight(x, z);
    position.setValues(x + 0.5, h + 1.0, z + 0.5);
    velocity.setZero();
    health = maxHealth;
    hurtCooldown = 0;
    hurtFlash = 0;
    timeSinceHurt = 999;
    _regenTimer = 0;
  }
}
