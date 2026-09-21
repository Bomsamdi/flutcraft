import 'package:flame/components.dart';
import 'package:flame_3d/camera.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_engine/flutcraft_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for a mob or an arrow: something the simulation owns.
class _Entity {
  _Entity(this.name);

  final String name;
  int synced = 0;
}

/// Stands in for its rendered counterpart. A plain [Component], so the test
/// needs no GPU — which is the point of testing the sync separately from
/// what it synchronises.
class _Marker extends Component {
  _Marker(this.entity);

  final _Entity entity;
}

/// A real mob, mutated the way a network mirror will mutate one.
void _mirroringRealMobs() {
  test('a mob whose state changes keeps the same component', () {
    final world = VoxelWorld(sizeX: 16, sizeY: 8, sizeZ: 16);
    final mobs = <Mob>[
      Mob(kind: MobKind.zombie, world: world, spawn: Vector3(8, 1, 8)),
    ];
    final scene = World3D();
    var built = 0;

    final sync = EntitySync<Mob, Component>(
      world: scene,
      source: () => mobs,
      build: (_) {
        built++;
        return Component();
      },
      sync: (_, _) {},
    );

    for (var frame = 0; frame < 100; frame++) {
      // What a client applying packets does: write into the object it has.
      mobs.first.position.x += 0.01;
      mobs.first.health -= 0.05;
      sync.refresh();
    }

    // Rebuilding a Mob per packet instead would add and remove every
    // component twenty times a second, and the mobs would flicker.
    expect(built, 1);
    expect(sync.length, 1);
  });

  test('replacing the object does churn the components', () {
    final world = VoxelWorld(sizeX: 16, sizeY: 8, sizeZ: 16);
    final mobs = <Mob>[
      Mob(kind: MobKind.zombie, world: world, spawn: Vector3(8, 1, 8)),
    ];
    final scene = World3D();
    var built = 0;

    final sync = EntitySync<Mob, Component>(
      world: scene,
      source: () => mobs,
      build: (_) {
        built++;
        return Component();
      },
      sync: (_, _) {},
    );

    for (var frame = 0; frame < 10; frame++) {
      mobs[0] = Mob(
        kind: MobKind.zombie,
        world: world,
        spawn: Vector3(8, 1, 8),
      );
      sync.refresh();
    }

    // This is the failure mode the mirror has to avoid, pinned so that the
    // cost of getting it wrong is visible rather than theoretical.
    expect(built, 10);
  });
}

void main() {
  _mirroringRealMobs();

  late World3D world;
  late List<_Entity> entities;
  late EntitySync<_Entity, _Marker> sync;

  setUp(() {
    world = World3D();
    entities = [];
    sync = EntitySync(
      world: world,
      source: () => entities,
      build: _Marker.new,
      sync: (_, entity) => entity.synced++,
    );
  });

  test('a new entity gets a component', () {
    entities.add(_Entity('zombie'));

    sync.refresh();

    expect(sync.length, 1);
  });

  test('an entity that is gone loses its component', () {
    final zombie = _Entity('zombie');
    entities.add(zombie);
    sync.refresh();

    entities.remove(zombie);
    sync.refresh();

    expect(sync.length, 0);
  });

  test('a surviving entity keeps the same component', () {
    final zombie = _Entity('zombie');
    entities.add(zombie);
    sync.refresh();

    entities.add(_Entity('spider'));
    sync.refresh();

    expect(sync.length, 2);
    expect(zombie.synced, 2, reason: 'synced on both passes, not rebuilt');
  });

  test('every surviving entity is synced once per refresh', () {
    final mobs = [_Entity('a'), _Entity('b'), _Entity('c')];
    entities.addAll(mobs);

    sync
      ..refresh()
      ..refresh();

    expect(mobs.map((mob) => mob.synced), everyElement(2));
  });

  test('appearing and disappearing in the same frame is not an error', () {
    entities.add(_Entity('mayfly'));
    sync.refresh();
    entities.clear();
    entities.add(_Entity('another'));

    expect(sync.refresh, returnsNormally);
    expect(sync.length, 1);
  });

  test('nothing to sync is not a special case', () {
    expect(sync.refresh, returnsNormally);
    expect(sync.length, 0);
  });
}
