import 'dart:math';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

VoxelWorld flatWorld({int size = 64}) {
  final world = VoxelWorld(sizeX: size, sizeY: 24, sizeZ: size);
  for (var z = 0; z < size; z++) {
    for (var x = 0; x < size; x++) {
      world.setRaw(x, 0, z, BlockType.bedrock);
      world.setRaw(x, 1, z, BlockType.stone);
    }
  }
  return world;
}

LoopGameSession sessionAt(VoxelWorld world, {Vector3? spawn}) =>
    LoopGameSession(
      GameLoop(
        state: GameState.solo(
          world: world,
          player: Player(world: world, spawn: spawn ?? Vector3(32.5, 2, 32.5)),
          inventory: Inventory(),
        ),
        spawner: MobSpawner(world: world, seed: 1, maxMobs: 0),
        random: Random(1),
      ),
    );

/// One second of walking forward, delivered in [frames] rendered frames.
Vector3 walkForASecond(int frames, {VoxelWorld? into, Vector3? spawn}) {
  final world = into ?? flatWorld();
  final session = sessionAt(world, spawn: spawn);
  const input = InputFrame(forward: 1, held: {GameAction.moveForward});

  for (var i = 0; i < frames; i++) {
    session.tick(1 / frames, input);
  }
  return session.loop.state.solo.player.position.clone();
}

void main() {
  group('The outcome no longer depends on the frame rate', () {
    test('one second of walking ends in the same place at any frame rate', () {
      final at60 = walkForASecond(60);
      final at30 = walkForASecond(30);
      final at6 = walkForASecond(6);

      // Before the fixed step this failed: VoxelBody splits a move into
      // sub-steps and the count came from dt, so the same input travelled a
      // different distance on a faster machine.
      expect(at30.distanceTo(at60), lessThan(1e-6));
      expect(at6.distanceTo(at60), lessThan(1e-6));
    });

    test('walking into a wall stops in the same place at any frame rate', () {
      Vector3 intoWall(int frames) {
        final world = flatWorld();
        for (var y = 2; y < 5; y++) {
          for (var x = 28; x < 38; x++) {
            world.setBlock(x, y, 30, BlockType.stone);
          }
        }
        return walkForASecond(
          frames,
          into: world,
          spawn: Vector3(32.5, 2, 33.5),
        );
      }

      // The snap to a block edge is a step function: a difference of one
      // sub-step used to become a difference of a whole block at a wall.
      expect(intoWall(30).distanceTo(intoWall(60)), lessThan(1e-6));
      expect(intoWall(6).distanceTo(intoWall(60)), lessThan(1e-6));
    });

    test('gravity settles at the same height at any frame rate', () {
      double fall(int frames) {
        final world = flatWorld();
        final session = sessionAt(world, spawn: Vector3(32.5, 12, 32.5));
        for (var i = 0; i < frames * 2; i++) {
          session.tick(2 / (frames * 2), InputFrame.idle);
        }
        return session.loop.state.solo.player.position.y;
      }

      expect(fall(60), closeTo(fall(30), 1e-6));
      expect(fall(60), closeTo(fall(6), 1e-6));
    });
  });

  group('TickClock', () {
    test('a frame shorter than a step runs nothing, and is not lost', () {
      final clock = TickClock();

      expect(clock.stepsFor(kStep / 2), 0);
      expect(clock.stepsFor(kStep / 2), 1, reason: 'the halves add up');
    });

    test('a long frame runs several steps', () {
      expect(TickClock().stepsFor(kStep * 3), 3);
    });

    test('the remainder carries over instead of being rounded away', () {
      final clock = TickClock();
      // Ten frames of 1/100 s is 0.1 s, which is six steps of 1/60 s with a
      // remainder; over a second the remainders must add up to whole steps.
      var steps = 0;
      for (var i = 0; i < 100; i++) {
        steps += clock.stepsFor(1 / 100);
      }

      expect(steps, kTicksPerSecond);
    });

    test('elapsed counts every step run', () {
      final clock = TickClock();
      clock
        ..stepsFor(kStep * 2)
        ..stepsFor(kStep);

      expect(clock.elapsed, 3);
    });

    test('a woken phone does not simulate the time it slept', () {
      final clock = TickClock();

      // Eight seconds in a pocket is 480 steps. Running them would freeze the
      // game while it caught up on nothing.
      expect(clock.stepsFor(8), kMaxCatchUp);
      expect(clock.skipped, isTrue);
      expect(
        clock.stepsFor(kStep),
        1,
        reason: 'the dropped time does not come back later',
      );
      expect(clock.skipped, isFalse);
    });

    test('zero and negative frame times are ignored', () {
      final clock = TickClock();

      expect(clock.stepsFor(0), 0);
      expect(clock.stepsFor(-1), 0);
      expect(
        clock.stepsFor(kStep),
        1,
        reason: 'the clock did not go backwards',
      );
    });
  });

  group('A frame worth several steps is not applied several times', () {
    test('one tap of a key is one command, however long the frame', () {
      final world = flatWorld();
      final session = sessionAt(world);
      const tap = InputFrame(pressed: [GameAction.toggleInventory]);

      // A frame worth three steps: the naive loop would open, close and
      // reopen the inventory.
      session.tick(kStep * 3, tap);

      expect(session.loop.state.solo.route, UiRoute.inventory);
    });

    test('a look delta is shared out, not repeated per step', () {
      double yawAfter(int steps) {
        final session = sessionAt(flatWorld());
        session.tick(kStep * steps, const InputFrame(lookYaw: 0.6));
        return session.loop.state.solo.player.yaw;
      }

      // Turning the same amount with the mouse must turn the same amount,
      // whether the frame was worth one step or four.
      expect(yawAfter(4), closeTo(yawAfter(1), 1e-6));
    });

    test('a held key applies in every step of the frame', () {
      final oneLongFrame = sessionAt(flatWorld());
      final threeShortOnes = sessionAt(flatWorld());
      const walking = InputFrame(forward: 1, held: {GameAction.moveForward});

      oneLongFrame.tick(kStep * 3, walking);
      for (var i = 0; i < 3; i++) {
        threeShortOnes.tick(kStep, walking);
      }

      expect(
        oneLongFrame.loop.state.solo.player.position.distanceTo(
          threeShortOnes.loop.state.solo.player.position,
        ),
        lessThan(1e-6),
      );
    });
  });
}
