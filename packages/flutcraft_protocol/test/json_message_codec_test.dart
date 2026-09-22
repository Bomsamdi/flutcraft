import 'dart:convert';
import 'dart:typed_data';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_protocol/flutcraft_protocol.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

const codec = JsonMessageCodec();

ClientMessage roundTripClient(ClientMessage message) =>
    codec.decodeClient(codec.encodeClient(message));

ServerMessage roundTripServer(ServerMessage message) =>
    codec.decodeServer(codec.encodeServer(message));

/// A message written by hand, as a future version of the other end might.
Uint8List handWritten(Map<String, Object?> body) =>
    utf8.encode(json.encode({'v': JsonMessageCodec.protocolVersion, ...body}));

void main() {
  group('Client messages survive the trip', () {
    test('a sign-in carries the name and the secret', () {
      final message =
          roundTripClient(const SignIn('alice', 'open sesame')) as SignIn;

      expect(message.name, 'alice');
      expect(message.secret, 'open sesame');
    });

    test('a sign-up is not mistaken for a sign-in', () {
      // The two carry the same two strings and mean different things: one
      // claims a name, the other proves it. A codec that folded them into a
      // flag would let a typo register a new account.
      final message = roundTripClient(const SignUp('alice', 'open sesame'));

      expect(message, isA<SignUp>());
    });

    test('input keeps its axes, its held keys and its edges', () {
      const sent = InputTick(
        42,
        InputFrame(
          forward: 1,
          strafe: -0.5,
          lookYaw: 0.25,
          lookPitch: -0.125,
          held: {GameAction.moveForward, GameAction.primary},
          pressed: [GameAction.toggleInventory],
        ),
      );

      final got = roundTripClient(sent) as InputTick;

      expect(got.tick, 42);
      expect(got.input.forward, 1);
      expect(got.input.strafe, -0.5);
      expect(got.input.lookYaw, closeTo(0.25, 1e-9));
      expect(got.input.held, sent.input.held);
      expect(got.input.pressed, sent.input.pressed);
    });

    test('every command variant survives', () {
      const commands = <GameCommand>[
        SelectHotbarSlot(3),
        CycleHotbarSlot(-1),
        ClickSlot(InventorySlotRef(7)),
        ClickSlot(GridSlotRef(2), kind: ClickKind.split),
        ClickSlot(FurnaceSlotRef(FurnaceSlot.fuel)),
        ClickSlot(CraftResultRef()),
        OpenRoute(UiRoute.craftingTable),
        CloseRoute(),
        OpenRecipes(),
        ToggleFlight(),
        Respawn(),
        UseOrPlace(),
        SaveGame(),
      ];

      for (final command in commands) {
        final got = roundTripClient(Command(command)) as Command;
        expect(
          got.command.runtimeType,
          command.runtimeType,
          reason: '$command changed shape',
        );
      }
    });

    test('a click keeps which slot and which button', () {
      final got =
          roundTripClient(
                const Command(ClickSlot(GridSlotRef(5), kind: ClickKind.split)),
              )
              as Command;
      final click = got.command as ClickSlot;

      expect((click.ref as GridSlotRef).index, 5);
      expect(click.kind, ClickKind.split);
    });
  });

  group('Server messages survive the trip', () {
    test('welcome carries a whole world as a seed and its edits', () {
      final got =
          roundTripServer(
                Welcome(
                  you: const PlayerId('bob'),
                  tick: 900,
                  world: WorldState(
                    seed: 1337,
                    edits: {
                      const BlockPos(10, 20, 30): BlockType.planks,
                      const BlockPos(11, 20, 30): BlockType.air,
                    },
                  ),
                ),
              )
              as Welcome;

      expect(got.you, const PlayerId('bob'));
      expect(got.tick, 900);
      expect(got.world.seed, 1337);
      expect(got.world.edits[const BlockPos(10, 20, 30)], BlockType.planks);
      expect(got.world.edits[const BlockPos(11, 20, 30)], BlockType.air);
    });

    test('a world delta keeps its tick, which is what settles a guess', () {
      final got =
          roundTripServer(
                const WorldDelta(120, [
                  BlockChange(BlockPos(1, 2, 3), BlockType.stone),
                ]),
              )
              as WorldDelta;

      expect(got.tick, 120);
      expect(got.changes.single.pos, const BlockPos(1, 2, 3));
      expect(got.changes.single.block, BlockType.stone);
    });

    test('an entity delta keeps mobs, arrows and the departed', () {
      final got =
          roundTripServer(
                EntityDelta(
                  tick: 7,
                  mobs: [
                    MobState(
                      id: const EntityId(3),
                      kind: MobKind.creeper,
                      position: Vector3(1.5, 2.25, 3),
                      yaw: 0.5,
                      health: 12,
                      walkSpeed: 2,
                      fuse: 0.75,
                    ),
                  ],
                  arrows: [
                    ArrowState(
                      id: const EntityId(4),
                      position: Vector3(5, 6, 7),
                      yaw: 1,
                      pitch: -0.25,
                    ),
                  ],
                  gone: const [EntityId(1), EntityId(2)],
                ),
              )
              as EntityDelta;

      expect(got.mobs.single.id, const EntityId(3));
      expect(got.mobs.single.kind, MobKind.creeper);
      expect(got.mobs.single.fuse, closeTo(0.75, 1e-9));
      expect(got.arrows.single.id, const EntityId(4));
      expect(got.gone, const [EntityId(1), EntityId(2)]);
    });

    test('a correction keeps the tick it acknowledges', () {
      final got =
          roundTripServer(
                SelfState(
                  ackTick: 555,
                  position: Vector3(10, 20, 30),
                  velocity: Vector3(0, -9.5, 0),
                  yaw: 1.25,
                  pitch: -0.5,
                  onGround: true,
                  flying: false,
                  health: 17,
                ),
              )
              as SelfState;

      expect(got.ackTick, 555);
      expect(got.position.y, 20);
      expect(got.velocity.y, closeTo(-9.5, 1e-9));
      expect(got.onGround, isTrue);
      expect(got.health, 17);
    });

    test('an inventory keeps its revision, its slots and the cursor', () {
      final got =
          roundTripServer(
                const InventoryState(
                  revision: 9,
                  slots: [ItemStack(ItemType.coal, 5), null],
                  selectedSlot: 1,
                  cursor: ItemStack(ItemType.ironIngot, 2),
                ),
              )
              as InventoryState;

      expect(got.revision, 9);
      expect(got.slots.first, const ItemStack(ItemType.coal, 5));
      expect(got.slots[1], isNull);
      expect(got.cursor, const ItemStack(ItemType.ironIngot, 2));
    });

    test('every event variant survives', () {
      const events = <GameEvent>[
        BlockBroken(BlockPos(1, 2, 3), BlockType.log, [
          ItemStack(ItemType.log, 1),
        ]),
        ToolTooWeak(BlockType.ironOre),
        InventoryFull(ItemType.cobblestone),
        PlacementRejected(PlacementRejection.insideMob),
        MobKilled(MobKind.spider, [ItemStack(ItemType.string, 2)]),
        CreeperExploded(),
        FlightToggled(true),
        PlayerRespawned(),
        GameSaved(),
      ];

      for (final event in events) {
        final got = roundTripServer(Notice(event)) as Notice;
        expect(
          got.event.runtimeType,
          event.runtimeType,
          reason: '$event changed shape',
        );
      }
    });

    test('a kick carries a code, not a sentence', () {
      final got = roundTripServer(const Kick(KickReason.tooSlow)) as Kick;

      // The server never knew which language anybody reads.
      expect(got.reason, KickReason.tooSlow);
    });

    test('a blast travels as a point and a radius, not as a crater', () {
      final got =
          roundTripServer(ExplosionAt(Vector3(8, 4, 8), 3.4)) as ExplosionAt;

      expect(got.radius, closeTo(3.4, 1e-9));
      expect(codec.encodeServer(got).length, lessThan(100));
    });
  });

  group('A reader that tolerates a stranger', () {
    test('an action this build never heard of is dropped', () {
      final message =
          codec.decodeClient(
                handWritten({
                  't': 'input',
                  'tick': 1,
                  'in': {
                    'held': ['moveForward', 'somersault'],
                    'pressed': <String>[],
                  },
                }),
              )
              as InputTick;

      expect(message.input.held, {GameAction.moveForward});
    });

    test('a block this build never heard of costs only its own edit', () {
      final message =
          codec.decodeServer(
                handWritten({
                  't': 'world',
                  'tick': 1,
                  'changes': [
                    {
                      'p': [1, 2, 3],
                      'b': 'mithril',
                    },
                    {
                      'p': [4, 5, 6],
                      'b': 'stone',
                    },
                  ],
                }),
              )
              as WorldDelta;

      expect(message.changes, hasLength(1));
      expect(message.changes.single.block, BlockType.stone);
    });

    test('a species this build cannot draw is dropped, not guessed at', () {
      final message =
          codec.decodeServer(
                handWritten({
                  't': 'entities',
                  'tick': 1,
                  'mobs': [
                    {'id': 1, 'kind': 'dragon'},
                    {'id': 2, 'kind': 'zombie'},
                  ],
                }),
              )
              as EntityDelta;

      expect(message.mobs.single.kind, MobKind.zombie);
    });

    test('a whole message this build does not know is refused', () {
      // Half a message cannot be applied, so unlike an unknown member it is
      // not something to shrug off.
      expect(
        () => codec.decodeServer(handWritten({'t': 'teleport'})),
        throwsA(isA<UnknownMessage>()),
      );
    });

    test('a different protocol version is refused with a clear error', () {
      final bytes = utf8.encode(
        json.encode({'v': JsonMessageCodec.protocolVersion + 1, 't': 'ping'}),
      );

      expect(() => codec.decodeServer(bytes), throwsA(isA<ProtocolMismatch>()));
    });
  });

  group('The traps JSON sets', () {
    test('a whole number read back as a double does not throw', () {
      // jsonEncode writes 0.0 as 0, which decodes as an int; `as double`
      // would throw on exactly the values that happen to be round.
      final got =
          roundTripServer(
                SelfState(
                  ackTick: 1,
                  position: Vector3.zero(),
                  velocity: Vector3.zero(),
                  yaw: 0,
                  pitch: 0,
                  onGround: false,
                  flying: false,
                  health: 20,
                ),
              )
              as SelfState;

      expect(got.position.x, 0);
      expect(got.yaw, 0);
    });

    test('float32 noise is rounded away instead of being transmitted', () {
      final noisy = Vector3(20.5, 0, 0)..x = 20.500000953674316;
      final encoded = utf8.decode(codec.encodeServer(ExplosionAt(noisy, 1)));

      expect(encoded, contains('20.5'));
      expect(encoded, isNot(contains('20.500000953674316')));
    });
  });
}
