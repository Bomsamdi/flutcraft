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

    expect(state.world.blockAt(16, 5, 16), BlockType.air, reason: 'the centre');
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

  test('bedrock survives an explosion', () {
    final state = solidState();
    system.explode(state, Vector3(16.5, 0.5, 16.5), 4, 20);
    expect(state.world.blockAt(16, 0, 16), BlockType.bedrock);
  });

  test('a furnace in range leaves the registry too', () {
    final state = solidState();
    state.world.setBlock(16, 5, 16, BlockType.furnace);
    state.furnaces.open(const BlockPos(16, 5, 16));

    system.explode(state, Vector3(16.5, 5.5, 16.5), 3, 10);

    expect(state.furnaces.isEmpty, isTrue);
  });

  test('it hurts the player more the closer they are', () {
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

  test('out of range the player is untouched', () {
    final state = solidState();
    system.explode(state, Vector3(16.5 + 12, 8.5, 16.5), 3, 14);
    expect(state.player.health, Player.maxHealth);
  });

  test('it hurts other mobs as well', () {
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

  test('it reports exactly one event', () {
    final state = solidState();
    final events = system.explode(state, Vector3(16.5, 5.5, 16.5), 3, 10);
    expect(events, hasLength(1));
    expect(events.single, isA<CreeperExploded>());
  });

  test('the minimum damage is one point, not zero', () {
    final state = solidState();
    // Right at the edge of the radius the falloff is nearly zero.
    system.explode(state, Vector3(16.5 + 3.9, 8.5, 16.5), 3, 14);
    expect(state.player.health, lessThan(Player.maxHealth));
  });
}
