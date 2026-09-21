import 'dart:math';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

const alice = PlayerId('alice');
const bob = PlayerId('bob');

/// A session over a world that already exists, standing in for the networked
/// one the client will get later. It is three members; that is the point.
class FakeSession implements SimulatedSession {
  FakeSession(this.state, this.viewerId);

  @override
  final GameState state;

  @override
  final PlayerId viewerId;

  int ticks = 0;

  @override
  void tick(double dt, InputFrame input) => ticks++;
}

GameState worldWithBoth() {
  final world = VoxelWorld(sizeX: 32, sizeY: 16, sizeZ: 32);
  for (var z = 0; z < 32; z++) {
    for (var x = 0; x < 32; x++) {
      world.setRaw(x, 0, z, BlockType.stone);
    }
  }
  Participant at(PlayerId id, double x) => Participant(
    id: id,
    player: Player(world: world, spawn: Vector3(x, 1, 16)),
  );
  return GameState(world: world, players: [at(alice, 8), at(bob, 24)]);
}

void main() {
  group('A renderer draws one point of view out of several', () {
    test('the viewer is the player this client is playing', () {
      final session = FakeSession(worldWithBoth(), bob);

      expect(session.viewer.id, bob);
      expect(session.viewer.player.position.x, 24);
    });

    test('a world with company no longer breaks the renderer', () {
      final state = worldWithBoth();

      // `state.solo` is `participants.values.single` — what the engine used
      // to call. This is the line that used to throw.
      expect(() => state.solo, throwsStateError);
      expect(() => FakeSession(state, alice).viewer, returnsNormally);
    });

    test('a single-player session names its only player as the viewer', () {
      final world = VoxelWorld(sizeX: 16, sizeY: 8, sizeZ: 16);
      final session = LoopGameSession(
        GameLoop(
          state: GameState.solo(
            world: world,
            player: Player(world: world, spawn: Vector3(8, 1, 8)),
            inventory: Inventory(),
          ),
          spawner: MobSpawner(world: world, seed: 1, maxMobs: 0),
          random: Random(1),
        ),
      );

      expect(session.viewerId, GameState.soloId);
      expect(session.viewer, same(session.state.solo));
    });

    test('looking through somebody who is not there fails loudly', () {
      final session = FakeSession(worldWithBoth(), const PlayerId('nobody'));

      // Better than drawing an arbitrary player's game and looking fine.
      expect(() => session.viewer, throwsA(isA<TypeError>()));
    });
  });
}
