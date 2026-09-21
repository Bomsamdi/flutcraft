import 'package:flame/components.dart';
import 'package:flame_3d/camera.dart';
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

void main() {
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
