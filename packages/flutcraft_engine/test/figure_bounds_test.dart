import 'package:flame/game.dart';
import 'package:flame_3d/components.dart';
import 'package:flutcraft_atlas/flutcraft_atlas.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_engine/flutcraft_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mounting is all these need. `FlameGame3D` wants a GPU, and what is under
/// test is arithmetic on bounding boxes.
Future<FlameGame> mounted(Component3D figure) async {
  final game = FlameGame()..add(figure);
  await game.ready();
  return game;
}

/// Where every part of a figure thinks it is.
///
/// Reading this is also what a rendered frame does: the frustum test asks
/// every part for its box, and the answer is cached. A test that never asks
/// before moving the figure never fills that cache, and so never sees the
/// stale answer the game sees.
List<double> partDepths(Component3D figure) => figure.children
    .whereType<Object3D>()
    .map((part) => part.aabb.center.z)
    .toList();

void main() {
  late MobModels models;
  late VoxelWorld world;

  setUp(() {
    models = MobModels(EngineAtlas(TextureAtlas.generate()));
    world = VoxelWorld(sizeX: 64, sizeY: 16, sizeZ: 64);
  });

  group('A figure that moves takes all of itself along', () {
    test('every part of a player, not only the ones that swing', () async {
      final her = Participant(
        id: const PlayerId('her'),
        player: Player(world: world, spawn: Vector3(8, 1, 8)),
      );
      final figure = PlayerFigure(participant: her, model: models.player);
      await mounted(figure);
      figure.sync(1 / 60);
      // A frame is drawn where the player spawned.
      expect(partDepths(figure), everyElement(closeTo(8, 1)));

      her.player.position.setValues(8, 1, 40);
      figure.sync(1 / 60);

      // The arms and the legs always did: a rotation set every frame
      // invalidates their bounds as a side effect. The head and the torso
      // stayed behind at the spawn, and were culled as if the player had
      // never left — so from half the angles in the world, another player
      // was a pair of arms and legs walking about on their own.
      expect(
        partDepths(figure),
        everyElement(closeTo(40, 1)),
        reason: 'a part left behind is a part the frustum test throws away',
      );
    });

    test('and every part of a mob', () async {
      final mob = Mob(
        kind: MobKind.zombie,
        world: world,
        spawn: Vector3(8, 1, 8),
      );
      final figure = MobComponent(
        mob: mob,
        model: models.forKind(MobKind.zombie),
      );
      await mounted(figure);
      figure.sync();
      expect(partDepths(figure), everyElement(closeTo(8, 1)));

      mob.position.setValues(8, 1, 40);
      figure.sync();

      expect(partDepths(figure), everyElement(closeTo(40, 1)));
    });

    test('and the figure as a whole, which is what culls it', () async {
      final mob = Mob(
        kind: MobKind.creeper,
        world: world,
        spawn: Vector3(8, 1, 8),
      );
      final figure = MobComponent(
        mob: mob,
        model: models.forKind(MobKind.creeper),
      );
      await mounted(figure);
      figure.sync();
      expect(figure.aabb.center.z, closeTo(8, 1));

      mob.position.setValues(8, 1, 40);
      figure.sync();

      // One part left behind stretches the whole figure's box back to where
      // it started, which is thirty-two blocks of bounding box around
      // something half a block wide.
      expect(figure.aabb.min.z, greaterThan(38));
      expect(figure.aabb.max.z, lessThan(42));
    });
  });
}
