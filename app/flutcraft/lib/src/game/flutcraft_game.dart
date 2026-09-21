import 'dart:ui' as ui;

import 'package:flame/input.dart' show KeyboardEvents;
import 'package:flame_3d/camera.dart';
import 'package:flame_3d/game.dart';
import 'package:flame_3d/graphics.dart';
import 'package:flame_3d/resources.dart';
import 'package:flutcraft/src/game/held_item.dart';
import 'package:flutcraft/src/game/hud_state.dart';
import 'package:flutcraft/src/render/atlas.dart';
import 'package:flutcraft/src/ui/messages/event_messages.dart';
import 'package:flutcraft/src/render/chunk_renderer.dart';
import 'package:flutcraft/src/render/mob_renderer.dart';
import 'package:flutcraft/src/render/overlay_meshes.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show KeyEventResult;

/// Kamera z sensowną bliską/daleką płaszczyzną.
///
/// [CameraComponent3D] ma na sztywno near = 0.01 / far = 1000, co przy
/// świecie z wokseli daje widoczny z-fighting. Nadpisujemy projekcję.
class VoxelCamera extends CameraComponent3D {
  VoxelCamera({required super.world, super.fovY = 70});

  static const double near = 0.06;
  static const double far = 260;

  final Matrix4 _projection = Matrix4.zero();

  @override
  Matrix4 get projectionMatrix => _projection
    ..setAsPerspective(
      fovY,
      viewport.virtualSize.x / viewport.virtualSize.y,
      near,
      far,
    );
}

