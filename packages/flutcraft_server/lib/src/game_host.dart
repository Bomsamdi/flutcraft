import 'dart:math';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_protocol/flutcraft_protocol.dart';
import 'package:vector_math/vector_math.dart';

import 'client_link.dart';
import 'world_store.dart';

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

  /// Opens the world kept in [store], or starts one if there is none there.
  ///
  /// The people who have been here before are remembered but not put back in
  /// the world: they come back when they connect, with what they were
  /// carrying.
  factory GameHost.fromStore(WorldStore store, {int seed = 1337}) {
    final saved = store.loadWorld();
    final host = saved == null
        ? GameHost.newWorld(seed: seed)
        : GameHost.on(
            const GamePersistence().restoreWorld(saved),
            seed: saved.seed,
          );

    host._store = store;
    for (final player in store.loadPlayers()) {
      host._remembered[player.id] = player;
    }
    return host;
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
      loop: GameLoop.authoritative(
        state: state,
        random: Random(seed),
        world: WorldSystems(
          spawner: MobSpawner(world: world, seed: seed),
          random: Random(seed),
          saveSink: saveSink,
          // A shared world does not stop because somebody opened their bag.
          pausesWhenEveryoneSteppedAway: false,
        ),
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

  WorldStore? _store;

  /// What each player was carrying when they last left.
  final Map<PlayerId, PlayerSave> _remembered = {};

  /// How often the world is written down, in ticks.
  static const int saveEvery = kTicksPerSecond * 60;

  int _sinceSave = 0;

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

    state.participants.putIfAbsent(who, () => _returning(who) ?? _arrive(who));
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

  /// Somebody this world has seen before, put back as they left.
  ///
  /// Keyed by the id the client chose and keeps, not by the connection, so
  /// coming back after a dropped connection finds the same inventory rather
  /// than a new player standing beside the old one's belongings.
  Participant? _returning(PlayerId who) {
    final saved = _remembered[who];
    if (saved == null) return null;
    return const GamePersistence().restorePlayer(saved, state.world);
  }

  /// Somebody who has never been in this world before.
  ///
  /// They arrive with the same handful of blocks a new single-player game
  /// hands out, because a world you cannot build in on your first minute is
  /// not much of an invitation.
  Participant _arrive(PlayerId who) {
    final participant = Participant(
      id: who,
      player: Player(world: state.world, spawn: Vector3.zero())..respawn(),
    );
    participant.inventory
      ..add(ItemType.log, 8)
      ..add(ItemType.planks, 8)
      ..add(ItemType.cobblestone, 16);
    return participant;
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

    final saved = const GamePersistence().capturePlayer(participant);
    _remembered[who] = saved;
    _store?.savePlayer(saved);
    return saved;
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
      case InputTick(:final tick, :final input, :final claim):
        // Merged, not replaced. A client sends one frame per simulation step
        // and a socket delivers several of them at once whenever the network
        // bunched them up; the world steps on its own clock in between.
        // Overwriting kept only the last of each burst, which is a state and
        // so survives — but a turn and a tap are amounts, and those were
        // simply gone.
        final waiting = _pending[who];
        _pending[who] = _HeldInput(
          waiting == null ? input : waiting.frame.mergedWith(input),
          _tick + inputHoldTicks,
          // A claim is a state, like an axis: the newest one is the truth,
          // and there is nothing to add up.
          claim: claim,
        );
        _ackTick[who] = tick;
      case Command(:final command):
        _publish(loop.dispatch(who, command));
      case SignIn():
      case SignUp():
      // Already in. Signing in twice on one connection is not news, and it is
      // certainly not a way to become somebody else.
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
    // Whatever each player last said their crosshair was on, and nothing at
    // all for whoever has gone quiet: a claim that outlived its input would
    // pin that player's aim to a block they walked away from.
    for (final it in state.participants.values) {
      it.claimedAim = _pending[it.id]?.claim;
    }
    _publish(loop.tick(kStep, inputs));

    // What is left of an input on the next tick is the part that may repeat:
    // a held key, but not the tap that opened a screen.
    for (final entry in _pending.entries) {
      entry.value.frame = entry.value.frame.sustained;
    }

    _broadcastWorldChanges();
    _saveOnSchedule();
    _sinceSnapshot++;
    if (_sinceSnapshot < snapshotEvery) return;
    _sinceSnapshot = 0;
    _broadcastSnapshot();
  }

  /// Writes the world down every so often.
  ///
  /// The world only: an autosave that also rewrote everybody's inventory
  /// would be doing sixty times the work for something that changes when a
  /// player does, not when a minute passes.
  void _saveOnSchedule() {
    final store = _store;
    if (store == null) return;
    if (++_sinceSave < saveEvery) return;
    _sinceSave = 0;
    store.saveWorld(const GamePersistence().captureWorld(state));
  }

  /// Writes everything down now — on the way out, say.
  void saveNow() {
    final store = _store;
    if (store == null) return;
    store.saveWorld(const GamePersistence().captureWorld(state));
    for (final participant in state.participants.values) {
      if (participant.id == caretaker) continue;
      store.savePlayer(const GamePersistence().capturePlayer(participant));
    }
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

    // The log remembers what each cell *was*; what goes on the wire is what
    // it is now, read back out of the world.
    final delta = WorldDelta(_tick, [
      for (final pos in changed.keys)
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
  _HeldInput(this.frame, this.expiresAt, {this.claim});

  InputFrame frame;
  final int expiresAt;

  /// Which block that client said its crosshair was on.
  final AimClaim? claim;
}
