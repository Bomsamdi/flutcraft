import 'dart:math';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

LoopGameSession newSession({int size = 32}) {
  final world = VoxelWorld(sizeX: size, sizeY: 16, sizeZ: size);
  for (var z = 0; z < size; z++) {
    for (var x = 0; x < size; x++) {
      world.setRaw(x, 0, z, BlockType.bedrock);
      world.setRaw(x, 1, z, BlockType.stone);
    }
  }
  final state = GameState(
    world: world,
    player: Player(world: world, spawn: Vector3(16.5, 2, 16.5)),
    inventory: Inventory(),
  );
  return LoopGameSession(
    GameLoop(
      state: state,
      spawner: MobSpawner(world: world, seed: 1, maxMobs: 0),
      random: Random(1),
    ),
  );
}

void main() {
  group('GameSnapshot really is a snapshot', () {
    test('a snapshot kept aside does not change as the game ticks', () {
      final session = newSession();
      session.loop.state.inventory.add(ItemType.planks, 5);
      session.dispatch(const SelectHotbarSlot(0));

      final before = session.snapshot;
      session.loop.state.inventory.add(ItemType.planks, 10);
      session.dispatch(const SelectHotbarSlot(1));

      expect(
        before.hotbar.first?.count,
        5,
        reason: 'the old snapshot holds its own state',
      );
      expect(before.selectedSlot, 0);
      expect(session.snapshot.hotbar.first?.count, 15);
      expect(session.snapshot.selectedSlot, 1);
    });

    test('the hotbar list cannot be modified', () {
      final session = newSession();
      expect(() => session.snapshot.hotbar.add(null), throwsUnsupportedError);
    });

    test('aiming turns into a view the UI can render', () {
      final session = newSession();
      expect(session.snapshot.aim, isA<NoAimView>());

      session.loop.state.player
        ..yaw = 0
        ..pitch = -1.4;
      session.tick(1 / 60, InputFrame.idle);
      session.dispatch(const SelectHotbarSlot(0));

      expect(session.snapshot.aim, isA<BlockAimView>());
    });

    test('the snapshot carries health and position', () {
      final session = newSession();
      session.loop.state.player.damage(6);
      session.dispatch(const SelectHotbarSlot(0));

      expect(session.snapshot.health, Player.maxHealth - 6);
      expect(session.snapshot.position, const BlockPos(16, 2, 16));
    });
  });

  group('Throttling', () {
    test('ticking does not publish faster than the chosen rate', () async {
      final session = newSession();
      final received = <GameSnapshot>[];
      final sub = session.snapshots.listen(received.add);

      // One second at 60 fps; at 20 Hz that should be about 20 snapshots.
      for (var i = 0; i < 60; i++) {
        session.tick(1 / 60, InputFrame.idle);
      }
      await Future<void>.delayed(Duration.zero);

      expect(received.length, inInclusiveRange(18, 22));
      await sub.cancel();
    });

    test('a command publishes a snapshot at once', () async {
      final session = newSession();
      final received = <GameSnapshot>[];
      final sub = session.snapshots.listen(received.add);

      session.dispatch(const ToggleFlight());
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.single.flying, isTrue);
      await sub.cancel();
    });
  });

  group('The event stream', () {
    test('commands reach the stream', () async {
      final session = newSession();
      final events = <GameEvent>[];
      final sub = session.events.listen(events.add);

      session.dispatch(const ToggleFlight());
      await Future<void>.delayed(Duration.zero);

      expect(events.single, isA<FlightToggled>());
      await sub.cancel();
    });

    test('so do events from the simulation', () async {
      final session = newSession();
      final events = <GameEvent>[];
      final sub = session.events.listen(events.add);

      session.loop.state.mobs.add(
        Mob(
          kind: MobKind.spider,
          world: session.loop.state.world,
          spawn: Vector3(16.5, 2, 14.5),
        )..health = 0,
      );
      session.tick(1 / 60, InputFrame.idle);
      await Future<void>.delayed(Duration.zero);

      expect(events.whereType<MobKilled>(), hasLength(1));
      await sub.cancel();
    });
  });
}
