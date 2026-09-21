import 'dart:math' as math;

import 'package:flame_3d/components.dart';
import 'package:flame_3d/core.dart';
import 'package:flame_3d/graphics.dart';
import 'package:flame_3d/resources.dart';
import 'package:flutcraft_engine/src/render/atlas_texture.dart';
import 'package:flutcraft_engine/src/render/mesh_builder.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';

/// Oś, wokół której kołysze się kończyna.
enum SwingAxis { none, pitch, roll }

/// Jedna bryła modelu potwora wraz z opisem animacji.
class MobPart {
  MobPart({
    required this.mesh,
    required this.anchor,
    this.axis = SwingAxis.none,
    this.amount = 0,
    this.phase = 0,
  });

  final Mesh mesh;

  /// Punkt zaczepienia względem stóp potwora.
  final Vector3 anchor;

  final SwingAxis axis;

  /// Amplituda wychylenia w radianach.
  final double amount;

  /// Przesunięcie fazy, żeby kończyny nie machały zgodnie.
  final double phase;
}

/// Zestaw brył jednego gatunku - współdzielony przez wszystkie egzemplarze.
class MobModel {
  MobModel(this.parts);

  final List<MobPart> parts;
}

/// Buduje i cache'uje modele potworów oraz strzał.
class MobModels {
  MobModels(this.atlas)
    : _material = UnlitMaterial(albedoTexture: atlas.texture)
        ..cullMode = CullMode.backFace;

  final EngineAtlas atlas;
  final Material _material;
  final Map<MobKind, MobModel> _cache = {};
  Mesh? _arrow;

  MobModel forKind(MobKind kind) =>
      _cache.putIfAbsent(kind, () => _build(kind));

  Mesh get arrow => _arrow ??= _buildArrow();

  Mesh _box(
    double sx,
    double sy,
    double sz,
    Tile tile, {
    Tile? front,
    bool hanging = false,
  }) {
    final builder = MeshBuilder(atlas, _material);
    // `hanging` zaczepia bryłę górną krawędzią, żeby obracała się jak
    // wahadło wokół barku albo biodra.
    final minY = hanging ? -sy : 0.0;
    builder.addBox(
      Vector3(-sx / 2, minY, -sz / 2),
      Vector3(sx / 2, minY + sy, sz / 2),
      tile,
      front: front,
    );
    return builder.build()!;
  }

  Mesh _buildArrow() {
    final builder = MeshBuilder(atlas, _material);
    builder
      ..addBox(
        Vector3(-0.03, -0.03, -0.28),
        Vector3(0.03, 0.03, 0.22),
        Tile.handle,
      )
      ..addBox(
        Vector3(-0.045, -0.045, -0.36),
        Vector3(0.045, 0.045, -0.26),
        Tile.ironIngotIcon,
      );
    return builder.build()!;
  }

  MobModel _build(MobKind kind) => switch (kind) {
    MobKind.zombie => _humanoid(kind, armForward: true),
    MobKind.skeleton => _humanoid(kind, slim: true),
    MobKind.spider => _spider(kind),
    MobKind.creeper => _creeper(kind),
  };

  /// Zombie i szkielet: ta sama sylwetka, inne proporcje.
  MobModel _humanoid(
    MobKind kind, {
    bool slim = false,
    bool armForward = false,
  }) {
    final limb = slim ? 0.13 : 0.17;
    final torsoWidth = slim ? 0.42 : 0.5;
    final skin = kind.skin;

    return MobModel([
      MobPart(
        mesh: _box(limb, 0.85, limb, skin, hanging: true),
        anchor: Vector3(-0.11, 0.85, 0),
        axis: SwingAxis.pitch,
        amount: 0.7,
      ),
      MobPart(
        mesh: _box(limb, 0.85, limb, skin, hanging: true),
        anchor: Vector3(0.11, 0.85, 0),
        axis: SwingAxis.pitch,
        amount: 0.7,
        phase: math.pi,
      ),
      MobPart(
        mesh: _box(torsoWidth, 0.6, 0.26, skin),
        anchor: Vector3(0, 0.85, 0),
      ),
      MobPart(
        mesh: _box(limb, 0.6, limb, skin, hanging: true),
        anchor: Vector3(-(torsoWidth / 2 + limb / 2), 1.42, 0),
        axis: SwingAxis.pitch,
        // Zombie trzyma ręce wyciągnięte przed siebie.
        amount: armForward ? 0.25 : 0.55,
        phase: math.pi,
      ),
      MobPart(
        mesh: _box(limb, 0.6, limb, skin, hanging: true),
        anchor: Vector3(torsoWidth / 2 + limb / 2, 1.42, 0),
        axis: SwingAxis.pitch,
        amount: armForward ? 0.25 : 0.55,
      ),
      MobPart(
        mesh: _box(0.5, 0.5, 0.5, skin, front: kind.face),
        anchor: Vector3(0, 1.45, 0),
      ),
    ]);
  }

