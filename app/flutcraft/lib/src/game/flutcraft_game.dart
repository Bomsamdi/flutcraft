import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/input.dart' show KeyboardEvents;
import 'package:flame_3d/camera.dart';
import 'package:flame_3d/game.dart';
import 'package:flame_3d/graphics.dart';
import 'package:flame_3d/resources.dart';
import 'package:flutcraft/src/game/held_item.dart';
import 'package:flutcraft/src/input/keyboard_input_source.dart';
import 'package:flutcraft/src/render/atlas.dart';
import 'package:flutcraft/src/render/chunk_renderer.dart';
import 'package:flutcraft/src/render/mob_renderer.dart';
import 'package:flutcraft/src/render/overlay_meshes.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show KeyEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show KeyEventResult;

/// A camera with sensible near and far planes.
///
/// [CameraComponent3D] ma na sztywno near = 0.01 / far = 1000, co przy
/// a voxel world that means visible z-fighting, so the projection is
/// overridden here.
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
  factory FlutcraftGame({
    required LoopGameSession session,
    required InputRouter input,
    required TextureAtlas atlas,
  }) {
    // The camera and the game must point at the same World3D.
    final world = World3D();
    return FlutcraftGame._(
      session: session,
      input: input,
      atlas: atlas,
      world: world,
      camera: VoxelCamera(world: world),
    );
  }

  FlutcraftGame._({
    required this.session,
    required this.input,
    required this.atlas,
    required World3D world,
    required VoxelCamera camera,
  }) : super(world: world, camera: camera);

  /// Symulacja zbudowana przez composition root. Silnik jej nie tworzy -
  /// only drives and draws it.
  final LoopGameSession session;

  /// Which blocks react to being used, and how.
  static const BlockRegistry blocks = BlockRegistry.standard;

  static const double lookSensitivity = 0.0032;

  VoxelWorld get voxels => state.world;

  /// Built by the composition root; the engine only uses it.
  final TextureAtlas atlas;
  late final ChunkManager chunkManager;
  Player get player => state.player;
  late final SelectionBox selection;
  late final HeldItem heldItem;
  late final ItemMeshes itemMeshes;
  late final MobModels mobModels;

  /// What the renderer reports about itself: frame rate and chunk progress.
  final ValueNotifier<FrameStats> frameStats = ValueNotifier(
    const FrameStats(),
  );

  // --- inventory and crafting -------------------------------------------------

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

  // --- mobs --------------------------------------------------------------

  List<Mob> get mobs => state.mobs;
  List<Arrow> get arrows => state.arrows;
  final Map<Mob, MobComponent> _mobComponents = {};
  final Map<Arrow, ArrowComponent> _arrowComponents = {};

  // --- input ----------------------------------------------------------------

  /// Every input source meets here; the game only reads the finished frame.
  /// The router belongs to the app, because touch and keyboard live outside
  /// the engine.
  final InputRouter input;

  late final KeyboardInputSource _keyboard = KeyboardInputSource(router: input);

  GameLoop get loop => session.loop;

  GameState get state => loop.state;

  // --- game state -------------------------------------------------------------

  /// Co jest pod celownikiem. Ustawia to AimingSystem - gra tylko czyta.
  AimResult get _aim => state.aim;
  double _swingTimer = 0;
  double _fps = 0;

  static const double _swingDuration = 0.28;

  @override
  ui.Color backgroundColor() => const ui.Color(0xFF88BBEE);

  @override
  Future<void> onLoad() async {
    final terrainMaterial = UnlitMaterial(albedoTexture: atlas.texture)
      ..cullMode = CullMode.backFace;

    chunkManager = ChunkManager(
      world: voxels,
      atlas: atlas,
      material: terrainMaterial,
    );

    chunkManager.focus.setFrom(player.position);

    final chunkComponents = chunkManager.createComponents();
    // The area around the spawn has to be ready before the first frame.
    chunkManager.prebuild(20);

    itemMeshes = ItemMeshes(atlas);
    mobModels = MobModels(atlas);
    selection = SelectionBox.create(atlas)..visible = false;
    // The composition root hands out the starting items, so the held mesh
    // has to be set now rather than at the first command.
    heldItem = HeldItem();
    _syncHeldMesh();

    await add(chunkManager);
    await world.addAll(chunkComponents);
    await world.add(selection);
    await world.add(heldItem);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (dt > 0) {
      final instant = 1 / dt;
      _fps = _fps == 0 ? instant : _fps * 0.9 + instant * 0.1;
    }

    session.tick(dt, input.build(dt));

    chunkManager.focus.setFrom(player.position);
    _updateCamera();
    _updateSelection();
    _syncMobComponents();
    _syncArrowComponents();
    _syncHeldMesh();
    _updateHeldItem(dt);
    _publishFrameStats();
  }

  /// The selection box follows whatever the aiming system picked.
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

  // --- camera ---------------------------------------------------------------

  void _updateCamera() {
    final eye = player.eye;
    final dir = player.lookDirection;
    camera.position.setFrom(eye);
    camera.target.setValues(eye.x + dir.x, eye.y + dir.y, eye.z + dir.z);
  }

  // --- mobs --------------------------------------------------------------

  /// Adds components for new mobs, removes them for mobs that are gone and
  /// syncs the rest. One place instead of four.
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

  // --- held item ------------------------------------------------------------

  void _updateHeldItem(double dt) {
    final swingingAtBlock =
        input.isHeld(GameAction.primary) && _aim is BlockTarget;
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

  /// The mesh in hand follows the selected slot. Checked every frame,
  /// because refreshing it only on a command missed changes from anywhere
  /// else — the starting items used to stay invisible.
  ItemType? _heldMeshItem;

  void _syncHeldMesh() {
    final item = state.heldItem;
    if (item == _heldMeshItem) return;
    _heldMeshItem = item;
    heldItem.mesh = itemMeshes.forItem(item);
  }

  // --- keyboard -----------------------------------------------------------

  /// Keys become actions and go to the router. What an action means on a
  /// given screen is the domain's decision — there is not a single
  /// `if` about the inventory left here.
  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    _keyboard.onKeysChanged(keysPressed);
    return KeyEventResult.handled;
  }

  // --- telemetry ---------------------------------------------------------

  void _publishFrameStats() => frameStats.value = FrameStats(
    fps: _fps,
    chunksReady: chunkManager.totalChunks - chunkManager.pendingChunks,
    chunksTotal: chunkManager.totalChunks,
  );
}
