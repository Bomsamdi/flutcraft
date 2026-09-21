import '../actors/player_id.dart';
import 'dart:math';

import '../actors/mob.dart';
import '../actors/mob_behavior.dart';
import '../aiming/aim_result.dart';
import '../blocks/block_interaction.dart';
import '../crafting/recipes.dart';
import '../inventory/inventory.dart';
import '../input/action_commands.dart';
import '../input/game_action.dart';
import '../input/input_frame.dart';
import '../items/item_type.dart';
import '../save/save_sink.dart';
import 'addressed_event.dart';
import 'game_command.dart';
import 'game_event.dart';
import 'game_state.dart';
import 'participant.dart';
import 'systems/aiming_system.dart';
import 'systems/autosave_system.dart';
import 'systems/entity_separation_system.dart';
import 'systems/explosion_system.dart';
import 'systems/furnace_system.dart';
import 'systems/mining_system.dart';
import 'systems/mob_ai_system.dart';
import 'systems/placement_system.dart';
import 'systems/player_movement_system.dart';
import 'systems/projectile_system.dart';
import 'ui_route.dart';
import '../machines/furnace_state.dart';
import 'package:vector_math/vector_math.dart';

/// Runs the simulation: executes commands, then ticks every system in order.
///
/// This is the whole game, minus rendering. It has no Flutter, no Flame and
/// no GPU, so a test can run thousands of frames in milliseconds — which is
/// the point of the entire refactor.
class GameLoop implements MobTickContext {
  GameLoop({
    required this.state,
    required MobSpawner spawner,
    Random? random,
    SaveSink? saveSink,
    double autosaveInterval = 60,
  }) : _mobAi = MobAiSystem(spawner: spawner, random: random ?? Random()),
       _mining = MiningSystem(random: random ?? Random()),
       _autosave = saveSink == null
           ? null
           : AutosaveSystem(sink: saveSink, interval: autosaveInterval);

  final GameState state;

  final MiningSystem _mining;
  final MobAiSystem _mobAi;
  final PlacementSystem _placement = PlacementSystem();
  final EntitySeparationSystem _separation = const EntitySeparationSystem();
  final ExplosionSystem _explosions = const ExplosionSystem();
  final ProjectileSystem _projectiles = const ProjectileSystem();
  final FurnaceSystem _furnaces = const FurnaceSystem();
  final AimingSystem _aiming = const AimingSystem();
  final PlayerMovementSystem _movement = const PlayerMovementSystem();

  /// `null` when nothing is listening for saves — tests, mostly.
  final AutosaveSystem? _autosave;

  final BlockRegistry _blocks = BlockRegistry.standard;

  /// Where each player's recipe book should return to when closed.
  final Map<PlayerId, UiRoute?> _routeBeforeRecipes = {};

  final List<AddressedEvent> _events = [];

  /// Advances the world by [dt] seconds and returns what happened.
  ///
  /// Takes one frame of input per player. A player with nothing in [inputs]
  /// is still simulated — they simply asked for nothing this tick, which is
  /// what a disconnected client looks like from here.
  List<AddressedEvent> tick(double dt, Map<PlayerId, InputFrame> inputs) {
    _events.clear();

    // Furnaces and autosave belong to the world, and keep going even while
    // somebody has a screen open.
    _furnaces.update(state, dt);
    if (_autosave?.update(state, dt) ?? false) {
      // The world was saved, not one player's copy of it.
      _events.add(const AddressedEvent.everyone(GameSaved()));
    }

    for (final participant in state.participants.values) {
      _tickPlayer(participant, dt, inputs[participant.id] ?? InputFrame.idle);
    }

    // The world itself only stops when everyone has stepped away from it.
    if (state.participants.values.every((it) => it.route.pausesWorld)) {
      return List.of(_events);
    }

    _events.addAll(_mobAi.update(state, dt, this));
    // Everyone has moved by now, so this is the moment to untangle them.
    _separation.update(state);
    _projectiles.update(state, dt);

    return List.of(_events);
  }

