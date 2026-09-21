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
  return GameState(
    world: world,
    player: Player(world: world, spawn: Vector3(8.5, 2, 8.5)),
    inventory: inventory,
  );
}

/// Trafienie w górną ścianę bloku (x, y, z) — blok stanie nad nim.
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

  test('blok ląduje po stronie trafionej ściany', () {
    final state = flatState(held: ItemType.planks);
    state.aim = BlockTarget(topOf(state, 5, 1, 5));

    final events = system.placeNow(state);

    expect(events, isEmpty);
    expect(state.world.blockAt(5, 2, 5), BlockType.planks);
    expect(state.inventory.countOf(ItemType.planks), 9);
  });

  test('narzędzie w ręce nie jest blokiem', () {
    final state = flatState(held: ItemType.ironPickaxe);
    state.aim = BlockTarget(topOf(state, 5, 1, 5));

    final events = system.placeNow(state);

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

  test('pusty slot też odmawia', () {
    final state = flatState();
    state.aim = BlockTarget(topOf(state, 5, 1, 5));
    expect(system.placeNow(state).single, isA<PlacementRejected>());
  });

  test('nie da się postawić bloku w sobie', () {
    final state = flatState(held: ItemType.planks);
    // Gracz stoi na (8, 2, 8); celujemy w blok pod nim.
    state.aim = BlockTarget(topOf(state, 8, 1, 8));

    final events = system.placeNow(state);

    expect(
      events.single,
      isA<PlacementRejected>().having(
        (e) => e.reason,
        'reason',
        PlacementRejection.insidePlayer,
      ),
    );
  });

  test('nie da się postawić bloku w potworze', () {
    final state = flatState(held: ItemType.planks);
    state.mobs.add(
      Mob(
        kind: MobKind.zombie,
        world: state.world,
        spawn: Vector3(5.5, 2, 5.5),
      ),
    );
    state.aim = BlockTarget(topOf(state, 5, 1, 5));

    expect(
      system.placeNow(state).single,
      isA<PlacementRejected>().having(
        (e) => e.reason,
        'reason',
        PlacementRejection.insideMob,
      ),
    );
  });

  test('zajęte miejsce po prostu nic nie robi', () {
    final state = flatState(held: ItemType.planks);
    state.world.setBlock(5, 2, 5, BlockType.dirt);
    state.aim = BlockTarget(topOf(state, 5, 1, 5));

    expect(system.placeNow(state), isEmpty);
    expect(state.world.blockAt(5, 2, 5), BlockType.dirt);
  });

  test('poza granicami świata nic nie stawiamy', () {
    final state = flatState(held: ItemType.planks);
    state.aim = BlockTarget(
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
    expect(system.placeNow(state), isEmpty);
  });

  test('celowanie w potwora nie stawia bloków', () {
    final state = flatState(held: ItemType.planks);
    final mob = Mob(
      kind: MobKind.zombie,
      world: state.world,
      spawn: Vector3(5.5, 2, 5.5),
    );
    state.aim = MobTarget(mob, 3);
    expect(system.placeNow(state), isEmpty);
  });

  test('trzymany przycisk stawia w odstępach, nie co klatkę', () {
    final state = flatState(held: ItemType.planks);
    state.aim = BlockTarget(topOf(state, 5, 1, 5));

    system.update(state, 1 / 60, active: true);
    expect(state.inventory.countOf(ItemType.planks), 9);

    // Kolejna klatka: cooldown jeszcze trwa.
    state.aim = BlockTarget(topOf(state, 6, 1, 6));
    system.update(state, 1 / 60, active: true);
    expect(state.inventory.countOf(ItemType.planks), 9);

    // Po upływie cooldownu znowu wolno.
    system.update(state, PlacementSystem.cooldown, active: true);
    expect(state.inventory.countOf(ItemType.planks), 8);
  });

  test('puszczony przycisk nic nie stawia', () {
    final state = flatState(held: ItemType.planks);
    state.aim = BlockTarget(topOf(state, 5, 1, 5));
    system.update(state, 1, active: false);
    expect(state.world.blockAt(5, 2, 5), BlockType.air);
  });
}
