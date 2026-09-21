import 'package:flame_3d/core.dart';
import 'package:flame_3d/resources.dart';
import 'package:flutcraft/src/render/atlas.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';

/// Jedna z sześciu ścian sześcianu jednostkowego.
///
/// [corners] są w kolejności CCW patrząc z zewnątrz (Impeller traktuje
/// counter-clockwise jako front face), więc culling tylnych ścian działa.
class Face {
  const Face._(this.dx, this.dy, this.dz, this.shade, this.corners);

  final int dx;
  final int dy;
  final int dz;
  final Shade shade;
  final List<List<double>> corners;

  static const up = Face._(0, 1, 0, Shade.top, [
    [0, 1, 0],
    [0, 1, 1],
    [1, 1, 1],
    [1, 1, 0],
  ]);
  static const down = Face._(0, -1, 0, Shade.bottom, [
    [0, 0, 0],
    [1, 0, 0],
    [1, 0, 1],
    [0, 0, 1],
  ]);
  static const north = Face._(0, 0, -1, Shade.sideZ, [
    [1, 0, 0],
    [0, 0, 0],
    [0, 1, 0],
    [1, 1, 0],
  ]);
  static const south = Face._(0, 0, 1, Shade.sideZ, [
    [0, 0, 1],
    [1, 0, 1],
    [1, 1, 1],
    [0, 1, 1],
  ]);
  static const east = Face._(1, 0, 0, Shade.sideX, [
    [1, 0, 1],
    [1, 0, 0],
    [1, 1, 0],
    [1, 1, 1],
  ]);
  static const west = Face._(-1, 0, 0, Shade.sideX, [
    [0, 0, 0],
    [0, 0, 1],
    [0, 1, 1],
    [0, 1, 0],
  ]);

  static const values = [up, down, north, south, east, west];

  /// Kafelek, jakim malowana jest ta ściana danego bloku.
  Tile tileOf(BlockType block) => switch (this) {
    Face.up => block.topTile,
    Face.down => block.bottomTile,
    // Wyróżniona ściana (np. palenisko pieca) zawsze patrzy na północ.
    Face.north => block.frontTile ?? block.sideTile,
    _ => block.sideTile,
  };
}

/// Zbiera quady i wypuszcza gotowy [Mesh].
///
/// Indeksy w [Surface] są 16-bitowe, więc builder sam rozbija geometrię na
/// kolejne powierzchnie po przekroczeniu limitu wierzchołków.
class MeshBuilder {
  MeshBuilder(this.atlas, this.material);

  final TextureAtlas atlas;
  final Material material;

  /// 16 000 quadów = 64 000 wierzchołków, tuż pod limitem uint16.
  static const int _maxQuadsPerSurface = 16000;

  final List<Surface> _surfaces = [];
  List<Vertex> _vertices = [];
  List<int> _indices = [];
  int _quads = 0;

  // Wektory są kopiowane wewnątrz `Vertex`, więc można je bezpiecznie
  // recyklingować zamiast alokować 4 sztuki na quad.
  final Vector3 _p = Vector3.zero();
  final Vector2 _t = Vector2.zero();
  final Vector3 _n = Vector3.zero();

  bool get isEmpty => _surfaces.isEmpty && _quads == 0;

  int get quadCount =>
      _quads + _surfaces.fold(0, (sum, s) => sum + s.vertexCount ~/ 4);

  /// Dokłada ścianę [face] bloku o rogu w (x, y, z), skalując sześcian
  /// jednostkowy do [size].
  void addFace(
    double x,
    double y,
    double z,
    Face face,
    Tile tile, {
    double size = 1,
    Shade? shadeOverride,
  }) {
    final uv = atlas.uv(tile, shadeOverride ?? face.shade);
    final base = _vertices.length;

    // a,b to dolna krawędź (v1), c,d górna (v0) - tekstura stoi pionowo.
    const us = [0, 1, 1, 0];
    const vs = [1, 1, 0, 0];

    _n.setValues(face.dx.toDouble(), face.dy.toDouble(), face.dz.toDouble());

    for (var i = 0; i < 4; i++) {
      final c = face.corners[i];
      _p.setValues(x + c[0] * size, y + c[1] * size, z + c[2] * size);
      _t.setValues(us[i] == 0 ? uv.u0 : uv.u1, vs[i] == 0 ? uv.v0 : uv.v1);
      _vertices.add(Vertex(position: _p, texCoord: _t, normal: _n));
    }

    _indices
      ..add(base)
      ..add(base + 1)
      ..add(base + 2)
      ..add(base + 2)
      ..add(base + 3)
      ..add(base);

    if (++_quads >= _maxQuadsPerSurface) {
      _flush();
    }
  }

  /// Prostopadłościan o dowolnych wymiarach - używany do modelu kilofa
  /// i trzymanego bloku.
  void addBox(Vector3 min, Vector3 max, Tile tile, {Tile? front}) {
    final size = max - min;
    for (final face in Face.values) {
      final faceTile = (front != null && face == Face.north) ? front : tile;
      final uv = atlas.uv(faceTile, face.shade);
      final base = _vertices.length;
      const us = [0, 1, 1, 0];
      const vs = [1, 1, 0, 0];

      _n.setValues(face.dx.toDouble(), face.dy.toDouble(), face.dz.toDouble());

      for (var i = 0; i < 4; i++) {
        final c = face.corners[i];
        _p.setValues(
          min.x + c[0] * size.x,
          min.y + c[1] * size.y,
          min.z + c[2] * size.z,
        );
        _t.setValues(us[i] == 0 ? uv.u0 : uv.u1, vs[i] == 0 ? uv.v0 : uv.v1);
        _vertices.add(Vertex(position: _p, texCoord: _t, normal: _n));
      }

      _indices
        ..add(base)
        ..add(base + 1)
        ..add(base + 2)
        ..add(base + 2)
        ..add(base + 3)
        ..add(base);
      if (++_quads >= _maxQuadsPerSurface) {
        _flush();
      }
    }
  }

  void _flush() {
    if (_vertices.isEmpty) return;
    _surfaces.add(
      Surface(
        vertices: _vertices,
        indices: _indices,
        material: material,
        calculateNormals: false,
      ),
    );
    _vertices = [];
    _indices = [];
    _quads = 0;
  }

  /// Zwraca gotową siatkę albo `null`, jeśli nic nie dodano.
  Mesh? build() {
    _flush();
    if (_surfaces.isEmpty) return null;
    final mesh = Mesh();
    for (final surface in _surfaces) {
      mesh.addSurface(surface);
    }
    _surfaces.clear();
    return mesh;
  }
}
