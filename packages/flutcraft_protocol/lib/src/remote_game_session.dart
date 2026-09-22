import 'dart:async';
import 'dart:math';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:vector_math/vector_math.dart';

import 'entity_mirror.dart';
import 'credentials.dart';
import 'message_channel.dart';
import 'messages.dart';

/// A game that is really happening somewhere else.
///
/// Satisfies both of the interfaces a local game does — [GameSession] for the
/// widgets, [SimulatedSession] for the renderer — so nothing above it can
/// tell the difference. That is the whole trick: the interface was already
/// four members and the renderer three, and neither of them says where the
/// world is.
///
/// What it does underneath is simulate the player's own movement immediately
/// and correct it when the server disagrees. Waiting a round trip to walk is
/// unshippable; so is having two machines with different opinions about
/// where a zombie is. The split between those two is the whole design.
class RemoteGameSession implements PlayableSession {
  RemoteGameSession._({
    required this.channel,
    required this.viewerId,
    required GameState state,
    required int serverTick,
    required StreamSubscription<ServerMessage> subscription,
  }) : _state = state,
       _tick = serverTick,
       // A named parameter cannot be `this._subscription`: a named parameter
       // cannot start with an underscore.
       // ignore: prefer_initializing_formals
       _subscription = subscription,
       loop = GameLoop.predicting(state: state, random: Random(serverTick)) {
    _snapshot = GameSnapshot.forPlayer(state, state.participants[viewerId]!);
  }

  /// Joins a server and waits for the world.
  ///
  /// Asynchronous because there is nothing to render until the world arrives;
  /// the composition root already waits for a save to load, and this is the
  /// same wait with a different source.
  /// A refusal comes back as a [SignInRefused], not as a timeout: a server
  /// that will not have you says so at once, and waiting ten seconds to tell
  /// the player their password is wrong would be a poor way to say it.
  static Future<RemoteGameSession> join(
    MessageChannel channel,
    Credentials credentials, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // One subscription from the first moment, and anything that arrives
    // before the world is built waits in a queue.
    //
    // Subscribing twice — once to wait for the welcome, once for the rest —
    // leaves a gap between them, and a broadcast stream keeps nothing for
    // whoever was not listening. A server sends the welcome and the player's
    // inventory back to back, so the gap is not theoretical: the inventory
    // fell into it every time, and the player arrived empty-handed.
    final waiting = <ServerMessage>[];
    final welcome = Completer<Welcome>();

    final subscription = channel.incoming.listen((message) {
      if (welcome.isCompleted) {
        waiting.add(message);
        return;
      }
      switch (message) {
        case Welcome():
          welcome.complete(message);
        case Kick(:final reason):
          welcome.completeError(SignInRefused(reason));
        default:
          waiting.add(message);
      }
    });
    channel.send(credentials.greeting);

    final Welcome arrived;
    try {
      arrived = await welcome.future.timeout(timeout);
    } on Object {
      await subscription.cancel();
      rethrow;
    }

    final session = RemoteGameSession._(
      channel: channel,
      viewerId: arrived.you,
      serverTick: arrived.tick,
      state: _worldFrom(arrived),
      subscription: subscription,
    );
    subscription.onData(session._receive);
    waiting.forEach(session._receive);
    return session;
  }

  /// How far the player may be wrong before the view is snapped rather than
  /// eased. Under it, the correction is spread over [_correctionTicks].
  static const double snapAbove = 0.3;

  /// How many ticks a small correction is spread over.
  static const int _correctionTicks = 5;

  /// How many of this player's own inputs are kept for replaying.
  static const int _bufferedTicks = kTicksPerSecond;

  final MessageChannel channel;

  @override
  final PlayerId viewerId;

  /// The loop that predicts. It owns none of the systems that rule a world.
  final GameLoop loop;

  final GameState _state;
  final EntityMirror _mirror = EntityMirror();
  final _snapshots = StreamController<GameSnapshot>.broadcast();
  final _events = StreamController<GameEvent>.broadcast();
  final TickClock _clock = TickClock();

  /// Input this player has sent that the server has not confirmed applying.
  final List<(int, InputFrame)> _unacked = [];