  /// One player's half of a tick: their input, their aim, their swing.
  void _tickPlayer(Participant it, double dt, InputFrame input) {
    if (it.player.isDead && it.route != UiRoute.dead) {
      it.route = UiRoute.dead;
    }

    // Buttons that were tapped this tick become commands. What each one means
    // depends on where that player is, which is why it is decided in one
    // place rather than in whichever source happened to see the key.
    for (final action in input.pressed) {
      final command = commandFor(action, it.route);
      if (command != null) dispatch(it.id, command);
    }

    if (it.route.pausesWorld) return;

    if (input.lookYaw != 0 || input.lookPitch != 0) {
      it.player.look(input.lookYaw, input.lookPitch);
    }
    _movement.update(it, dt, input.moveFor(flying: it.player.flying));
    _aiming.update(state, it);
    // A system answers what happened; the loop knows whose turn it was.
    _events.addAll(
      addressedTo(
        it.id,
        _mining.update(state, it, dt, active: input.isHeld(GameAction.primary)),
      ),
    );
    _events.addAll(
      addressedTo(
        it.id,
        _placement.update(
          state,
          it,
          dt,
          active: input.isHeld(GameAction.secondary),
        ),
      ),
    );
  }

  /// Advances a single-player game.
  List<AddressedEvent> tickSolo(double dt, InputFrame input) =>
      tick(dt, {state.solo.id: input});

  /// Applies one player's action and returns what it caused.
  List<AddressedEvent> dispatch(PlayerId who, GameCommand command) {
    final it = state.participants[who];
    // A command from somebody who has left is not an error, it is late.
    if (it == null) return const [];

    final before = _events.length;
    switch (command) {
      case SelectHotbarSlot(:final index):
        if (index >= 0 && index < it.inventory.hotbarSize) {
          it.selectedSlot = index;
          it.breakProgress = 0;
        }
      case CycleHotbarSlot(:final delta):
        final size = it.inventory.hotbarSize;
        it.selectedSlot = (it.selectedSlot + delta) % size;
        it.breakProgress = 0;
      case ClickSlot(:final ref, :final kind):
        _clickSlot(it, ref, kind);
      case OpenRoute(:final route):
        _openRoute(it, route);
      case CloseRoute():
        _closeRoute(it);
      case OpenRecipes():
        _openRecipes(it);
      case ToggleFlight():
        it.player.flying = !it.player.flying;
        if (it.player.flying) it.player.velocity.y = 0;
        _events.add(AddressedEvent(FlightToggled(it.player.flying), who));
      case Respawn():
        it.player.respawn();
        // Only a solo game may clear the world on one player's death; with
        // company, the mobs are everybody's problem.
        if (state.participants.length == 1) {
          _mobAi.despawnAll(state);
          _projectiles.clear(state);
        }
        it.route = UiRoute.none;
        _events.add(AddressedEvent(const PlayerRespawned(), who));
      case UseOrPlace():
        _useOrPlace(it);
      case SaveGame():
        if (_autosave?.saveNow(state) ?? false) {
          // Asked for by one player, so told to that one.
          _events.add(AddressedEvent(const GameSaved(), who));
        }
    }
    return _events.sublist(before);
  }

  /// Applies an action in a single-player game.
  List<AddressedEvent> dispatchSolo(GameCommand command) =>
      dispatch(state.solo.id, command);

  void _useOrPlace(Participant it) {
    if (it.aim case BlockTarget(:final hit)) {
      switch (_blocks.interactionFor(hit.block)) {
        case OpenCraftingTable():
          _openRoute(it, UiRoute.craftingTable);
        case OpenFurnace():
          state.furnaces.open(hit.pos);
          it.openFurnace = hit.pos;
          _openRoute(it, UiRoute.furnace);
        case null:
          _events.addAll(addressedTo(it.id, _placement.placeNow(state, it)));
      }
    }
  }

