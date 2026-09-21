import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

GameState flatState({ItemType? held}) {
  final world = VoxelWorld(sizeX: 16, sizeY: 16, sizeZ: 16);
  for (var z = 0; z < 16; z++) {
    for (var x = 0; x < 16; x++) {
      world.setRaw(x, 0, z, BlockType.bedrock);
      world.setRaw(x, 1, z, BlockType.stone);
    }
  }
  final inventory = Inventory();
  if (held != null) inventory.add(held, 10);
  return GameState.solo(
    world: world,
    player: Player(world: world, spawn: Vector3(8.5, 2, 8.5)),
    inventory: inventory,
  );
}

/// A hit on the top face of (x, y, z) — a block would go above it.
RayHit topOf(GameState state, int x, int y, int z) => RayHit(
  x: x,
  y: y,
  z: z,
  block: state.world.blockAt(x, y, z),
  nx: 0,
  ny: 1,
  nz: 0,
  distance: 2,
);

void main() {
  late PlacementSystem system;

  setUp(() => system = PlacementSystem());

  test('the block lands on the side of the face that was hit', () {
    final state = flatState(held: ItemType.planks);
    state.solo.aim = BlockTarget(topOf(state, 5, 1, 5));

    final events = system.placeNow(state, state.solo);

    expect(events, isEmpty);
    expect(state.world.blockAt(5, 2, 5), BlockType.planks);
    expect(state.solo.inventory.countOf(ItemType.planks), 9);
  });

  test('a tool in hand is not a block', () {
    final state = flatState(held: ItemType.ironPickaxe);
    state.solo.aim = BlockTarget(topOf(state, 5, 1, 5));

    final events = system.placeNow(state, state.solo);

    expect(
      events.single,
      isA<PlacementRejected>().having(
        (e) => e.reason,
        'reason',
        PlacementRejection.notABlock,
      ),
    );
    expect(state.world.blockAt(5, 2, 5), BlockType.air);
  });

  test('an empty slot refuses too', () {
    final state = flatState();
    state.solo.aim = BlockTarget(topOf(state, 5, 1, 5));
    expect(system.placeNow(state, state.solo).single, isA<PlacementRejected>());
  });

  test('a block cannot be placed inside yourself', () {
    final state = flatState(held: ItemType.planks);
    // Gracz stoi na (8, 2, 8); celujemy w blok pod nim.
    state.solo.aim = BlockTarget(topOf(state, 8, 1, 8));

    final events = system.placeNow(state, state.solo);

    expect(
      events.single,
      isA<PlacementRejected>().having(
        (e) => e.reason,
        'reason',
        PlacementRejection.insidePlayer,
      ),
    );
  });

  test('a block cannot be placed inside a mob', () {
    final state = flatState(held: ItemType.planks);
    state.mobs.add(
      Mob(
        kind: MobKind.zombie,
        world: state.world,
        spawn: Vector3(5.5, 2, 5.5),
      ),
    );
    state.solo.aim = BlockTarget(topOf(state, 5, 1, 5));

    expect(
      system.placeNow(state, state.solo).single,
      isA<PlacementRejected>().having(
        (e) => e.reason,
        'reason',
        PlacementRejection.insideMob,
      ),
    );
  });

  test('an occupied cell simply does nothing', () {
    final state = flatState(held: ItemType.planks);
    state.world.setBlock(5, 2, 5, BlockType.dirt);
    state.solo.aim = BlockTarget(topOf(state, 5, 1, 5));

    expect(system.placeNow(state, state.solo), isEmpty);
    expect(state.world.blockAt(5, 2, 5), BlockType.dirt);
  });

  test('nothing is placed outside the world', () {
    final state = flatState(held: ItemType.planks);
    state.solo.aim = BlockTarget(
      RayHit(
        x: 5,
        y: 15,
        z: 5,
        block: BlockType.stone,
        nx: 0,
        ny: 1,
        nz: 0,
        distance: 2,
      ),
    );
    expect(system.placeNow(state, state.solo), isEmpty);
  });

  test('aiming at a mob places no blocks', () {
    final state = flatState(held: ItemType.planks);
    final mob = Mob(
      kind: MobKind.zombie,
      world: state.world,
      spawn: Vector3(5.5, 2, 5.5),
    );
    state.solo.aim = MobTarget(mob, 3);
    expect(system.placeNow(state, state.solo), isEmpty);
  });

  test('a held button places at intervals, not every frame', () {
    final state = flatState(held: ItemType.planks);
    state.solo.aim = BlockTarget(topOf(state, 5, 1, 5));

    system.update(state, state.solo, 1 / 60, active: true);
    expect(state.solo.inventory.countOf(ItemType.planks), 9);

    // Kolejna klatka: cooldown jeszcze trwa.
    state.solo.aim = BlockTarget(topOf(state, 6, 1, 6));
    system.update(state, state.solo, 1 / 60, active: true);
    expect(state.solo.inventory.countOf(ItemType.planks), 9);

    // Once the cooldown passes it is allowed again.
    system.update(state, state.solo, PlacementSystem.cooldown, active: true);
    expect(state.solo.inventory.countOf(ItemType.planks), 8);
  });

  test('a released button places nothing', () {
    final state = flatState(held: ItemType.planks);
    state.solo.aim = BlockTarget(topOf(state, 5, 1, 5));
    system.update(state, state.solo, 1, active: false);
    expect(state.world.blockAt(5, 2, 5), BlockType.air);
  });
}
