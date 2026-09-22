import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:vector_math/vector_math.dart';

import 'message_codec.dart';
import 'messages.dart';
import 'wire_values.dart';

/// Messages as JSON, following the save format's conventions.
///
/// Enums by name, never by index: an index would silently turn every pickaxe
/// into sand the day somebody reorders `ItemType`, with nothing failing to
/// compile. Numbers are read through `num` because `jsonEncode` writes `0.0`
/// as `0`, which comes back an `int` and would make a plain `as double`
/// throw on any value that happened to be whole.
class JsonMessageCodec implements MessageCodec {
  const JsonMessageCodec();

  /// Bump when the shape of a message changes.
  static const int protocolVersion = 1;

  /// Positions are rounded to this many decimals.
  ///
  /// `Vector3` is backed by 32-bit floats, so `20.500000953674316` is noise
  /// being transmitted faithfully. A millimetre is finer than anything the
  /// game can show.
  static const int _decimals = 3;

  @override
  Uint8List encodeClient(ClientMessage message) =>
      _encode(_clientToJson(message));

  @override
  Uint8List encodeServer(ServerMessage message) =>
      _encode(_serverToJson(message));

  @override
  ClientMessage decodeClient(Uint8List bytes) => clientFromJson(_decode(bytes));

  @override
  ServerMessage decodeServer(Uint8List bytes) => serverFromJson(_decode(bytes));

  // --- envelope --------------------------------------------------------

  Uint8List _encode(Map<String, Object?> body) =>
      utf8.encode(json.encode({'v': protocolVersion, ...body}));

  Map<String, Object?> _decode(Uint8List bytes) {
    final raw = json.decode(utf8.decode(bytes)) as Map<String, Object?>;
    final version = raw['v'] as int? ?? 0;
    if (version != protocolVersion) {
      throw ProtocolMismatch(version, protocolVersion);
    }
    return raw;
  }

  // --- client messages -------------------------------------------------

  Map<String, Object?> _clientToJson(ClientMessage message) =>
      switch (message) {
        SignIn(:final name, :final secret) => {
          't': 'signin',
          'name': name,
          'secret': secret,
        },
        SignUp(:final name, :final secret) => {
          't': 'signup',
          'name': name,
          'secret': secret,
        },
        InputTick(:final tick, :final input) => {
          't': 'input',
          'tick': tick,
          'in': _inputToJson(input),
        },
        Command(:final command) => {'t': 'cmd', 'cmd': _commandToJson(command)},
        Pong(:final id) => {'t': 'pong', 'id': id},
      };

  /// Reads a client message. Visible for tests that write JSON by hand.
  ClientMessage clientFromJson(Map<String, Object?> raw) {
    final type = raw['t'] as String? ?? '';
    return switch (type) {
      'signin' => SignIn(
        raw['name'] as String? ?? '',
        raw['secret'] as String? ?? '',
      ),
      'signup' => SignUp(
        raw['name'] as String? ?? '',
        raw['secret'] as String? ?? '',
      ),
      'input' => InputTick(
        raw['tick'] as int? ?? 0,
        _inputFromJson(raw['in'] as Map<String, Object?>? ?? const {}),
      ),
      'cmd' => Command(
        _commandFromJson(raw['cmd'] as Map<String, Object?>? ?? const {}),
      ),
      'pong' => Pong(raw['id'] as int? ?? 0),
      _ => throw UnknownMessage(type),
    };
  }

  // --- server messages -------------------------------------------------

  Map<String, Object?> _serverToJson(ServerMessage message) =>
      switch (message) {
        Welcome(:final you, :final tick, :final world) => {
          't': 'welcome',
          'you': you.value,
          'tick': tick,
          'seed': world.seed,
          'edits': [
            for (final entry in world.edits.entries)
              {'p': _posToJson(entry.key), 'b': entry.value.name},
          ],
        },
        WorldDelta(:final tick, :final changes) => {
          't': 'world',
          'tick': tick,
          'changes': [
            for (final change in changes)
              {'p': _posToJson(change.pos), 'b': change.block.name},
          ],
        },
        EntityDelta(:final tick, :final mobs, :final arrows, :final gone) => {
          't': 'entities',
          'tick': tick,
          'mobs': [for (final mob in mobs) _mobToJson(mob)],
          'arrows': [for (final arrow in arrows) _arrowToJson(arrow)],
          'gone': [for (final id in gone) id.value],
        },
        PlayerStates(:final tick, :final players) => {
          't': 'players',
          'tick': tick,
          'players': [for (final player in players) _playerToJson(player)],
        },
        SelfState() => {
          't': 'self',
          'ack': message.ackTick,
          'pos': _vectorToJson(message.position),
          'vel': _vectorToJson(message.velocity),
          'yaw': _round(message.yaw),
          'pitch': _round(message.pitch),
          'ground': message.onGround,
          'flying': message.flying,
          'health': message.health,
        },
        InventoryState() => {
          't': 'inventory',
          'rev': message.revision,
          'slots': [for (final stack in message.slots) _stackToJson(stack)],
          'selected': message.selectedSlot,
          'cursor': _stackToJson(message.cursor),
        },
        ExplosionAt(:final at, :final radius) => {
          't': 'boom',
          'at': _vectorToJson(at),
          'r': _round(radius),
        },
        Notice(:final event) => {'t': 'notice', 'e': _eventToJson(event)},
        Ping(:final id) => {'t': 'ping', 'id': id},
        Kick(:final reason) => {'t': 'kick', 'why': reason.name},
      };