/// Prototyp Minecrafta: woksele, crafting, piec i potwory.
class FlutcraftGame extends FlameGame3D<World3D, VoxelCamera>
    with KeyboardEvents
    implements MobTickContext {
  factory FlutcraftGame({int seed = 1337}) {
    // Kamera i gra muszą wskazywać na ten sam World3D.
    final world = World3D();
    return FlutcraftGame._(
      seed: seed,
      world: world,
      camera: VoxelCamera(world: world),
    );
  }

  FlutcraftGame._({
    required this.seed,
    required World3D world,
    required VoxelCamera camera,
  }) : super(world: world, camera: camera);

  final int seed;

  /// Które bloki reagują na użycie i w jaki sposób.
  static const BlockRegistry blocks = BlockRegistry.standard;

  static const double reach = 5.5;
  static const double lookSensitivity = 0.0032;

  VoxelWorld get voxels => state.world;
  late final TextureAtlas atlas;
  late final ChunkManager chunkManager;
  @override
  Player get player => state.player;
  late final SelectionBox selection;
  late final HeldItem heldItem;
  late final ItemMeshes itemMeshes;
  late final MobModels mobModels;
  late final MobSpawner spawner;

  /// Atlas jako `ui.Image` - HUD rysuje z niego ikonki przedmiotów.
  ui.Image? atlasImage;

  final ValueNotifier<HudSnapshot?> hud = ValueNotifier(null);

  // --- ekwipunek i crafting -------------------------------------------------

  /// Cały stan symulacji. Klasa gry nim steruje, ale go nie posiada -
  /// systemy domenowe operują na tym samym obiekcie.
  late final GameState state;

  Inventory get inventory => state.inventory;
  CraftingGrid get smallGrid => state.smallGrid;
  CraftingGrid get bigGrid => state.bigGrid;
  FurnaceRegistry get furnaces => state.furnaces;

  ItemStack? get cursor => state.cursor;
  set cursor(ItemStack? value) => state.cursor = value;

  UiRoute get screen => state.route;
  set screen(UiRoute value) => state.route = value;

  /// Ekran, do którego wraca księga przepisów po zamknięciu.
  UiRoute? _screenBeforeRecipes;

  BlockPos? get openFurnaceKey => state.openFurnace;
  set openFurnaceKey(BlockPos? value) => state.openFurnace = value;

  int get selected => state.selectedSlot;
  set selected(int value) => state.selectedSlot = value;

  int revision = 0;

  CraftingGrid get activeGrid => state.activeGrid;

  FurnaceState? get openFurnace {
    final pos = openFurnaceKey;
    return pos == null ? null : furnaces[pos];
  }

  ItemType? get heldItemType => state.heldItem;

  // --- potwory --------------------------------------------------------------

  List<Mob> get mobs => state.mobs;
  List<Arrow> get arrows => state.arrows;
  final Map<Mob, MobComponent> _mobComponents = {};
  final Map<Arrow, ArrowComponent> _arrowComponents = {};

  // --- wejście --------------------------------------------------------------

  final Set<LogicalKeyboardKey> _keys = {};
  final Vector2 _touchMove = Vector2.zero();
  bool _touchJump = false;
  /// Czy gracz trzyma przycisk kopania/ataku.
  bool _isMining = false;

  /// Kopanie i walka wręcz - cała logika czasu i obrażeń w domenie.
  late final MiningSystem _mining = MiningSystem(random: spawner.rng);

  /// Stawianie bloków wraz z regułami, gdzie wolno.
  final PlacementSystem _placement = PlacementSystem();

  /// Wybuchy: destrukcja terenu i obrażenia obszarowe.
  final ExplosionSystem _explosions = const ExplosionSystem();
  bool _placing = false;

  // --- stan gry -------------------------------------------------------------

  AimResult get _aim => state.aim;
  set _aim(AimResult value) => state.aim = value;
  double get _breakProgress => state.breakProgress;
  set _breakProgress(double value) => state.breakProgress = value;
  double _swingTimer = 0;
  double _hudTimer = 0;
  double _fps = 0;
  String _message = '';
  double _messageTimer = 0;

  static const double _swingDuration = 0.28;

  @override
  ui.Color backgroundColor() => const ui.Color(0xFF88BBEE);

  @override
  Future<void> onLoad() async {
    atlas = TextureAtlas.generate();
    atlasImage = await atlas.toImage();

    final voxelWorld = VoxelWorld();
    TerrainGenerator(seed: seed).generate(voxelWorld);
    voxelWorld.markAllDirty();

    final spawnedPlayer = Player(world: voxelWorld, spawn: Vector3.zero())
      ..respawn()
      ..pitch = -0.25;
    state = GameState(
      world: voxelWorld,
      player: spawnedPlayer,
      inventory: Inventory(),
    );

    final terrainMaterial = UnlitMaterial(albedoTexture: atlas.texture)
      ..cullMode = CullMode.backFace;

    chunkManager = ChunkManager(
      world: voxels,
      atlas: atlas,
      material: terrainMaterial,
    );

    chunkManager.focus.setFrom(player.position);

    final chunkComponents = chunkManager.createComponents();
    // Okolica spawnu musi być gotowa zanim gracz zobaczy pierwszą klatkę.
    chunkManager.prebuild(20);

    itemMeshes = ItemMeshes(atlas);
    mobModels = MobModels(atlas);
    spawner = MobSpawner(world: voxels, seed: seed);
    selection = SelectionBox.create(atlas)..visible = false;
    heldItem = HeldItem();

    _giveStartingItems();

    await add(chunkManager);
    await world.addAll(chunkComponents);
    await world.add(selection);
    await world.add(heldItem);

    _publishHud();
  }

  /// Startowy zestaw: kilka bloków na rozruch, resztę trzeba wykopać.
  void _giveStartingItems() {
    inventory.add(ItemType.log, 8);
    inventory.add(ItemType.planks, 8);
    inventory.add(ItemType.cobblestone, 16);
    _syncHeldMesh();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (dt > 0) {
      final instant = 1 / dt;
      _fps = _fps == 0 ? instant : _fps * 0.9 + instant * 0.1;
    }

    _tickFurnaces(dt);

    if (screen.pausesWorld) {
      // Świat zamarza, gdy gracz grzebie w ekwipunku.
      _isMining = false;
      _placing = false;
      _updateHud(dt);
      return;
    }

    final input = _collectInput();
    _applyKeyboardLook(dt);
    player.update(dt, input);
    chunkManager.focus.setFrom(player.position);

    if (player.isDead) {
      _openScreen(UiRoute.dead);
      _updateHud(dt);
      return;
    }

    _updateMobs(dt);
    _updateArrows(dt);
    _updateCamera();
    _updateAim();
    _updateMining(dt);
    _updatePlacing(dt);
    _updateHeldItem(dt);
    _updateHud(dt);
  }

  void _updateHud(double dt) {
    if (_messageTimer > 0) {
      _messageTimer -= dt;
      if (_messageTimer <= 0) _message = '';
    }
    _hudTimer += dt;
    if (_hudTimer >= 0.05) {
      _hudTimer = 0;
      _publishHud();
    }
  }

  // --- pętla gry ------------------------------------------------------------

  MoveInput _collectInput() {
    var forward = _touchMove.y;
    var strafe = _touchMove.x;

    if (_down(LogicalKeyboardKey.keyW)) forward += 1;
    if (_down(LogicalKeyboardKey.keyS)) forward -= 1;
    if (_down(LogicalKeyboardKey.keyD)) strafe += 1;
    if (_down(LogicalKeyboardKey.keyA)) strafe -= 1;

    return MoveInput(
      forward: forward.clamp(-1, 1),
      strafe: strafe.clamp(-1, 1),
      jump: _touchJump || _down(LogicalKeyboardKey.space),
      crouch: _down(LogicalKeyboardKey.shiftLeft) && player.flying,
      sprint: _down(LogicalKeyboardKey.shiftLeft) && !player.flying,
    );
  }

  void _applyKeyboardLook(double dt) {
    const speed = 1.8;
    var dyaw = 0.0;
    var dpitch = 0.0;
    if (_down(LogicalKeyboardKey.arrowLeft)) dyaw += speed * dt;
    if (_down(LogicalKeyboardKey.arrowRight)) dyaw -= speed * dt;
    if (_down(LogicalKeyboardKey.arrowUp)) dpitch += speed * dt;
    if (_down(LogicalKeyboardKey.arrowDown)) dpitch -= speed * dt;
    if (dyaw != 0 || dpitch != 0) player.look(dyaw, dpitch);
  }

  void _updateCamera() {
    final eye = player.eye;
    final dir = player.lookDirection;
    camera.position.setFrom(eye);
    camera.target.setValues(eye.x + dir.x, eye.y + dir.y, eye.z + dir.z);
  }

  // --- potwory --------------------------------------------------------------

  void _updateMobs(double dt) {
    final spawned = spawner.maybeSpawn(dt, player, mobs.length);
    if (spawned != null) _addMob(spawned);

    for (final mob in List<Mob>.from(mobs)) {
      mob.update(dt, player, this);
      if (mob.isDead) {
        _killMob(mob);
      } else {
        _mobComponents[mob]?.sync();
      }
    }
  }

  void _addMob(Mob mob) {
    mobs.add(mob);
    final component = MobComponent(
      mob: mob,
      model: mobModels.forKind(mob.kind),
    )..sync();
    _mobComponents[mob] = component;
    world.add(component);
  }

  void _killMob(Mob mob) {
    mobs.remove(mob);
    _mobComponents.remove(mob)?.removeFromParent();

    final drops = mob.kind.loot.roll(spawner.rng);
    for (final drop in drops) {
      inventory.add(drop.type, drop.count);
    }

    _emit(MobKilled(mob.kind, drops));
    revision++;
  }

  void _updateArrows(double dt) {
    for (final arrow in List<Arrow>.from(arrows)) {
      arrow.update(dt, player);
      if (arrow.removed) {
        arrows.remove(arrow);
        _arrowComponents.remove(arrow)?.removeFromParent();
      } else {
        _arrowComponents[arrow]?.sync();
      }
    }
  }

  @override
  void spawnArrow(Vector3 from, Vector3 direction) {
    final arrow = Arrow(world: voxels, spawn: from, direction: direction);
    arrows.add(arrow);
    final component = ArrowComponent(arrow: arrow, mesh: mobModels.arrow)
      ..sync();
    _arrowComponents[arrow] = component;
    world.add(component);
  }

  @override
  void explode(Vector3 at, double radius, int maxDamage) {
    for (final event in _explosions.explode(state, at, radius, maxDamage)) {
      _emit(event);
    }
  }

  // --- celowanie ------------------------------------------------------------

  void _updateAim() {
    final previous = _aim;
    _aim = pickTarget(
      world: voxels,
      mobs: mobs,
      eye: player.eye,
      direction: player.lookDirection,
      reach: reach,
    );

    switch (_aim) {
      case NoTarget() || MobTarget():
        _breakProgress = 0;
        selection.visible = false;
      case BlockTarget(:final hit):
        // Zmiana celowanego bloku kasuje postęp kopania.
        if (previous is! BlockTarget || !previous.hit.samePosition(hit)) {
          _breakProgress = 0;
        }
        selection
          ..visible = true
          ..target(hit.x, hit.y, hit.z);
    }
  }

  // --- kopanie i walka ------------------------------------------------------

  void _updateMining(double dt) {
    for (final event in _mining.update(state, dt, active: _isMining)) {
      _emit(event);
      if (event is BlockBroken) {
        selection.visible = false;
        revision++;
      }
    }
    if (_isMining && _aim is MobTarget) _swingTimer = _swingDuration;
  }

  // --- stawianie i interakcja -----------------------------------------------

  void _updatePlacing(double dt) {
    _applyPlacement(_placement.update(state, dt, active: _placing));
  }

  /// Prawy przycisk: otwiera stół/piec albo stawia blok.
  void interactOrPlace() {
    if (_aim case BlockTarget(:final hit)) {
      if (blocks.isInteractive(hit.block)) {
        _openBlock(hit);
      } else {
        placeBlock();
      }
    }
  }

  void placeBlock() => _applyPlacement(_placement.placeNow(state));

  void _applyPlacement(List<GameEvent> events) {
    for (final event in events) {
      _emit(event);
    }
    if (events.isEmpty && _aim is BlockTarget) {
      _swingTimer = _swingDuration;
      _syncHeldMesh();
      revision++;
      _publishHud();
    }
  }

  void _openBlock(RayHit hit) {
    switch (blocks.interactionFor(hit.block)) {
      case null:
        return;
      case OpenCraftingTable():
        _openScreen(UiRoute.craftingTable);
      case OpenFurnace():
        final pos = hit.pos;
        furnaces.open(pos);
        openFurnaceKey = pos;
        _openScreen(UiRoute.furnace);
    }
  }

  // --- piec -----------------------------------------------------------------

  void _tickFurnaces(double dt) {
    if (furnaces.isEmpty) return;
    for (final pos in furnaces.tick(dt)) {
      _applyFurnaceBlock(pos, furnaces[pos]!.isLit);
    }
  }

  /// Podmienia blok pieca na wariant z płomieniem (lub z powrotem).
  void _applyFurnaceBlock(BlockPos pos, bool lit) {
    final current = voxels.blockAt(pos.x, pos.y, pos.z);
    if (!current.hasLitVariant) return;
    final wanted =
        (lit ? current.litVariant : current.unlitVariant) ?? current;
    if (current != wanted) voxels.setBlock(pos.x, pos.y, pos.z, wanted);
  }

  // --- przedmiot w ręce -----------------------------------------------------

  void _updateHeldItem(double dt) {
    final swingingAtBlock = _isMining && _aim is BlockTarget;
    if (_swingTimer > 0) {
      _swingTimer -= dt;
      if (_swingTimer <= 0) {
        _swingTimer = swingingAtBlock ? _swingDuration : 0;
      }
    } else if (swingingAtBlock) {
      _swingTimer = _swingDuration;
    }

    heldItem
      ..swing = _swingTimer <= 0 ? 0 : 1 - (_swingTimer / _swingDuration)
      ..follow(player.eye, player.lookDirection)
      ..markAabbDirty();
  }

  void _syncHeldMesh() {
    heldItem.mesh = itemMeshes.forItem(inventory[selected]?.type);
  }

  // --- API dla warstwy UI ---------------------------------------------------

  void look(double dxPixels, double dyPixels) {
    if (screen.pausesWorld) return;
    player.look(-dxPixels * lookSensitivity, -dyPixels * lookSensitivity);
  }

  void setMoveAxis(double strafe, double forward) {
    _touchMove.setValues(strafe, forward);
  }

  void setJump(bool value) => _touchJump = value;

  void setMining(bool value) {
    _isMining = value && !screen.pausesWorld;
    if (!_isMining) _breakProgress = 0;
  }

  void setPlacing(bool value) {
    _placing = value && !screen.pausesWorld;
    if (_placing) _placement.resetCooldown();
  }

  void selectSlot(int index) {
    if (index < 0 || index >= inventory.hotbarSize || index == selected) return;
    selected = index;
    _breakProgress = 0;
    _syncHeldMesh();
    _publishHud();
  }

  void cycleSlot(int delta) {
    selectSlot((selected + delta) % inventory.hotbarSize);
  }

  void toggleFly() {
    player.flying = !player.flying;
    if (player.flying) player.velocity.y = 0;
    _emit(FlightToggled(player.flying));
  }

  /// Otwiera księgę przepisów, zapamiętując, skąd ją wywołano.
  ///
  /// Dzięki temu zerknięcie na przepis w trakcie układania na stole nie
  /// rozsypuje tego, co gracz już położył na siatce.
  void openRecipes() {
    if (screen == UiRoute.recipes) {
      closeScreen();
      return;
    }
    _screenBeforeRecipes = screen == UiRoute.none ? null : screen;
    _openScreen(UiRoute.recipes);
  }

  void toggleInventory() {
    if (screen == UiRoute.none) {
      _openScreen(UiRoute.inventory);
    } else if (screen != UiRoute.dead) {
      closeScreen();
    }
  }

  void _openScreen(UiRoute value) {
    screen = value;
    _isMining = false;
    _placing = false;
    _touchMove.setZero();
    _publishHud();
  }

  /// Zamyka ekran, oddając graczowi to, co zostało w siatce i na kursorze.
  void closeScreen() {
    // Z księgi wracamy tam, skąd ją otwarto - siatka zostaje nietknięta.
    if (screen == UiRoute.recipes) {
      final previous = _screenBeforeRecipes;
      _screenBeforeRecipes = null;
      screen = previous ?? UiRoute.none;
      _publishHud();
      return;
    }

    final grid = activeGrid;
    for (var i = 0; i < grid.slots.length; i++) {
      final stack = grid[i];
      if (stack == null) continue;
      inventory.add(stack.type, stack.count);
      grid[i] = null;
    }
    final held = cursor;
    if (held != null) {
      inventory.add(held.type, held.count);
      cursor = null;
    }
    openFurnaceKey = null;
    screen = UiRoute.none;
    _syncHeldMesh();
    revision++;
    _publishHud();
  }

  void respawn() {
    player.respawn();
    for (final mob in List<Mob>.from(mobs)) {
      mobs.remove(mob);
      _mobComponents.remove(mob)?.removeFromParent();
    }
    for (final arrow in List<Arrow>.from(arrows)) {
      arrows.remove(arrow);
      _arrowComponents.remove(arrow)?.removeFromParent();
    }
    screen = UiRoute.none;
    _emit(const PlayerRespawned());
    _publishHud();
  }

  // --- przekładanie przedmiotów w UI ----------------------------------------

  /// Kliknięcie w slot: podnosi, odkłada albo scala stosy.
  void clickSlot(ItemStack? Function() get, void Function(ItemStack?) set) {
    final result = transferSlot(get(), cursor);
    set(result.slot);
    cursor = result.cursor;

    _syncHeldMesh();
    revision++;
    _publishHud();
  }

  /// Kliknięcie pomocnicze: dzieli stos albo dokłada po jednej sztuce.
  void splitSlotAt(
    ItemStack? Function() get,
    void Function(ItemStack?) set,
  ) {
    final result = splitSlot(get(), cursor);
    set(result.slot);
    cursor = result.cursor;

    _syncHeldMesh();
    revision++;
    _publishHud();
  }

  void clickInventorySlot(int index) =>
      clickSlot(() => inventory[index], (s) => inventory[index] = s);

  void splitInventorySlot(int index) =>
      splitSlotAt(() => inventory[index], (s) => inventory[index] = s);

  void clickGridSlot(int index) {
    final grid = activeGrid;
    clickSlot(() => grid[index], (s) => grid[index] = s);
  }

  void splitGridSlot(int index) {
    final grid = activeGrid;
    splitSlotAt(() => grid[index], (s) => grid[index] = s);
  }

  /// Slot wyniku craftingu: wyjmuje gotowy przedmiot i zużywa składniki.
  void takeCraftResult() {
    final grid = activeGrid;
    final recipe = matchRecipe(grid);
    if (recipe == null) return;
    if (!cursorAccepts(cursor, recipe.output, recipe.outputCount)) return;

    final held = cursor;
    cursor = held == null
        ? ItemStack(recipe.output, recipe.outputCount)
        : held.plus(recipe.outputCount);

    consumeGrid(grid);
    revision++;
    _publishHud();
  }

  ItemStack? get craftPreview {
    final recipe = matchRecipe(activeGrid);
    return recipe == null
        ? null
        : ItemStack(recipe.output, recipe.outputCount);
  }

  void clickFurnaceSlot(int index, {bool split = false}) {
    final state = openFurnace;
    if (state == null) return;

    switch (index) {
      case 0:
        if (split) {
          splitSlotAt(() => state.input, (s) => state.input = s);
        } else {
          clickSlot(() => state.input, (s) => state.input = s);
        }
      case 1:
        if (split) {
          splitSlotAt(() => state.fuel, (s) => state.fuel = s);
        } else {
          clickSlot(() => state.fuel, (s) => state.fuel = s);
        }
      default:
        // Ze slotu wyniku można tylko zabierać.
        final result = takeOutput(state.output, cursor);
        state.output = result.slot;
        cursor = result.cursor;
        revision++;
        _publishHud();
    }
  }

  // --- klawiatura -----------------------------------------------------------

  bool _down(LogicalKeyboardKey key) => _keys.contains(key);

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    _keys
      ..clear()
      ..addAll(keysPressed);

    if (event is KeyDownEvent) {
      const digits = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
        LogicalKeyboardKey.digit6,
        LogicalKeyboardKey.digit7,
        LogicalKeyboardKey.digit8,
        LogicalKeyboardKey.digit9,
      ];
      final digit = digits.indexOf(event.logicalKey);
      if (digit >= 0 && !screen.pausesWorld) {
        selectSlot(digit);
        return KeyEventResult.handled;
      }

      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyE:
          if (screen != UiRoute.dead) toggleInventory();
        case LogicalKeyboardKey.escape:
          if (screen != UiRoute.none && screen != UiRoute.dead) {
            closeScreen();
          }
        case LogicalKeyboardKey.keyB:
          if (screen != UiRoute.dead) openRecipes();
        case LogicalKeyboardKey.keyF:
          if (!screen.pausesWorld) toggleFly();
        case LogicalKeyboardKey.keyR:
          if (screen == UiRoute.dead) {
            respawn();
          } else if (!screen.pausesWorld) {
            interactOrPlace();
          }
      }
    }
    return KeyEventResult.handled;
  }

  // --- HUD ------------------------------------------------------------------

  /// Zgłasza zdarzenie graczowi. Silnik nie zna tekstu - tłumaczy go
  /// [describeEvent] w warstwie prezentacji.
  void _emit(GameEvent event) {
    final text = describeEvent(event);
    if (text.isEmpty) return;
    _message = text;
    _messageTimer = 2.4;
    _publishHud();
  }

  void _publishHud() {
    final mob = switch (_aim) { MobTarget(:final mob) => mob, _ => null };
    hud.value = HudSnapshot(
      targetMob: mob == null
          ? null
          : TargetMob(
              label: mob.kind.label,
              health: mob.health,
              maxHealth: mob.kind.maxHealth,
            ),
      hotbar: inventory.hotbar.toList(),
      selected: selected,
      breakProgress: _breakProgress.clamp(0, 1),
      targetLabel: switch (_aim) {
        NoTarget() => '',
        BlockTarget(:final hit) => hit.block.label,
        MobTarget(:final mob) => mob.kind.label,
      },
      position: (
        player.position.x.floor(),
        player.position.y.floor(),
        player.position.z.floor(),
      ),
      fps: _fps,
      flying: player.flying,
      chunksPending: chunkManager.pendingChunks,
      chunksTotal: chunkManager.totalChunks,
      message: _message,
      health: player.health,
      maxHealth: Player.maxHealth,
      hurtFlash: player.hurtFlash,
      mobCount: mobs.length,
      screen: screen,
      revision: revision,
    );
  }
}
