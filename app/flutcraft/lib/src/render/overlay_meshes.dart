import 'dart:ui' show Color;

import 'package:flame_3d/components.dart';
import 'package:flame_3d/core.dart';
import 'package:flame_3d/graphics.dart';
import 'package:flame_3d/resources.dart';
import 'package:flutcraft/src/render/atlas.dart';
import 'package:flutcraft/src/render/mesh_builder.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';

/// [MeshComponent], które można ukryć bez wyjmowania z drzewa komponentów.
class ToggleableMesh extends MeshComponent {
  ToggleableMesh({required super.mesh, super.position});

  bool visible = true;

  @override
  void draw(covariant RenderContext3D context) {
    if (!visible) return;
    super.draw(context);
  }
}

/// Czarna ramka podświetlająca blok pod celownikiem.
class SelectionBox extends ToggleableMesh {
  SelectionBox._(Mesh mesh) : super(mesh: mesh);

  factory SelectionBox.create(TextureAtlas atlas) {
    final material = UnlitMaterial(albedoColor: const Color(0xFF0A0A0A));
    final builder = MeshBuilder(atlas, material);

    const t = 0.018; // grubość krawędzi
    const o = 0.004; // lekkie rozdęcie, żeby nie walczyło o Z z blokiem
    const lo = -o;
    const hi = 1 + o;

    void edge(Vector3 a, Vector3 b) => builder.addBox(a, b, Tile.bedrock);

    for (final y in const [lo, hi]) {
      for (final z in const [lo, hi]) {
        edge(Vector3(lo, y - t, z - t), Vector3(hi, y + t, z + t));
      }
    }
    for (final x in const [lo, hi]) {
      for (final z in const [lo, hi]) {
        edge(Vector3(x - t, lo, z - t), Vector3(x + t, hi, z + t));
      }
    }
    for (final x in const [lo, hi]) {
      for (final y in const [lo, hi]) {
        edge(Vector3(x - t, y - t, lo), Vector3(x + t, y + t, hi));
      }
    }

    return SelectionBox._(builder.build()!);
  }

  /// Ustawia ramkę na bloku o podanych współrzędnych.
  void target(int x, int y, int z) {
    position.setValues(x.toDouble(), y.toDouble(), z.toDouble());
  }
}

/// Fabryki siatek dla przedmiotu trzymanego w ręce.
class ItemMeshes {
  ItemMeshes(this.atlas)
    : _material = UnlitMaterial(albedoTexture: atlas.texture)
        ..cullMode = CullMode.backFace;

  final TextureAtlas atlas;
  final Material _material;
  final Map<ItemType, Mesh> _cache = {};

  /// Siatka dla przedmiotu w ręce; `null` oznacza pustą rękę.
  Mesh? forItem(ItemType? item) {
    if (item == null) return null;
    return _cache.putIfAbsent(item, () => _build(item));
  }

  Mesh _build(ItemType item) {
    if (item.isBlock) return _buildCube(item.block!);
    return switch (item.tool) {
      ToolType.pickaxe => _buildPickaxe(_materialTile(item.tier)),
      ToolType.sword => _buildSword(_materialTile(item.tier)),
      _ => _buildFlat(item.icon),
    };
  }

  /// Drewno, kamień albo metal - zależnie od poziomu narzędzia.
  Tile _materialTile(int tier) => switch (tier) {
    1 => Tile.planks,
    2 => Tile.stone,
    _ => Tile.metal,
  };

  Mesh _buildPickaxe(Tile head) {
    final b = MeshBuilder(atlas, _material);
    // Trzonek wzdłuż osi Y.
    b.addBox(
      Vector3(-0.013, -0.17, -0.013),
      Vector3(0.013, 0.13, 0.013),
      Tile.handle,
    );
    // Poprzeczka głowicy.
    b.addBox(
      Vector3(-0.070, 0.115, -0.018),
      Vector3(0.070, 0.155, 0.018),
      head,
    );
    // Zaostrzone końce.
    b.addBox(
      Vector3(-0.105, 0.085, -0.015),
      Vector3(-0.070, 0.145, 0.015),
      head,
    );
    b.addBox(Vector3(0.070, 0.085, -0.015), Vector3(0.105, 0.145, 0.015), head);
    return b.build()!;
  }

  Mesh _buildSword(Tile blade) {
    final b = MeshBuilder(atlas, _material);
    // Rękojeść.
    b.addBox(
      Vector3(-0.014, -0.18, -0.014),
      Vector3(0.014, -0.06, 0.014),
      Tile.handle,
    );
    // Jelec.
    b.addBox(
      Vector3(-0.060, -0.075, -0.016),
      Vector3(0.060, -0.040, 0.016),
      Tile.metal,
    );
    // Ostrze.
    b.addBox(
      Vector3(-0.022, -0.040, -0.010),
      Vector3(0.022, 0.210, 0.010),
      blade,
    );
    return b.build()!;
  }

  /// Płaska tafla z ikoną - tak jak surowce wyglądają w oryginale.
  Mesh _buildFlat(Tile icon) {
    final b = MeshBuilder(atlas, _material);
    b.addBox(Vector3(-0.13, -0.13, -0.008), Vector3(0.13, 0.13, 0.008), icon);
    return b.build()!;
  }

  Mesh _buildCube(BlockType block) {
    final b = MeshBuilder(atlas, _material);
    const size = 0.22;
    for (final face in Face.values) {
      b.addFace(
        -size / 2,
        -size / 2,
        -size / 2,
        face,
        face.tileOf(block),
        size: size,
      );
    }
    return b.build()!;
  }
}