  /// Reads a server message. Visible for tests that write JSON by hand.
  ServerMessage serverFromJson(Map<String, Object?> raw) {
    final type = raw['t'] as String? ?? '';
    return switch (type) {
      'welcome' => Welcome(
        you: PlayerId(raw['you'] as String? ?? ''),
        tick: raw['tick'] as int? ?? 0,
        world: WorldState(
          seed: raw['seed'] as int? ?? 0,
          edits: {
            for (final entry in (raw['edits'] as List? ?? const []))
              _posFromJson((entry as Map<String, Object?>)['p'] as List):
                  ?_blockNamed(entry['b'] as String?),
          },
        ),
      ),
      'world' => WorldDelta(raw['tick'] as int? ?? 0, [
        for (final entry in (raw['changes'] as List? ?? const []))
          if (_blockNamed((entry as Map<String, Object?>)['b'] as String?)
              case final block?)
            BlockChange(_posFromJson(entry['p'] as List), block),
      ]),
      'entities' => EntityDelta(
        tick: raw['tick'] as int? ?? 0,
        mobs: [
          for (final entry in (raw['mobs'] as List? ?? const []))
            ?_mobFromJson(entry as Map<String, Object?>),
        ],
        arrows: [
          for (final entry in (raw['arrows'] as List? ?? const []))
            _arrowFromJson(entry as Map<String, Object?>),
        ],
        gone: [
          for (final id in (raw['gone'] as List? ?? const []))
            EntityId(id as int),
        ],
      ),
      'players' => PlayerStates(raw['tick'] as int? ?? 0, [
        for (final entry in (raw['players'] as List? ?? const []))
          _playerFromJson(entry as Map<String, Object?>),
      ]),
      'self' => SelfState(
        ackTick: raw['ack'] as int? ?? 0,
        position: _vectorFromJson(raw['pos'] as List?),
        velocity: _vectorFromJson(raw['vel'] as List?),
        yaw: _toDouble(raw['yaw']),
        pitch: _toDouble(raw['pitch']),
        onGround: raw['ground'] as bool? ?? false,
        flying: raw['flying'] as bool? ?? false,
        health: raw['health'] as int? ?? 0,
      ),
      'inventory' => InventoryState(
        revision: raw['rev'] as int? ?? 0,
        slots: [
          for (final entry in (raw['slots'] as List? ?? const []))
            _stackFromJson(entry as Map<String, Object?>?),
        ],
        selectedSlot: raw['selected'] as int? ?? 0,
        cursor: _stackFromJson(raw['cursor'] as Map<String, Object?>?),
      ),
      'boom' => ExplosionAt(
        _vectorFromJson(raw['at'] as List?),
        _toDouble(raw['r']),
      ),
      'notice' => Notice(
        _eventFromJson(raw['e'] as Map<String, Object?>? ?? const {}),
      ),
      'ping' => Ping(raw['id'] as int? ?? 0),
      'kick' => Kick(
        _named(KickReason.values, raw['why'] as String?) ??
            KickReason.shuttingDown,
      ),
      _ => throw UnknownMessage(type),
    };
  }

  // --- pieces ----------------------------------------------------------

  /// Looks an enum member up by name, tolerating one this build never heard
  /// of: a newer server may know blocks or actions this client does not.
  static T? _named<T extends Enum>(List<T> values, String? name) =>
      values.where((value) => value.name == name).firstOrNull;

  static BlockType? _blockNamed(String? name) => _named(BlockType.values, name);

  static double _toDouble(Object? raw) => (raw as num? ?? 0).toDouble();

  static double _round(double value) {
    final factor = math.pow(10, _decimals);
    return (value * factor).roundToDouble() / factor;
  }

  static List<int> _posToJson(BlockPos pos) => [pos.x, pos.y, pos.z];