  /// Blocks put down locally that the server has not yet confirmed.
  final List<_Prediction> _predictions = [];

  final StreamSubscription<ServerMessage> _subscription;
  late GameSnapshot _snapshot;

  final Vector3 _correction = Vector3.zero();
  int _tick;
  int _stepsSinceSnapshot = 0;
  int _inventoryRevision = -1;

  @override
  GameState get state => _state;

  @override
  GameSnapshot get snapshot => _snapshot;

  @override
  Stream<GameSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<GameEvent> get events => _events.stream;

  /// The tick this client believes it is on.
  int get currentTick => _tick;

  /// How many of this player's inputs are still unconfirmed.
  int get unackedInputs => _unacked.length;

  /// Blocks this client has put down on its own authority so far.
  int get unconfirmedBlocks => _predictions.length;

  @override
  void dispatch(GameCommand command) {
    // Which screen is open is this player's own business and must be
    // instant; everything it leads to is the server's word.
    loop.dispatch(viewerId, command);
    channel.send(Command(command));
    _publishSnapshot();
  }

  @override
  void tick(double dt, InputFrame input) {
    final steps = _clock.stepsFor(dt);
    for (var i = 0; i < steps; i++) {
      _step(input.asStep(i, steps));
    }
    _mirror.advance(steps * kStep);

    _stepsSinceSnapshot += steps;
    if (_stepsSinceSnapshot < kTicksPerSecond / 20) return;
    _stepsSinceSnapshot = 0;
    _publishSnapshot();
  }

  void _step(InputFrame frame) {
    _tick++;
    _unacked.add((_tick, frame));
    if (_unacked.length > _bufferedTicks) _unacked.removeAt(0);
    channel.send(InputTick(_tick, frame));

    loop.tick(kStep, {viewerId: frame});
    _recordPredictions();
    _easeCorrection();
  }

  /// Moves a little of a small correction into the player each tick.
  ///
  /// Applying it all at once would be a visible jerk for an error nobody can
  /// see; leaving it would let a slow drift build up.
  void _easeCorrection() {
    if (_correction.length2 < 1e-9) return;
    final step = _correction / _correctionTicks.toDouble();
    viewer.player.position.add(step);
    _correction.sub(step);
  }

  void _recordPredictions() {
    for (final entry in state.world.drainChanges().entries) {
      _predictions.add(_Prediction(_tick, entry.key, entry.value));
    }
  }

  void _receive(ServerMessage message) {
    switch (message) {
      case Welcome():
        // Already in; a second welcome would mean starting over.
        break;
      case SelfState():
        _reconcile(message);
      case EntityDelta():
        _mirror.apply(message, state);
      case PlayerStates():
        _mirrorOthers(message);
      case WorldDelta():
        _applyWorld(message);
      case InventoryState():
        _applyInventory(message);
      case ExplosionAt(:final at, :final radius):
        // Worked out locally rather than sent as three hundred block
        // changes: the crater is integer arithmetic over a radius, so both
        // machines arrive at exactly the same holes.
        _carve(at, radius);
      case Notice(:final event):
        _events.add(event);
      case Ping(:final id):
        channel.send(Pong(id));
      case Kick():
        unawaited(close());
    }
  }

  /// Puts the player where the server says, then replays what it has not
  /// seen yet.
  void _reconcile(SelfState corrected) {
    _unacked.removeWhere((entry) => entry.$1 <= corrected.ackTick);

    final player = viewer.player;
    final predicted = player.position.clone();

    // Where the player is, the server decides. Where they are *looking* it
    // does not: that is a mouse in somebody's hand, and taking the server's
    // slightly older answer for it would drag the view backwards a little on
    // every packet. The server learns the look from the input anyway, so the
    // two converge without anybody being overruled.
    player
      ..position.setFrom(corrected.position)
      ..velocity.setFrom(corrected.velocity)
      ..onGround = corrected.onGround
      ..flying = corrected.flying
      ..health = corrected.health;

    const movement = PlayerMovementSystem();
    for (final (_, frame) in _unacked) {
      movement.update(viewer, kStep, frame.moveFor(flying: player.flying));
    }

    final error = player.position.distanceTo(predicted);
    if (error >= snapAbove) {
      _correction.setZero();
      return;
    }

    // Small enough to hide: keep showing what the player saw, and walk the
    // difference in over the next few ticks.
    _correction.setFrom(player.position - predicted);
    player.position.setFrom(predicted);
  }

