import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';

void main() {
  group('VoxelWorld', () {
    test('zapis bloku oznacza chunk i sąsiadów na granicy', () {
      final world = VoxelWorld(sizeX: 32, sizeY: 16, sizeZ: 32)
        ..dirtyChunks.clear();

      world.setBlock(5, 5, 5, BlockType.stone);
      expect(world.dirtyChunks, {0});

      world.dirtyChunks.clear();
      // x == 0 dotyka chunku po lewej (poza mapą) i własnego.
      world.setBlock(16, 5, 5, BlockType.stone);
      expect(world.dirtyChunks, {0, 1});
    });

    test('poza granicami czyta się powietrze i nie da się pisać', () {
      final world = VoxelWorld(sizeX: 16, sizeY: 16, sizeZ: 16);
      expect(world.blockAt(-1, 0, 0), BlockType.air);
      expect(world.blockAt(0, 99, 0), BlockType.air);
      world.setBlock(-1, 0, 0, BlockType.stone);
      expect(world.blockAt(-1, 0, 0), BlockType.air);
    });

    test('raycast trafia blok i zwraca normalną ściany', () {
      final world = VoxelWorld(sizeX: 16, sizeY: 16, sizeZ: 16)
        ..setRaw(5, 2, 2, BlockType.stone);

      final hit = world.raycast(Vector3(0.5, 2.5, 2.5), Vector3(1, 0, 0), 10);

      expect(hit, isNotNull);
      expect((hit!.x, hit.y, hit.z), (5, 2, 2));
      expect(hit.block, BlockType.stone);
      // Weszliśmy od strony -X, więc blok stawiamy o jeden w lewo.
      expect((hit.nx, hit.ny, hit.nz), (-1, 0, 0));
      expect(hit.placement, (4, 2, 2));
      expect(hit.distance, closeTo(4.5, 1e-9));
    });

    test('raycast nie trafia nic poza zasięgiem', () {
      final world = VoxelWorld(sizeX: 16, sizeY: 16, sizeZ: 16)
        ..setRaw(10, 2, 2, BlockType.stone);
      final hit = world.raycast(Vector3(0.5, 2.5, 2.5), Vector3(1, 0, 0), 5);
      expect(hit, isNull);
    });

    test('raycast po skosie trafia w ścianę od właściwej strony', () {
      final world = VoxelWorld(sizeX: 16, sizeY: 16, sizeZ: 16)
        ..setRaw(3, 3, 3, BlockType.stone);
      final dir = Vector3(1, 1, 1)..normalize();
      final hit = world.raycast(Vector3(0.5, 0.5, 0.5), dir, 20);
      expect(hit, isNotNull);
      expect((hit!.x, hit.y, hit.z), (3, 3, 3));
      // Normalna zawsze wskazuje na dokładnie jedną oś.
      expect(hit.nx.abs() + hit.ny.abs() + hit.nz.abs(), 1);
    });

    test('surfaceHeight zwraca najwyższy blok stały', () {
      final world = VoxelWorld(sizeX: 16, sizeY: 16, sizeZ: 16)
        ..setRaw(1, 0, 1, BlockType.stone)
        ..setRaw(1, 7, 1, BlockType.grass);
      expect(world.surfaceHeight(1, 1), 7);
      expect(world.surfaceHeight(2, 2), -1);
    });
  });

  group('Player', () {
    VoxelWorld flatWorld() {
      final world = VoxelWorld(sizeX: 32, sizeY: 16, sizeZ: 32);
      for (var z = 0; z < 32; z++) {
        for (var x = 0; x < 32; x++) {
          world.setRaw(x, 0, z, BlockType.stone);
        }
      }
      return world;
    }

    test('grawitacja sadza gracza dokładnie na podłożu', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(8.5, 6, 8.5));

      for (var i = 0; i < 120; i++) {
        player.update(1 / 60, MoveInput());
      }

      expect(player.onGround, isTrue);
      expect(player.position.y, closeTo(1, 0.01));
      expect(player.velocity.y, 0);
    });

    test('ściana zatrzymuje ruch w poziomie', () {
      final world = flatWorld();
      for (var y = 1; y <= 3; y++) {
        world.setRaw(12, y, 8, BlockType.stone);
      }
      final player = Player(world: world, spawn: Vector3(8.5, 1, 8.5))..yaw = 0;

      // yaw = 0 to kierunek -Z; obracamy o -90 stopni, żeby iść w +X.
      player.yaw = -1.5707963267948966;
      for (var i = 0; i < 240; i++) {
        player.update(1 / 60, MoveInput(forward: 1));
      }

      // 12 - połowa szerokości gracza = 11.7.
      expect(player.position.x, lessThan(11.71));
      expect(player.position.x, greaterThan(11.6));
    });

    test('skok podnosi gracza i wraca na ziemię', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(8.5, 1, 8.5));
      player.update(1 / 60, MoveInput());

      player.update(1 / 60, MoveInput(jump: true));
      expect(player.velocity.y, greaterThan(0));

      var peak = player.position.y;
      for (var i = 0; i < 120; i++) {
        player.update(1 / 60, MoveInput());
        if (player.position.y > peak) peak = player.position.y;
      }
      expect(peak, greaterThan(2));
      expect(player.position.y, closeTo(1, 0.01));
    });

    test('occupies wykrywa blok wewnątrz bryły gracza', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(8.5, 1, 8.5));
      expect(player.occupies(8, 1, 8), isTrue);
      expect(player.occupies(8, 2, 8), isTrue);
      expect(player.occupies(8, 3, 8), isFalse);
      expect(player.occupies(10, 1, 8), isFalse);
    });

    test('lot ignoruje grawitację', () {
      final world = flatWorld();
      final player = Player(world: world, spawn: Vector3(8.5, 5, 8.5))
        ..flying = true;
      for (var i = 0; i < 60; i++) {
        player.update(1 / 60, MoveInput());
      }
      expect(player.position.y, 5);
    });
  });

  group('TerrainGenerator', () {
    test('ten sam seed daje ten sam teren', () {
      VoxelWorld build() {
        final world = VoxelWorld(sizeX: 32, sizeY: 48, sizeZ: 32);
        TerrainGenerator(seed: 7).generate(world);
        return world;
      }

      final a = build();
      final b = build();
      for (var z = 0; z < 32; z += 5) {
        for (var x = 0; x < 32; x += 5) {
          expect(a.surfaceHeight(x, z), b.surfaceHeight(x, z));
        }
      }
    });

    test('każda kolumna ma bedrock na dole i powierzchnię nad nim', () {
      final world = VoxelWorld(sizeX: 32, sizeY: 48, sizeZ: 32);
      TerrainGenerator(seed: 7).generate(world);

      for (var z = 0; z < 32; z += 3) {
        for (var x = 0; x < 32; x += 3) {
          expect(world.blockAt(x, 0, z), BlockType.bedrock);
          final h = world.surfaceHeight(x, z);
          expect(h, greaterThan(0));
          expect(world.blockAt(x, h + 1, z), BlockType.air);
        }
      }
    });
  });

  group('BlockType', () {
    final rng = math.Random(1);
    ItemType? dropType(BlockType block, ItemType? tool) {
      final drops = blockDrops(block, tool, rng);
      return drops.isEmpty ? null : drops.single.type;
    }

    test('kamień i trawa dają inny drop niż same siebie', () {
      expect(
        dropType(BlockType.stone, ItemType.woodenPickaxe),
        ItemType.cobblestone,
      );
      expect(dropType(BlockType.grass, null), ItemType.dirt);
      expect(dropType(BlockType.sand, null), ItemType.sand);
    });

    test('bez odpowiedniego kilofa blok nie daje nic', () {
      expect(dropType(BlockType.stone, null), isNull);
      expect(dropType(BlockType.ironOre, ItemType.woodenPickaxe), isNull);
      expect(
        dropType(BlockType.ironOre, ItemType.stonePickaxe),
        ItemType.rawIron,
      );
    });

    test('piec zawsze wraca jako zwykły piec', () {
      expect(
        dropType(BlockType.furnaceLit, ItemType.stonePickaxe),
        ItemType.furnace,
      );
    });

    test('liście i bedrock nie dają nic', () {
      expect(blockDrops(BlockType.leaves, null, rng), isEmpty);
      expect(blockDrops(BlockType.bedrock, ItemType.ironPickaxe, rng), isEmpty);
    });

    test('bedrock jest niezniszczalny', () {
      expect(BlockType.bedrock.breakable, isFalse);
      expect(BlockType.stone.breakable, isTrue);
    });

    test('trawa ma trzy różne tekstury ścian', () {
      expect(BlockType.grass.topTile, isNot(BlockType.grass.sideTile));
      expect(BlockType.grass.sideTile, isNot(BlockType.grass.bottomTile));
    });
  });
}