  static BlockPos _posFromJson(List<Object?> raw) {
    final values = raw.cast<int>();
    return BlockPos(values[0], values[1], values[2]);
  }

  static List<double> _vectorToJson(Vector3 v) => [
    _round(v.x),
    _round(v.y),
    _round(v.z),
  ];

  static Vector3 _vectorFromJson(List<Object?>? raw) {
    if (raw == null || raw.length < 3) return Vector3.zero();
    return Vector3(_toDouble(raw[0]), _toDouble(raw[1]), _toDouble(raw[2]));
  }

  static Map<String, Object?>? _stackToJson(ItemStack? stack) =>
      stack == null ? null : {'item': stack.type.name, 'count': stack.count};

  static ItemStack? _stackFromJson(Map<String, Object?>? raw) {
    if (raw == null) return null;
    final item = _named(ItemType.values, raw['item'] as String?);
    if (item == null) return null;
    return ItemStack(item, raw['count'] as int? ?? 1);
  }

  static Map<String, Object?> _mobToJson(MobState mob) => {
    'id': mob.id.value,
    'kind': mob.kind.name,
    'pos': _vectorToJson(mob.position),
    'yaw': _round(mob.yaw),
    'hp': _round(mob.health),
    'walk': _round(mob.walkSpeed),
    'fuse': _round(mob.fuse),
  };

  static MobState? _mobFromJson(Map<String, Object?> raw) {
    final kind = _named(MobKind.values, raw['kind'] as String?);
    // A species this build does not have cannot be drawn, so it is dropped
    // rather than guessed at.
    if (kind == null) return null;
    return MobState(
      id: EntityId(raw['id'] as int? ?? 0),
      kind: kind,
      position: _vectorFromJson(raw['pos'] as List?),
      yaw: _toDouble(raw['yaw']),
      health: _toDouble(raw['hp']),
      walkSpeed: _toDouble(raw['walk']),
      fuse: _toDouble(raw['fuse']),
    );
  }

  static Map<String, Object?> _arrowToJson(ArrowState arrow) => {
    'id': arrow.id.value,
    'pos': _vectorToJson(arrow.position),
    'yaw': _round(arrow.yaw),
    'pitch': _round(arrow.pitch),
  };

  static ArrowState _arrowFromJson(Map<String, Object?> raw) => ArrowState(
    id: EntityId(raw['id'] as int? ?? 0),
    position: _vectorFromJson(raw['pos'] as List?),
    yaw: _toDouble(raw['yaw']),
    pitch: _toDouble(raw['pitch']),
  );

  static Map<String, Object?> _playerToJson(RemotePlayerState player) => {
    'id': player.id.value,
    'pos': _vectorToJson(player.position),
    'yaw': _round(player.yaw),
    'pitch': _round(player.pitch),
    'hp': player.health,
  };

  static RemotePlayerState _playerFromJson(Map<String, Object?> raw) =>
      RemotePlayerState(
        id: PlayerId(raw['id'] as String? ?? ''),
        position: _vectorFromJson(raw['pos'] as List?),
        yaw: _toDouble(raw['yaw']),
        pitch: _toDouble(raw['pitch']),
        health: raw['hp'] as int? ?? 0,
      );

  // --- input -----------------------------------------------------------

  static Map<String, Object?> _inputToJson(InputFrame input) => {
    'fwd': _round(input.forward),
    'str': _round(input.strafe),
    'yaw': _round(input.lookYaw),
    'pitch': _round(input.lookPitch),
    'held': [for (final action in input.held) action.name],
    'pressed': [for (final action in input.pressed) action.name],
  };

  static InputFrame _inputFromJson(Map<String, Object?> raw) => InputFrame(
    forward: _toDouble(raw['fwd']),
    strafe: _toDouble(raw['str']),
    lookYaw: _toDouble(raw['yaw']),
    lookPitch: _toDouble(raw['pitch']),
    held: {
      for (final name in (raw['held'] as List? ?? const []))
        ?_named(GameAction.values, name as String?),
    },
    pressed: [
      for (final name in (raw['pressed'] as List? ?? const []))
        ?_named(GameAction.values, name as String?),
    ],
  );

  // --- commands --------------------------------------------------------

  static Map<String, Object?> _commandToJson(GameCommand command) =>
      switch (command) {
        SelectHotbarSlot(:final index) => {'c': 'select', 'i': index},
        CycleHotbarSlot(:final delta) => {'c': 'cycle', 'd': delta},
        ClickSlot(:final ref, :final kind) => {
          'c': 'click',
          'kind': kind.name,
          'ref': _slotRefToJson(ref),
        },
        OpenRoute(:final route) => {'c': 'open', 'route': route.name},
        CloseRoute() => {'c': 'close'},
        OpenRecipes() => {'c': 'recipes'},
        ToggleFlight() => {'c': 'fly'},
        Respawn() => {'c': 'respawn'},
        UseOrPlace() => {'c': 'use'},
        SaveGame() => {'c': 'save'},
      };

