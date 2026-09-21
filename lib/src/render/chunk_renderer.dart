import 'package:flame/components.dart' show Component;
import 'package:flame_3d/camera.dart';
import 'package:flame_3d/components.dart';
import 'package:flame_3d/core.dart';
import 'package:flame_3d/graphics.dart';
import 'package:flame_3d/resources.dart';
import 'package:flutcraft/src/render/atlas.dart';
import 'package:flutcraft/src/render/mesh_builder.dart';
import 'package:flutcraft/src/world/voxel_world.dart';

/// Jeden chunk świata jako obiekt renderowany.
///
/// W odróżnieniu od [MeshComponent] siatka jest wymienialna - po zbiciu
/// lub postawieniu bloku podmieniamy ją bez usuwania komponentu z drzewa.
class ChunkComponent extends Object3D {
  ChunkComponent({
    required this.cx,
    required this.cz,
    required int worldHeight,
  }) : _localAabb = Aabb3.minMax(
         Vector3.zero(),
         Vector3(
           VoxelWorld.chunkSize.toDouble(),
           worldHeight.toDouble(),
           VoxelWorld.chunkSize.toDouble(),
         ),
       ),
       super(
         position: Vector3(
           (cx * VoxelWorld.chunkSize).toDouble(),
           0,
           (cz * VoxelWorld.chunkSize).toDouble(),
         ),
       );

  final int cx;
  final int cz;
  final Aabb3 _localAabb;

  Mesh? _mesh;

  Mesh? get mesh => _mesh;

  set mesh(Mesh? value) {
    _mesh = value;
    markAabbDirty();
  }

  int get surfaceCount => _mesh?.surfaceCount ?? 0;

  int get vertexCount => _mesh?.vertexCount ?? 0;

  @override
  Aabb3? computeLocalAabb() => _localAabb;

  @override
  bool isVisible(CameraComponent3D camera) =>
      _mesh != null && camera.frustum.intersectsWithAabb3(aabb);

  @override
  void draw(covariant RenderContext3D context) {
    final mesh = _mesh;
    if (mesh == null) return;
    context
      ..model.setFrom(worldTransformMatrix)
      ..drawMesh(mesh);
  }
}

/// Buduje siatki chunków i rozkłada tę pracę na klatki.
///
/// Pełne przemielenie mapy 128x128 na raz zajmuje kilkaset ms, więc
/// kolejka przerabia [chunksPerFrame] chunków na klatkę, zaczynając od
/// tych najbliżej gracza.
class ChunkManager extends Component {
  ChunkManager({
    required this.world,
    required this.atlas,
    required this.material,
    this.chunksPerFrame = 2,
  });

  final VoxelWorld world;
  final TextureAtlas atlas;
  final Material material;
  final int chunksPerFrame;

  final Map<int, ChunkComponent> _chunks = {};

  /// Punkt odniesienia dla priorytetu przebudowy (pozycja gracza).
  final Vector3 focus = Vector3.zero();

  int get pendingChunks => world.dirtyChunks.length;

  int get totalChunks => world.chunksX * world.chunksZ;

  int get builtChunks => _chunks.values.where((c) => c.mesh != null).length;

  int get visibleVertices =>
      _chunks.values.fold(0, (sum, c) => sum + c.vertexCount);

  Iterable<ChunkComponent> get chunks => _chunks.values;

  /// Tworzy puste komponenty dla całej mapy; siatki dojdą w kolejce.
  List<ChunkComponent> createComponents() {
    for (var cz = 0; cz < world.chunksZ; cz++) {
      for (var cx = 0; cx < world.chunksX; cx++) {
        final key = cz * world.chunksX + cx;
        _chunks[key] = ChunkComponent(
          cx: cx,
          cz: cz,
          worldHeight: world.sizeY,
        );
      }
    }
    return _chunks.values.toList();
  }

  /// Buduje od razu [count] chunków najbliższych [focus] - używane na
  /// starcie, żeby gracz nie pojawił się w pustce.
  ///
  /// Wymaga wcześniejszego [createComponents].
  void prebuild(int count) {
    for (var i = 0; i < count && world.dirtyChunks.isNotEmpty; i++) {
      _rebuildNearest();
    }
  }

  @override
  void update(double dt) {
    for (var i = 0; i < chunksPerFrame && world.dirtyChunks.isNotEmpty; i++) {
      _rebuildNearest();
    }
  }

  void _rebuildNearest() {
    var bestKey = -1;
    var bestDistance = double.infinity;
    for (final key in world.dirtyChunks) {
      final cx = key % world.chunksX;
      final cz = key ~/ world.chunksX;
      final dx = (cx + 0.5) * VoxelWorld.chunkSize - focus.x;
      final dz = (cz + 0.5) * VoxelWorld.chunkSize - focus.z;
      final d = dx * dx + dz * dz;
      if (d < bestDistance) {
        bestDistance = d;
        bestKey = key;
      }
    }
    if (bestKey < 0) return;

    world.dirtyChunks.remove(bestKey);
    final chunk = _chunks[bestKey];
    if (chunk == null) return;
    chunk.mesh = _buildMesh(chunk.cx, chunk.cz);
  }

  Mesh? _buildMesh(int cx, int cz) {
    final builder = MeshBuilder(atlas, material);
    final originX = cx * VoxelWorld.chunkSize;
    final originZ = cz * VoxelWorld.chunkSize;

    for (var z = 0; z < VoxelWorld.chunkSize; z++) {
      for (var x = 0; x < VoxelWorld.chunkSize; x++) {
        final wx = originX + x;
        final wz = originZ + z;
        if (wx >= world.sizeX || wz >= world.sizeZ) continue;

        for (var y = 0; y < world.sizeY; y++) {
          final block = world.blockAt(wx, y, wz);
          if (!block.solid) continue;

          for (final face in Face.values) {
            // Ściana jest widoczna tylko wtedy, gdy sąsiad jej nie zasłania.
            if (world.isSolid(wx + face.dx, y + face.dy, wz + face.dz)) {
              continue;
            }
            builder.addFace(
              x.toDouble(),
              y.toDouble(),
              z.toDouble(),
              face,
              face.tileOf(block),
            );
          }
        }
      }
    }

    return builder.build();
  }
}
