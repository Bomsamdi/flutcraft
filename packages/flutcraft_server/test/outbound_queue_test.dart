import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_protocol/flutcraft_protocol.dart';
import 'package:flutcraft_server/flutcraft_server.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

SelfState selfAt(int tick) => SelfState(
  ackTick: tick,
  position: Vector3.zero(),
  velocity: Vector3.zero(),
  yaw: 0,
  pitch: 0,
  onGround: true,
  flying: false,
  health: 20,
);

WorldDelta changeAt(int tick) =>
    WorldDelta(tick, [BlockChange(BlockPos(tick, 1, 1), BlockType.stone)]);

void main() {
  group('Snapshots are replaced, records are kept', () {
    test('only the newest snapshot of a kind survives', () {
      final queue = OutboundQueue()
        ..add(selfAt(1))
        ..add(selfAt(2))
        ..add(selfAt(3));

      final out = queue.drain();

      // A correction from 200 ms ago helps nobody.
      expect(out, hasLength(1));
      expect((out.single as SelfState).ackTick, 3);
    });

    test('every record is kept, in order', () {
      final queue = OutboundQueue()
        ..add(changeAt(1))
        ..add(changeAt(2));

      final out = queue.drain().cast<WorldDelta>();

      // Dropping a block change leaves the client wrong about the world for
      // good, so these are a log and not a snapshot.
      expect(out.map((d) => d.tick), [1, 2]);
    });

    test('records go out before snapshots', () {
      final queue = OutboundQueue()
        ..add(selfAt(1))
        ..add(changeAt(1));

      expect(queue.drain().first, isA<WorldDelta>());
    });

    test('draining starts a new batch', () {
      final queue = OutboundQueue()..add(changeAt(1));
      queue.drain();

      expect(queue.drain(), isEmpty);
    });
  });

  group('A client that stopped reading', () {
    test('overflows once the log passes the cap', () {
      final queue = OutboundQueue(capacity: 3);

      for (var i = 0; i < 4; i++) {
        queue.add(changeAt(i));
      }

      expect(queue.overflowed, isTrue);
    });

    test('a flood of snapshots alone never overflows', () {
      final queue = OutboundQueue(capacity: 3);

      // A backgrounded phone getting twenty corrections a second must not be
      // disconnected for it: they collapse into one.
      for (var i = 0; i < 1000; i++) {
        queue.add(selfAt(i));
      }

      expect(queue.overflowed, isFalse);
      expect(queue.length, 1);
    });

    test('every message is classified, and the compiler checks that', () {
      // The switch in isSnapshot is exhaustive over a sealed hierarchy, so a
      // new message cannot be added without deciding which kind it is.
      expect(OutboundQueue.isSnapshot(selfAt(1)), isTrue);
      expect(OutboundQueue.isSnapshot(changeAt(1)), isFalse);
      expect(
        OutboundQueue.isSnapshot(const Notice(GameSaved())),
        isFalse,
        reason: 'a notice seen once is a notice, twice is a bug',
      );
    });
  });
}
