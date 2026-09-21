import 'dart:math';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_protocol/flutcraft_protocol.dart';
import 'package:vector_math/vector_math.dart';

import 'client_link.dart';

/// One world, everybody in it, and the loop that decides what is true.
///
/// Knows nothing about sockets: clients arrive as a [ClientLink], which a
/// test can satisfy with a list. That is what lets the rules of a server —
/// who joins, what they are told, what happens when they stop reading — be
/// tested without binding a port.
class GameHost {
  GameHost({
    required this.state,
    required this.loop,
    this.snapshotEvery = kTicksPerSecond ~/ 20,
  });

  /// Builds a host over a freshly generated world.
  factory GameHost.newWorld({int seed = 1337, SaveSink? saveSink}) {
    final world = VoxelWorld();
    TerrainGenerator(seed: seed).generate(world);
    return GameHost.on(world, seed: seed, saveSink: saveSink);
  }

  /// Builds a host over a world that already exists — one just loaded, say.
  factory GameHost.on(VoxelWorld world, {int seed = 1337, SaveSink? saveSink}) {
    // A world with nobody in it still has to exist, so the first player is a
    // placeholder that leaves as soon as somebody real arrives.
    final state = GameState(
      world: world,
      players: [
        Participant(
          id: caretaker,
          player: Player(world: world, spawn: Vector3.zero())..respawn(),
        ),
      ],
    );
    return GameHost(
      state: state,
      loop: GameLoop(
        state: state,
        spawner: MobSpawner(world: world, seed: seed),
        random: Random(seed),
        saveSink: saveSink,
      ),
    );
  }

  /// The id of the placeholder that keeps an empty world valid.
  ///
  /// [GameState] insists on at least one player, because a game with nobody
  /// in it is a bug everywhere except here. Rather than weaken that rule for
  /// everyone, a server keeps one participant nobody is playing.
  static const PlayerId caretaker = PlayerId('#caretaker');

  final GameState state;
  final GameLoop loop;

  /// How many simulation steps pass between broadcasts.
  final int snapshotEvery;

  final Map<PlayerId, ClientLink> _links = {};
  final Map<PlayerId, _HeldInput> _pending = {};
  final Map<PlayerId, int> _ackTick = {};
  final Map<PlayerId, int> _sentRevision = {};

  int _tick = 0;
  int _sinceSnapshot = 0;

  /// The server's current tick. Clients stamp their input with it.
  int get tick => _tick;

  /// Who is connected right now.
  Iterable<PlayerId> get players => _links.keys;

  /// Lets a client in and tells it what world it landed in.
  void join(PlayerId who, ClientLink link) {
    // Somebody reconnecting replaces their old connection rather than
    // standing beside it.
    _links.remove(who)?.close();
    _links[who] = link;

    state.participants.putIfAbsent(
      who,
      () => Participant(
        id: who,
        player: Player(world: state.world, spawn: Vector3.zero())..respawn(),
      ),
    );
    _retireCaretaker();

    link.send(
      Welcome(
        you: who,
        tick: _tick,
        world: WorldState(
          seed: state.world.seed,
          edits: Map.of(state.world.edits),
        ),
      ),
    );
    _sendInventory(who, force: true);
  }

  /// Sees a client out. Returns what they were carrying, so a caller can
  /// write it down before it is gone.
  PlayerSave? leave(PlayerId who) {
    _links.remove(who)?.close();
    _pending.remove(who);
    _ackTick.remove(who);
    _sentRevision.remove(who);

    final participant = state.leave(who);
    if (participant == null) return null;
    // A world may not be left empty, so the caretaker comes back.
    if (state.participants.isEmpty) _hireCaretaker();
    return const GamePersistence().capturePlayer(participant);
  }

  /// How long a client's last input keeps applying without a new one.
  ///
  /// Not one tick: a single lost packet would then freeze that player for a
  /// frame, and the internet loses packets. Not for ever either — a client
  /// that stopped talking must stop walking, not run into a wall until the
  /// socket times out. A sixth of a second covers a stutter and nothing more.
  static const int inputHoldTicks = 10;

  /// Records what a client wants to do.
  ///
  /// Only the newest frame is kept. A client that sends three frames between
  /// two server ticks is ahead of the server, not owed three simulations.
  void receive(PlayerId who, ClientMessage message) {
    if (!state.participants.containsKey(who)) return;

    switch (message) {
      case InputTick(:final tick, :final input):
        _pending[who] = _HeldInput(input, _tick + inputHoldTicks);
        _ackTick[who] = tick;
      case Command(:final command):
        _publish(loop.dispatch(who, command));
      case Hello():
      // Already in; a second hello is not news.
      case Pong():
      // Timing only, and nothing yet depends on it.
    }
  }