  MobModel _spider(MobKind kind) {
    final parts = <MobPart>[
      MobPart(
        mesh: _box(0.72, 0.5, 0.72, kind.skin),
        anchor: Vector3(0, 0.22, 0.28),
      ),
      MobPart(
        mesh: _box(0.46, 0.42, 0.46, kind.skin, front: kind.face),
        anchor: Vector3(0, 0.26, -0.42),
      ),
    ];

    // Osiem odnóży, po cztery na stronę, machających w przeciwfazach.
    for (var i = 0; i < 4; i++) {
      final z = -0.25 + i * 0.22;
      for (final side in const [-1.0, 1.0]) {
        parts.add(
          MobPart(
            mesh: _box(0.08, 0.55, 0.08, kind.skin, hanging: true),
            anchor: Vector3(side * 0.34, 0.5, z),
            axis: SwingAxis.roll,
            amount: 0.45 * side,
            phase: i * math.pi / 2,
          ),
        );
      }
    }
    return MobModel(parts);
  }

  MobModel _creeper(MobKind kind) {
    final parts = <MobPart>[
      MobPart(
        mesh: _box(0.42, 0.8, 0.26, kind.skin),
        anchor: Vector3(0, 0.4, 0),
      ),
      MobPart(
        mesh: _box(0.5, 0.5, 0.5, kind.skin, front: kind.face),
        anchor: Vector3(0, 1.2, 0),
      ),
    ];

    for (final (i, offset) in const [
      (0, [-0.12, -0.13]),
      (1, [0.12, -0.13]),
      (2, [-0.12, 0.13]),
      (3, [0.12, 0.13]),
    ]) {
      parts.add(
        MobPart(
          mesh: _box(0.2, 0.4, 0.2, kind.skin, hanging: true),
          anchor: Vector3(offset[0], 0.4, offset[1]),
          axis: SwingAxis.pitch,
          amount: 0.5,
          phase: i.isEven ? 0 : math.pi,
        ),
      );
    }
    return MobModel(parts);
  }
}

/// Komponent renderujący jednego potwora.
class MobComponent extends Component3D {
  MobComponent({required this.mob, required MobModel model}) {
    for (final part in model.parts) {
      final component = MeshComponent(
        mesh: part.mesh,
        position: part.anchor.clone(),
      );
      _parts.add((part, component));
      add(component);
    }
  }

  final Mob mob;
  final List<(MobPart, MeshComponent)> _parts = [];

  /// Przepisuje stan logiczny potwora na transformacje komponentów.
  void sync() {
    position.setValues(mob.position.x, mob.position.y, mob.position.z);
    rotation.setFrom(Quaternion.axisAngle(Vector3(0, 1, 0), mob.yaw));

    // Trafienie i tykający lont creepera sygnalizujemy pulsem skali -
    // meshe są współdzielone, więc nie da się zmienić im koloru.
    var pulse = 1.0;
    if (mob.hurtFlash > 0) {
      pulse += mob.hurtFlash * 0.7;
    }
    if (mob.isPrimed) {
      pulse += 0.18 + 0.18 * math.sin(mob.fuse * 22);
    }
    scale.setValues(pulse, pulse, pulse);

    // Stojący potwór tylko leciutko się buja, idący macha pełną amplitudą.
    final damping = mob.walkSpeed > 0.2 ? 1.0 : 0.15;
    for (final (part, component) in _parts) {
      if (part.axis == SwingAxis.none) continue;
      final angle =
          math.sin(mob.walkPhase + part.phase) * part.amount * damping;
      component.rotation.setFrom(
        Quaternion.axisAngle(
          part.axis == SwingAxis.pitch ? Vector3(1, 0, 0) : Vector3(0, 0, 1),
          angle,
        ),
      );
    }
  }
}

/// Komponent renderujący lecącą strzałę.
class ArrowComponent extends MeshComponent {
  ArrowComponent({required this.arrow, required super.mesh});

  final Arrow arrow;

  void sync() {
    position.setValues(arrow.position.x, arrow.position.y, arrow.position.z);
    rotation.setFrom(
      Quaternion.axisAngle(Vector3(0, 1, 0), arrow.yaw) *
          Quaternion.axisAngle(Vector3(1, 0, 0), arrow.pitch),
    );
  }
}
