import 'dart:math';

import '../actors/mob.dart';
import '../actors/mob_behavior.dart';
import '../actors/player.dart';
import '../aiming/aim_result.dart';
import '../blocks/block_interaction.dart';
import '../crafting/recipes.dart';
import '../inventory/inventory.dart';
import '../input/action_commands.dart';
import '../input/game_action.dart';
import '../input/input_frame.dart';
import '../items/item_type.dart';
import '../save/save_sink.dart';
import 'game_command.dart';
import 'game_event.dart';
import 'game_state.dart';
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

  /// Where the recipe book should return to when closed.
  UiRoute? _routeBeforeRecipes;

  final List<GameEvent> _events = [];

  @override
  Player get player => state.player;

  /// Advances the world by [dt] seconds and returns what happened.
  List<GameEvent> tick(double dt, InputFrame input) {
    _events.clear();

    // Furnaces and autosave keep going even while a screen is open.
    _furnaces.update(state, dt);
    if (_autosave?.update(state, dt) ?? false) _events.add(const GameSaved());

    if (state.player.isDead && state.route != UiRoute.dead) {
      state.route = UiRoute.dead;
    }

    // Buttons that were tapped this tick become commands. What each one means
    // depends on where the player is, which is why it is decided in one
    // place rather than in whichever source happened to see the key.
    for (final action in input.pressed) {
      final command = commandFor(action, state.route);
      if (command != null) dispatch(command);
    }

    if (state.route.pausesWorld) return List.of(_events);

    if (input.lookYaw != 0 || input.lookPitch != 0) {
      state.player.look(input.lookYaw, input.lookPitch);
    }
    _movement.update(state, dt, input.moveFor(flying: state.player.flying));
    _events.addAll(_mobAi.update(state, dt, this));
    // Everyone has moved by now, so this is the moment to untangle them.
    _separation.update(state);
    _projectiles.update(state, dt);
    _aiming.update(state);
    _events.addAll(
      _mining.update(state, dt, active: input.isHeld(GameAction.primary)),
    );
    _events.addAll(
      _placement.update(state, dt, active: input.isHeld(GameAction.secondary)),
    );

    return List.of(_events);
  }

  /// Applies a single player action and returns what it caused.
  List<GameEvent> dispatch(GameCommand command) {
    final before = _events.length;
    switch (command) {
      case SelectHotbarSlot(:final index):
        if (index >= 0 && index < state.inventory.hotbarSize) {
          state.selectedSlot = index;
          state.breakProgress = 0;
        }
      case CycleHotbarSlot(:final delta):
        final size = state.inventory.hotbarSize;
        state.selectedSlot = (state.selectedSlot + delta) % size;
        state.breakProgress = 0;
      case ClickSlot(:final ref, :final kind):
        _clickSlot(ref, kind);
      case OpenRoute(:final route):
        _openRoute(route);
      case CloseRoute():
        _closeRoute();
      case OpenRecipes():
        _openRecipes();
      case ToggleFlight():
        state.player.flying = !state.player.flying;
        if (state.player.flying) state.player.velocity.y = 0;
        _events.add(FlightToggled(state.player.flying));
      case Respawn():
        state.player.respawn();
        _mobAi.despawnAll(state);
        _projectiles.clear(state);
        state.route = UiRoute.none;
        _events.add(const PlayerRespawned());
      case UseOrPlace():
        _useOrPlace();
      case SaveGame():
        if (_autosave?.saveNow(state) ?? false) {
          _events.add(const GameSaved());
        }
    }
    return _events.sublist(before);
  }

  void _useOrPlace() {
    if (state.aim case BlockTarget(:final hit)) {
      switch (_blocks.interactionFor(hit.block)) {
        case OpenCraftingTable():
          _openRoute(UiRoute.craftingTable);
        case OpenFurnace():
          state.furnaces.open(hit.pos);
          state.openFurnace = hit.pos;
          _openRoute(UiRoute.furnace);
        case null:
          _events.addAll(_placement.placeNow(state));
      }
    }
  }

  void _openRoute(UiRoute route) {
    state.route = route;
    state.breakProgress = 0;
    _placement.resetCooldown();
  }

  void _openRecipes() {
    if (state.route == UiRoute.recipes) {
      _closeRoute();
      return;
    }
    _routeBeforeRecipes = state.route == UiRoute.none ? null : state.route;
    _openRoute(UiRoute.recipes);
  }

  /// Closing gives back whatever sat in the crafting grid or on the cursor,
  /// so a player cannot lose items by pressing Escape.
  void _closeRoute() {
    if (state.route == UiRoute.recipes) {
      final previous = _routeBeforeRecipes;
      _routeBeforeRecipes = null;
      state.route = previous ?? UiRoute.none;
      return;
    }

    final grid = state.activeGrid;
    for (var i = 0; i < grid.length; i++) {
      final stack = grid[i];
      if (stack == null) continue;
      state.inventory.add(stack.type, stack.count);
      grid[i] = null;
    }
    final held = state.cursor;
    if (held != null) {
      state.inventory.add(held.type, held.count);
      state.cursor = null;
    }
    state.openFurnace = null;
    state.route = UiRoute.none;
  }

  void _clickSlot(SlotRef ref, ClickKind kind) {
    switch (ref) {
      case InventorySlotRef(:final index):
        _swap(
          () => state.inventory[index],
          (value) => state.inventory[index] = value,
          kind,
        );
      case GridSlotRef(:final index):
        final grid = state.activeGrid;
        _swap(() => grid[index], (value) => grid[index] = value, kind);
      case FurnaceSlotRef(:final slot):
        final furnace = state.openFurnace == null
            ? null
            : state.furnaces[state.openFurnace!];
        if (furnace == null) return;
        if (slot == FurnaceSlot.output) {
          final result = takeOutput(furnace.output, state.cursor);
          furnace.output = result.slot;
          state.cursor = result.cursor;
          return;
        }
        _swap(
          () => furnace.slot(slot),
          (value) => furnace.setSlot(slot, value),
          kind,
        );
      case CraftResultRef():
        _takeCraftResult();
    }
  }

  void _swap(
    ItemStack? Function() get,
    void Function(ItemStack?) set,
    ClickKind kind,
  ) {
    final result = kind == ClickKind.primary
        ? transferSlot(get(), state.cursor)
        : splitSlot(get(), state.cursor);
    set(result.slot);
    state.cursor = result.cursor;
  }

  void _takeCraftResult() {
    final grid = state.activeGrid;
    final recipe = matchRecipe(grid);
    if (recipe == null) return;
    if (!cursorAccepts(state.cursor, recipe.output, recipe.outputCount)) return;

    final held = state.cursor;
    state.cursor = held == null
        ? ItemStack(recipe.output, recipe.outputCount)
        : held.plus(recipe.outputCount);
    consumeGrid(grid);
  }

  /// What the crafting grid would produce right now.
  ItemStack? get craftPreview {
    final recipe = matchRecipe(state.activeGrid);
    return recipe == null ? null : ItemStack(recipe.output, recipe.outputCount);
  }

  @override
  void spawnArrow(Vector3 from, Vector3 direction) => state.arrows.add(
    Arrow(world: state.world, spawn: from, direction: direction),
  );

  @override
  void explode(Vector3 at, double radius, int maxDamage) =>
      _events.addAll(_explosions.explode(state, at, radius, maxDamage));
}