  void _mirrorOthers(PlayerStates reported) {
    final seen = <PlayerId>{viewerId};
    for (final other in reported.players) {
      if (other.id == viewerId) continue;
      seen.add(other.id);

      final participant = state.participants.putIfAbsent(
        other.id,
        () => Participant(
          id: other.id,
          player: Player(world: state.world, spawn: other.position),
        ),
      );
      participant.player
        ..position.setFrom(other.position)
        ..yaw = other.yaw
        ..pitch = other.pitch
        ..health = other.health;
    }

    state.participants.removeWhere((id, _) => !seen.contains(id));
  }

  void _applyWorld(WorldDelta delta) {
    for (final change in delta.changes) {
      state.world.setBlock(
        change.pos.x,
        change.pos.y,
        change.pos.z,
        change.block,
      );
    }
    final confirmed = {for (final change in delta.changes) change.pos};

    // Anything guessed at or before this delta's tick that it did not
    // mention never happened — somebody else got there first, or the server
    // refused it. One rule covers both.
    _predictions.removeWhere((prediction) {
      if (prediction.tick > delta.tick) return false;
      if (!confirmed.contains(prediction.pos)) prediction.undo(state.world);
      return true;
    });

    // Applying the server's word is not a guess of ours.
    state.world.drainChanges();
  }

  void _applyInventory(InventoryState reported) {
    // A copy that left the server before the one already applied is stale.
    if (reported.revision <= _inventoryRevision) return;
    _inventoryRevision = reported.revision;

    final it = viewer;
    for (var i = 0; i < it.inventory.length; i++) {
      it.inventory[i] = i < reported.slots.length ? reported.slots[i] : null;
    }
    it
      ..selectedSlot = reported.selectedSlot
      ..cursor = reported.cursor;
  }

  void _carve(Vector3 at, double radius) {
    final reach = radius.ceil();
    final centre = BlockPos.of(at);
    for (var y = centre.y - reach; y <= centre.y + reach; y++) {
      for (var z = centre.z - reach; z <= centre.z + reach; z++) {
        for (var x = centre.x - reach; x <= centre.x + reach; x++) {
          final dx = x + 0.5 - at.x;
          final dy = y + 0.5 - at.y;
          final dz = z + 0.5 - at.z;
          if (dx * dx + dy * dy + dz * dz > radius * radius) continue;
          final block = state.world.blockAt(x, y, z);
          if (!block.solid || !block.breakable) continue;
          state.world.setBlock(x, y, z, BlockType.air);
        }
      }
    }
    state.world.drainChanges();
  }

  void _publishSnapshot() {
    final it = state.participants[viewerId];
    if (it == null) return;
    _snapshot = GameSnapshot.forPlayer(state, it);
    _snapshots.add(_snapshot);
  }

  /// Leaves the server.
  Future<void> close() async {
    await _subscription.cancel();
    await channel.close();
    await _snapshots.close();
    await _events.close();
  }

  static GameState _worldFrom(Welcome welcome) {
    final world = VoxelWorld();
    TerrainGenerator(seed: welcome.world.seed).generate(world);
    for (final entry in welcome.world.edits.entries) {
      final pos = entry.key;
      world.setRaw(pos.x, pos.y, pos.z, entry.value);
    }
    world
      ..edits.addAll(welcome.world.edits)
      ..markAllDirty();

    return GameState(
      world: world,
      players: [
        Participant(
          id: welcome.you,
          player: Player(world: world, spawn: Vector3.zero())..respawn(),
        ),
      ],
    );
  }
}

/// A block this client put down before anybody agreed.
class _Prediction {
  const _Prediction(this.tick, this.pos, this.was);

  final int tick;
  final BlockPos pos;

  /// What was in that cell before the guess, so it can be put back.
  final BlockType was;

  void undo(VoxelWorld world) => world.setBlock(pos.x, pos.y, pos.z, was);
}