  void _openRoute(Participant it, UiRoute route) {
    it.route = route;
    it.breakProgress = 0;
    _placement.resetCooldown(it);
  }

  void _openRecipes(Participant it) {
    if (it.route == UiRoute.recipes) {
      _closeRoute(it);
      return;
    }
    _routeBeforeRecipes[it.id] = it.route == UiRoute.none ? null : it.route;
    _openRoute(it, UiRoute.recipes);
  }

  /// Closing gives back whatever sat in the crafting grid or on the cursor,
  /// so a player cannot lose items by pressing Escape.
  void _closeRoute(Participant it) {
    if (it.route == UiRoute.recipes) {
      it.route = _routeBeforeRecipes.remove(it.id) ?? UiRoute.none;
      return;
    }

    final grid = it.activeGrid;
    for (var i = 0; i < grid.length; i++) {
      final stack = grid[i];
      if (stack == null) continue;
      it.inventory.add(stack.type, stack.count);
      grid[i] = null;
    }
    final held = it.cursor;
    if (held != null) {
      it.inventory.add(held.type, held.count);
      it.cursor = null;
    }
    it.openFurnace = null;
    it.route = UiRoute.none;
  }

  void _clickSlot(Participant it, SlotRef ref, ClickKind kind) {
    switch (ref) {
      case InventorySlotRef(:final index):
        _swap(
          it,
          () => it.inventory[index],
          (value) => it.inventory[index] = value,
          kind,
        );
      case GridSlotRef(:final index):
        final grid = it.activeGrid;
        _swap(it, () => grid[index], (value) => grid[index] = value, kind);
      case FurnaceSlotRef(:final slot):
        final furnace = it.openFurnace == null
            ? null
            : state.furnaces[it.openFurnace!];
        if (furnace == null) return;
        if (slot == FurnaceSlot.output) {
          final result = takeOutput(furnace.output, it.cursor);
          furnace.output = result.slot;
          it.cursor = result.cursor;
          return;
        }
        _swap(
          it,
          () => furnace.slot(slot),
          (value) => furnace.setSlot(slot, value),
          kind,
        );
      case CraftResultRef():
        _takeCraftResult(it);
    }
  }

  void _swap(
    Participant it,
    ItemStack? Function() get,
    void Function(ItemStack?) set,
    ClickKind kind,
  ) {
    final result = kind == ClickKind.primary
        ? transferSlot(get(), it.cursor)
        : splitSlot(get(), it.cursor);
    set(result.slot);
    it.cursor = result.cursor;
  }

  void _takeCraftResult(Participant it) {
    final grid = it.activeGrid;
    final recipe = matchRecipe(grid);
    if (recipe == null) return;
    if (!cursorAccepts(it.cursor, recipe.output, recipe.outputCount)) return;

    final held = it.cursor;
    it.cursor = held == null
        ? ItemStack(recipe.output, recipe.outputCount)
        : held.plus(recipe.outputCount);
    consumeGrid(grid);
  }

  /// What a player's crafting grid would produce right now.
  ItemStack? craftPreviewFor(Participant it) {
    final recipe = matchRecipe(it.activeGrid);
    return recipe == null ? null : ItemStack(recipe.output, recipe.outputCount);
  }

  /// What the only player's grid would produce, in a single-player game.
  ItemStack? get craftPreview => craftPreviewFor(state.solo);

  @override
  void spawnArrow(Vector3 from, Vector3 direction) => state.launch(
    Arrow(world: state.world, spawn: from, direction: direction),
  );

  @override
  void explode(Vector3 at, double radius, int maxDamage) => _events.addAll([
    // A blast is heard by everyone, not only by whoever it caught.
    for (final event in _explosions.explode(state, at, radius, maxDamage))
      AddressedEvent.everyone(event),
  ]);
}