  static GameCommand _commandFromJson(Map<String, Object?> raw) {
    final name = raw['c'] as String? ?? '';
    return switch (name) {
      'select' => SelectHotbarSlot(raw['i'] as int? ?? 0),
      'cycle' => CycleHotbarSlot(raw['d'] as int? ?? 0),
      'click' => ClickSlot(
        _slotRefFromJson(raw['ref'] as Map<String, Object?>? ?? const {}),
        kind:
            _named(ClickKind.values, raw['kind'] as String?) ??
            ClickKind.primary,
      ),
      'open' => OpenRoute(
        _named(UiRoute.values, raw['route'] as String?) ?? UiRoute.none,
      ),
      'close' => const CloseRoute(),
      'recipes' => const OpenRecipes(),
      'fly' => const ToggleFlight(),
      'respawn' => const Respawn(),
      'use' => const UseOrPlace(),
      'save' => const SaveGame(),
      _ => throw UnknownMessage('command "$name"'),
    };
  }

  static Map<String, Object?> _slotRefToJson(SlotRef ref) => switch (ref) {
    InventorySlotRef(:final index) => {'r': 'inv', 'i': index},
    GridSlotRef(:final index) => {'r': 'grid', 'i': index},
    FurnaceSlotRef(:final slot) => {'r': 'furnace', 'slot': slot.name},
    CraftResultRef() => {'r': 'result'},
  };

  static SlotRef _slotRefFromJson(Map<String, Object?> raw) {
    final name = raw['r'] as String? ?? '';
    return switch (name) {
      'inv' => InventorySlotRef(raw['i'] as int? ?? 0),
      'grid' => GridSlotRef(raw['i'] as int? ?? 0),
      'furnace' => FurnaceSlotRef(
        _named(FurnaceSlot.values, raw['slot'] as String?) ?? FurnaceSlot.input,
      ),
      'result' => const CraftResultRef(),
      _ => throw UnknownMessage('slot "$name"'),
    };
  }

  // --- events ----------------------------------------------------------

  static Map<String, Object?> _eventToJson(GameEvent event) => switch (event) {
    BlockBroken(:final pos, :final block, :final drops) => {
      'e': 'broken',
      'p': _posToJson(pos),
      'b': block.name,
      'drops': [for (final drop in drops) _stackToJson(drop)],
    },
    ToolTooWeak(:final block) => {'e': 'weak', 'b': block.name},
    InventoryFull(:final item) => {'e': 'full', 'item': item.name},
    PlacementRejected(:final reason) => {'e': 'rejected', 'why': reason.name},
    MobKilled(:final kind, :final loot) => {
      'e': 'killed',
      'kind': kind.name,
      'loot': [for (final drop in loot) _stackToJson(drop)],
    },
    CreeperExploded() => {'e': 'boom'},
    FlightToggled(:final enabled) => {'e': 'fly', 'on': enabled},
    PlayerRespawned() => {'e': 'respawned'},
    GameSaved() => {'e': 'saved'},
  };

  static GameEvent _eventFromJson(Map<String, Object?> raw) {
    final name = raw['e'] as String? ?? '';
    List<ItemStack> stacks(String key) => [
      for (final entry in (raw[key] as List? ?? const []))
        ?_stackFromJson(entry as Map<String, Object?>?),
    ];

    return switch (name) {
      'broken' => BlockBroken(
        _posFromJson(raw['p'] as List? ?? const [0, 0, 0]),
        _blockNamed(raw['b'] as String?) ?? BlockType.air,
        stacks('drops'),
      ),
      'weak' => ToolTooWeak(_blockNamed(raw['b'] as String?) ?? BlockType.air),
      'full' => InventoryFull(
        _named(ItemType.values, raw['item'] as String?) ?? ItemType.stick,
      ),
      'rejected' => PlacementRejected(
        _named(PlacementRejection.values, raw['why'] as String?) ??
            PlacementRejection.notABlock,
      ),
      'killed' => MobKilled(
        _named(MobKind.values, raw['kind'] as String?) ?? MobKind.zombie,
        stacks('loot'),
      ),
      'boom' => const CreeperExploded(),
      'fly' => FlightToggled(raw['on'] as bool? ?? false),
      'respawned' => const PlayerRespawned(),
      'saved' => const GameSaved(),
      _ => throw UnknownMessage('event "$name"'),
    };
  }
}
