import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_protocol/flutcraft_protocol.dart';
import 'package:flutcraft_server/flutcraft_server.dart';
import 'package:test/test.dart';

const alice = PlayerId('alice');
const bob = PlayerId('bob');

const walkForward = InputFrame(forward: 1, held: {GameAction.moveForward});

void main() {
  late GameHost host;
  late RecordingLink toAlice;
  late RecordingLink toBob;

  setUp(() {
    host = GameHost.newWorld(seed: 7);
    toAlice = RecordingLink();
    toBob = RecordingLink();
  });

  void play(int ticks) {
    for (var i = 0; i < ticks; i++) {
      host.step();
    }
  }

  group('Joining', () {
    test('a new player is welcomed with the world', () {
      host.join(alice, toAlice);

      final welcome = toAlice.last<Welcome>()!;
      expect(welcome.you, alice);
      expect(welcome.world.seed, 7);
    });

    test('the world travels as a seed, not as a block array', () {
      host
        ..state.world.setBlock(64, 30, 64, BlockType.planks)
        ..join(alice, toAlice);

      final welcome = toAlice.last<Welcome>()!;
      const codec = JsonMessageCodec();

      // The full array is 786,432 bytes.
      expect(codec.encodeServer(welcome).length, lessThan(2000));
      expect(welcome.world.edits, contains(const BlockPos(64, 30, 64)));
    });

    test('a player is told what they are carrying, once, on arrival', () {
      host.join(alice, toAlice);

      expect(toAlice.all<InventoryState>(), hasLength(1));
    });

    test('an empty world is valid, and the caretaker steps aside', () {
      expect(host.state.participants.keys, [GameHost.caretaker]);

      host.join(alice, toAlice);

      expect(host.state.participants.keys, [alice]);
    });

    test('reconnecting replaces the old connection rather than doubling', () {
      host.join(alice, toAlice);
      final second = RecordingLink();

      host.join(alice, second);

      expect(toAlice.closed, isTrue);
      expect(host.players, [alice]);
      expect(host.state.participants, hasLength(1));
    });
  });

  group('Two players in one world', () {
    setUp(() {
      host
        ..join(alice, toAlice)
        ..join(bob, toBob);
    });

    test('each sees the other move', () {
      final start = host.state.participants[alice]!.player.position.clone();

      // A real client sends a frame per tick.
      for (var i = 0; i < kTicksPerSecond; i++) {
        host
          ..receive(alice, InputTick(i, walkForward))
          ..step();
      }

      final asBobSees = toBob.last<PlayerStates>()!.players.firstWhere(
        (p) => p.id == alice,
      );
      expect(
        asBobSees.position.distanceTo(start),
        greaterThan(0.5),
        reason: 'Bob watched Alice walk',
      );
    });

    test('a correction says which input it has applied', () {
      host.receive(alice, const InputTick(42, walkForward));

      play(kTicksPerSecond);

      expect(toAlice.last<SelfState>()!.ackTick, 42);
    });

    test('one lost packet does not freeze a player', () {
      // A gap between two frames is what a dropped packet looks like from
      // the server's side.
      host
        ..receive(alice, const InputTick(1, walkForward))
        ..step()
        ..step();
      final afterGap = host.state.participants[alice]!.player.position.clone();

      host.step();

      expect(
        host.state.participants[alice]!.player.position.distanceTo(afterGap),
        greaterThan(0),
        reason: 'the last input still counted through the gap',
      );
    });

    test('a client that stops talking stops walking', () {
      host.receive(alice, const InputTick(1, walkForward));
      play(GameHost.inputHoldTicks + 30);
      final settled = host.state.participants[alice]!.player.position.clone();

      play(kTicksPerSecond * 2);

      // Held for ever, a disconnected client would walk into a wall until
      // the socket timed out.
      expect(
        host.state.participants[alice]!.player.position.distanceTo(settled),
        lessThan(0.05),
      );
    });

    test('a held input repeats, but the tap inside it does not', () {
      host.receive(
        alice,
        const InputTick(1, InputFrame(pressed: [GameAction.toggleInventory])),
      );

      play(GameHost.inputHoldTicks);

      // Repeating the edge would have opened and closed the inventory five
      // times over.
      expect(host.state.participants[alice]!.route, UiRoute.inventory);
    });

    test('a block one player places reaches the other', () {
      host.state.world.setBlock(20, 5, 20, BlockType.planks);

      play(1);

      final delta = toBob.last<WorldDelta>()!;
      expect(delta.changes.single.pos, const BlockPos(20, 5, 20));
      expect(delta.changes.single.block, BlockType.planks);
    });

    test('a tick that changed nothing sends no world delta', () {
      play(30);

      expect(toBob.all<WorldDelta>(), isEmpty);
    });

    test('an inventory is sent when it changes, not on a timer', () {
      final before = toAlice.all<InventoryState>().length;
      play(60);
      expect(toAlice.all<InventoryState>(), hasLength(before));

      host.state.participants[alice]!.inventory.add(ItemType.coal, 3);
      play(1);

      expect(toAlice.all<InventoryState>(), hasLength(before + 1));
    });

    test("one player's inventory is not sent to the other", () {
      final bobsBefore = toBob.all<InventoryState>().length;

      host.state.participants[alice]!.inventory.add(ItemType.coal, 3);
      play(1);

      expect(toBob.all<InventoryState>(), hasLength(bobsBefore));
    });

    test('a notice goes to the player it is about', () {
      host.receive(alice, const Command(ToggleFlight()));

      final toldAlice = toAlice.all<Notice>().where(
        (n) => n.event is FlightToggled,
      );
      final toldBob = toBob.all<Notice>().where(
        (n) => n.event is FlightToggled,
      );

      expect(toldAlice, hasLength(1));
      expect(toldBob, isEmpty);
    });

    test('snapshots go out at 20 Hz, not at 60', () {
      final before = toAlice.all<PlayerStates>().length;

      play(kTicksPerSecond);

      expect(toAlice.all<PlayerStates>().length - before, 20);
    });
  });

  group('Leaving', () {
    test('what a player was carrying is handed back to be written down', () {
      host.join(alice, toAlice);
      host.state.participants[alice]!.inventory.add(ItemType.ironIngot, 4);

      final saved = host.leave(alice);

      expect(saved, isNotNull);
      expect(
        saved!.inventory.where((s) => s?.type == ItemType.ironIngot),
        isNotEmpty,
      );
      expect(saved.id, alice);
    });

    test('the last player out leaves a world that still exists', () {
      host
        ..join(alice, toAlice)
        ..leave(alice);

      expect(host.players, isEmpty);
      expect(host.state.participants.keys, [GameHost.caretaker]);
      expect(() => host.step(), returnsNormally);
    });

    test('input from somebody who left is ignored, not fatal', () {
      host
        ..join(alice, toAlice)
        ..leave(alice);

      expect(
        () => host.receive(alice, const InputTick(1, walkForward)),
        returnsNormally,
      );
    });
  });

  group('The world runs whether or not anyone is watching', () {
    test('an empty server still ticks', () {
      play(kTicksPerSecond);

      expect(host.tick, kTicksPerSecond);
    });

    test('one player in a menu does not stop the other', () {
      host
        ..join(alice, toAlice)
        ..join(bob, toBob)
        ..receive(alice, const Command(OpenRoute(UiRoute.inventory)))
        ..receive(bob, const InputTick(1, walkForward));
      final start = host.state.participants[bob]!.player.position.clone();

      play(30);

      expect(
        host.state.participants[bob]!.player.position.distanceTo(start),
        greaterThan(0.1),
      );
    });
  });
}
