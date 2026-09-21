import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

GameState solidState() {
  final world = VoxelWorld(sizeX: 32, sizeY: 16, sizeZ: 32);
  for (var y = 0; y < 8; y++) {
    for (var z = 0; z < 32; z++) {
      for (var x = 0; x < 32; x++) {
        world.setRaw(x, y, z, y == 0 ? BlockType.bedrock : BlockType.stone);
      }
    }
  }
  return GameState(
    world: world,
    player: Player(world: world, spawn: Vector3(16.5, 8, 16.5)),
    inventory: Inventory(),
  );
}

void main() {
  const system = ExplosionSystem();

  test('wybija kulisty krater', () {
    final state = solidState();
    system.explode(state, Vector3(16.5, 5.5, 16.5), 3, 10);

    expect(state.world.blockAt(16, 5, 16), BlockType.air, reason: 'środek');
    expect(
      state.world.blockAt(18, 5, 16),
      BlockType.air,
      reason: 'w promieniu',
    );
    expect(
      state.world.blockAt(16 + 5, 5, 16),
      BlockType.stone,
      reason: 'poza promieniem zostaje',
    );
  });

  test('bedrock przeżywa wybuch', () {
    final state = solidState();
    system.explode(state, Vector3(16.5, 0.5, 16.5), 4, 20);
    expect(state.world.blockAt(16, 0, 16), BlockType.bedrock);
  });

  test('piec w zasięgu znika też z rejestru', () {
    final state = solidState();
    state.world.setBlock(16, 5, 16, BlockType.furnace);
    state.furnaces.open(const BlockPos(16, 5, 16));

    system.explode(state, Vector3(16.5, 5.5, 16.5), 3, 10);

    expect(state.furnaces.isEmpty, isTrue);
  });

  test('rani gracza tym mocniej, im bliżej', () {
    int damageAt(double distance) {
      final state = solidState();
      final at = Vector3(16.5 + distance, 8.5, 16.5);
      system.explode(state, at, 3, 14);
      return Player.maxHealth - state.player.health;
    }

    final close = damageAt(0.5);
    final far = damageAt(3.2);
    expect(close, greaterThan(far));
    expect(far, greaterThan(0));
  });

  test('poza zasięgiem gracz nie obrywa', () {
    final state = solidState();
    system.explode(state, Vector3(16.5 + 12, 8.5, 16.5), 3, 14);
    expect(state.player.health, Player.maxHealth);
  });

  test('rani też inne potwory', () {
    final state = solidState();
    final near = Mob(
      kind: MobKind.zombie,
      world: state.world,
      spawn: Vector3(17.0, 8, 16.5),
    );
    final far = Mob(
      kind: MobKind.zombie,
      world: state.world,
      spawn: Vector3(16.5 + 20, 8, 16.5),
    );
    state.mobs.addAll([near, far]);

    system.explode(state, Vector3(16.5, 8.5, 16.5), 3, 14);

    expect(near.health, lessThan(MobKind.zombie.maxHealth));
    expect(far.health, MobKind.zombie.maxHealth);
  });

  test('zgłasza dokładnie jedno zdarzenie', () {
    final state = solidState();
    final events = system.explode(state, Vector3(16.5, 5.5, 16.5), 3, 10);
    expect(events, hasLength(1));
    expect(events.single, isA<CreeperExploded>());
  });

  test('minimalne obrażenia to jeden punkt, nie zero', () {
    final state = solidState();
    // Na samej krawędzi zasięgu falloff jest bliski zeru.
    system.explode(state, Vector3(16.5 + 3.9, 8.5, 16.5), 3, 14);
    expect(state.player.health, lessThan(Player.maxHealth));
  });
}
