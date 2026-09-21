import 'package:flame/components.dart' show Component;
import 'package:flame_3d/camera.dart';

/// Keeps a set of components in step with a list of simulated entities.
///
/// Adds a component when an entity appears, drops it when the entity is gone
/// and syncs the rest once a frame. One generic instead of a pair of
/// hand-written maps per entity type — adding arrows to the game used to mean
/// copying forty lines and getting the removal branch subtly wrong.
///
/// Deliberately not a [Component]: Flame would update it before the
/// simulation has ticked, so it would always be one frame behind.
class EntitySync<E extends Object, C extends Component> {
  EntitySync({
    required this.world,
    required this.source,
    required this.build,
    required this.sync,
  });

  /// The scene graph the components live in.
  final World3D world;

  /// The entities that should exist right now.
  final Iterable<E> Function() source;

  /// Builds the component for a newly seen entity.
  final C Function(E entity) build;

  /// Copies the entity's state onto its component.
  final void Function(C component, E entity) sync;

  final Map<E, C> _components = {};

  /// How many components are currently alive. Useful in tests.
  int get length => _components.length;

  void refresh() {
    final alive = source().toSet();

    for (final entity in alive) {
      final component = _components.putIfAbsent(entity, () {
        final created = build(entity);
        world.add(created);
        return created;
      });
      sync(component, entity);
    }

    _components.keys
        .where((entity) => !alive.contains(entity))
        .toList()
        .forEach((entity) => _components.remove(entity)?.removeFromParent());
  }
}