  /// Advances the world by [dt] seconds of wall clock.
  void advance(double dt) {
    final steps = _clock.stepsFor(dt);
    for (var i = 0; i < steps; i++) {
      step();
    }
  }

  final TickClock _clock = TickClock();

  /// Runs exactly one simulation step and tells whoever needs to know.
  void step() {
    _tick++;
    _pending.removeWhere((_, held) => held.expiresAt <= _tick);
    final inputs = {
      for (final entry in _pending.entries) entry.key: entry.value.frame,
    };
    _publish(loop.tick(kStep, inputs));

    // What is left of an input on the next tick is the part that may repeat:
    // a held key, but not the tap that opened a screen.
    for (final entry in _pending.entries) {
      entry.value.frame = entry.value.frame.sustained;
    }

    _broadcastWorldChanges();
    _sinceSnapshot++;
    if (_sinceSnapshot < snapshotEvery) return;
    _sinceSnapshot = 0;
    _broadcastSnapshot();
  }

  void _publish(List<AddressedEvent> events) {
    for (final addressed in events) {
      for (final entry in _links.entries) {
        if (addressed.reaches(entry.key)) {
          entry.value.send(Notice(addressed.event));
        }
      }
    }
    for (final who in _links.keys) {
      _sendInventory(who);
    }
  }

  void _broadcastWorldChanges() {
    final changed = state.world.drainChanges();
    if (changed.isEmpty) return;

    final delta = WorldDelta(_tick, [
      for (final pos in changed)
        BlockChange(pos, state.world.blockAt(pos.x, pos.y, pos.z)),
    ]);
    for (final link in _links.values) {
      link.send(delta);
    }
  }

  void _broadcastSnapshot() {
    final entities = EntityDelta(
      tick: _tick,
      mobs: [
        for (final mob in state.mobs)
          MobState(
            id: mob.id,
            kind: mob.kind,
            position: mob.position,
            yaw: mob.yaw,
            health: mob.health,
            walkSpeed: mob.walkSpeed,
            fuse: mob.fuse,
          ),
      ],
      arrows: [
        for (final arrow in state.arrows)
          ArrowState(
            id: arrow.id,
            position: arrow.position,
            yaw: arrow.yaw,
            pitch: arrow.pitch,
          ),
      ],
    );

    final everyone = PlayerStates(_tick, [
      for (final it in state.participants.values)
        if (it.id != caretaker)
          RemotePlayerState(
            id: it.id,
            position: it.player.position,
            yaw: it.player.yaw,
            pitch: it.player.pitch,
            health: it.player.health,
          ),
    ]);

    for (final entry in _links.entries) {
      entry.value
        ..send(entities)
        ..send(everyone);

      final it = state.participants[entry.key];
      if (it == null) continue;
      entry.value.send(
        SelfState(
          ackTick: _ackTick[entry.key] ?? 0,
          position: it.player.position,
          velocity: it.player.velocity,
          yaw: it.player.yaw,
          pitch: it.player.pitch,
          onGround: it.player.onGround,
          flying: it.player.flying,
          health: it.player.health,
        ),
      );
    }
  }

  /// Sends an inventory only when it has actually changed.
  void _sendInventory(PlayerId who, {bool force = false}) {
    final it = state.participants[who];
    final link = _links[who];
    if (it == null || link == null) return;

    final revision = it.inventory.revision;
    if (!force && _sentRevision[who] == revision) return;
    _sentRevision[who] = revision;

    link.send(
      InventoryState(
        revision: revision,
        slots: List.of(it.inventory.slots),
        selectedSlot: it.selectedSlot,
        cursor: it.cursor,
      ),
    );
  }

  void _retireCaretaker() {
    if (state.participants.length > 1) state.leave(caretaker);
  }

  void _hireCaretaker() {
    state.join(
      Participant(
        id: caretaker,
        player: Player(world: state.world, spawn: Vector3.zero())..respawn(),
      ),
    );
  }
}

/// A client's last input, and the tick it stops applying on.
class _HeldInput {
  _HeldInput(this.frame, this.expiresAt);

  InputFrame frame;
  final int expiresAt;
}
