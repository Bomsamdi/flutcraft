import 'dart:async';
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
    with KeyboardEvents {
  factory FlutcraftGame({required LoopGameSession session}) {
    // Kamera i gra muszą wskazywać na ten sam World3D.
    final world = World3D();
    return FlutcraftGame._(
      session: session,
      world: world,
      camera: VoxelCamera(world: world),
    );
  }

  FlutcraftGame._({
    required this.session,
    required World3D world,
    required VoxelCamera camera,
  }) : super(world: world, camera: camera);

  /// Symulacja zbudowana przez composition root. Silnik jej nie tworzy -
  /// tylko ją napędza i rysuje.
  final LoopGameSession session;

  /// Które bloki reagują na użycie i w jaki sposób.
  static const BlockRegistry blocks = BlockRegistry.standard;

  static const double lookSensitivity = 0.0032;

  VoxelWorld get voxels => state.world;
  late final TextureAtlas atlas;
  late final ChunkManager chunkManager;
  Player get player => state.player;
  late final SelectionBox selection;
  late final HeldItem heldItem;
  late final ItemMeshes itemMeshes;
  late final MobModels mobModels;

  /// Atlas jako `ui.Image` - HUD rysuje z niego ikonki przedmiotów.
  ui.Image? atlasImage;

  final ValueNotifier<HudSnapshot?> hud = ValueNotifier(null);

  // --- ekwipunek i crafting -------------------------------------------------

  Inventory get inventory => state.inventory;
  CraftingGrid get smallGrid => state.smallGrid;
  CraftingGrid get bigGrid => state.bigGrid;
  FurnaceRegistry get furnaces => state.furnaces;

  ItemStack? get cursor => state.cursor;
  set cursor(ItemStack? value) => state.cursor = value;

  UiRoute get screen => state.route;
  set screen(UiRoute value) => state.route = value;


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

  GameLoop get loop => session.loop;

  GameState get state => loop.state;
  bool _placing = false;

  // --- stan gry -------------------------------------------------------------

  /// Co jest pod celownikiem. Ustawia to AimingSystem - gra tylko czyta.
  AimResult get _aim => state.aim;
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
    selection = SelectionBox.create(atlas)..visible = false;
    heldItem = HeldItem();


    await add(chunkManager);
    await world.addAll(chunkComponents);
    await world.add(selection);
    await world.add(heldItem);

    _messages = session.events.listen(_emit);
    _publishHud();
  }

  StreamSubscription<GameEvent>? _messages;

  @override
  void onRemove() {
    _messages?.cancel();
    super.onRemove();
  }


  @override
  void update(double dt) {
    super.update(dt);
    if (dt > 0) {
      final instant = 1 / dt;
      _fps = _fps == 0 ? instant : _fps * 0.9 + instant * 0.1;
    }

    _applyKeyboardLook(dt);
    session.tick(dt, _inputFrame());

    chunkManager.focus.setFrom(player.position);
    _updateCamera();
    _updateSelection();
    _syncMobComponents();
    _syncArrowComponents();
    _updateHeldItem(dt);
    _updateHud(dt);
  }

  InputFrame _inputFrame() => InputFrame(
    move: _collectInput(),
    mining: _isMining,
    using: _placing,
  );


  /// Ramka zaznaczenia podąża za tym, co wybrał AimingSystem.
  void _updateSelection() {
    switch (_aim) {
      case BlockTarget(:final hit):
        selection
          ..visible = true
          ..target(hit.x, hit.y, hit.z);
      case NoTarget() || MobTarget():
        selection.visible = false;
    }
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



  /// Dokłada komponenty dla nowych potworów, usuwa dla tych, których już nie
  /// ma, i synchronizuje resztę. Jedno miejsce zamiast czterech.
  void _syncMobComponents() {
    for (final mob in mobs) {
      final component = _mobComponents.putIfAbsent(mob, () {
        final created = MobComponent(
          mob: mob,
          model: mobModels.forKind(mob.kind),
        );
        world.add(created);
        return created;
      });
      component.sync();
    }
    _mobComponents.keys.toList().where((m) => !mobs.contains(m)).forEach((m) {
      _mobComponents.remove(m)?.removeFromParent();
    });
  }

  void _syncArrowComponents() {
    for (final arrow in arrows) {
      final component = _arrowComponents.putIfAbsent(arrow, () {
        final created = ArrowComponent(arrow: arrow, mesh: mobModels.arrow);
        world.add(created);
        return created;
      });
      component.sync();
    }
    _arrowComponents.keys
        .toList()
        .where((a) => !arrows.contains(a))
        .forEach((a) => _arrowComponents.remove(a)?.removeFromParent());
  }



  // --- celowanie ------------------------------------------------------------


  // --- kopanie i walka ------------------------------------------------------


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
  //
  // Każda akcja gracza to komenda. Silnik nie zawiera już logiki tych
  // operacji - tylko przekazuje je do symulacji i odświeża widok.

  void _run(GameCommand command) {
    session.dispatch(command);
    _syncHeldMesh();
    revision++;
    _publishHud();
  }

  void look(double dxPixels, double dyPixels) {
    if (screen.pausesWorld) return;
    player.look(-dxPixels * lookSensitivity, -dyPixels * lookSensitivity);
  }

  void setMoveAxis(double strafe, double forward) =>
      _touchMove.setValues(strafe, forward);

  void setJump(bool value) => _touchJump = value;

  void setMining(bool value) {
    _isMining = value && !screen.pausesWorld;
    if (!_isMining) _breakProgress = 0;
  }

  void setPlacing(bool value) => _placing = value && !screen.pausesWorld;

  void selectSlot(int index) => _run(SelectHotbarSlot(index));

  void cycleSlot(int delta) => _run(CycleHotbarSlot(delta));

  void toggleFly() => _run(const ToggleFlight());

  void respawn() => _run(const Respawn());

  void closeScreen() => _run(const CloseRoute());

  void openRecipes() => _run(const OpenRecipes());

  void interactOrPlace() => _run(const UseOrPlace());

  void placeBlock() => _run(const UseOrPlace());

  void toggleInventory() => _run(
    screen == UiRoute.none
        ? const OpenRoute(UiRoute.inventory)
        : const CloseRoute(),
  );

  void clickInventorySlot(int index) =>
      _run(ClickSlot(InventorySlotRef(index)));

  void splitInventorySlot(int index) =>
      _run(ClickSlot(InventorySlotRef(index), kind: ClickKind.split));

  void clickGridSlot(int index) => _run(ClickSlot(GridSlotRef(index)));

  void splitGridSlot(int index) =>
      _run(ClickSlot(GridSlotRef(index), kind: ClickKind.split));

  void takeCraftResult() => _run(const ClickSlot(CraftResultRef()));

  void clickFurnaceSlot(int index, {bool split = false}) => _run(
    ClickSlot(
      FurnaceSlotRef(FurnaceSlot.values[index]),
      kind: split ? ClickKind.split : ClickKind.primary,
    ),
  );

  ItemStack? get craftPreview => loop.craftPreview;

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
          : MobAimView(mob.kind, mob.health, mob.kind.maxHealth),
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
