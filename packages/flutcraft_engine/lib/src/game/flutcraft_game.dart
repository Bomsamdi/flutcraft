import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame_3d/camera.dart';
import 'package:flame_3d/game.dart';
import 'package:flame_3d/graphics.dart';
import 'package:flame_3d/resources.dart';
import 'package:flutcraft_engine/src/game/held_item.dart';
import 'package:flutcraft_engine/src/game/voxel_camera.dart';
import 'package:flutcraft_engine/src/render/atlas_texture.dart';
import 'package:flutcraft_engine/src/render/chunk_renderer.dart';
import 'package:flutcraft_engine/src/render/mob_renderer.dart';
import 'package:flutcraft_engine/src/render/overlay_meshes.dart';
import 'package:flutcraft_engine/src/systems/entity_sync.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutter/foundation.dart';

/// The game itself: voxels, crafting, furnaces and mobs.
class FlutcraftGame extends FlameGame3D<World3D, VoxelCamera> {
  factory FlutcraftGame({
    required SimulatedSession session,
    required InputRouter input,
    required EngineAtlas atlas,
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

  /// The simulation, assembled by the composition root. The engine does not
  /// create it — it only drives it and draws it.
  ///
  /// An interface, not the single-player class: a networked session keeps a
  /// local world in step with a server and satisfies exactly the same three
  /// members, so nothing here has to know which one it got.
  final SimulatedSession session;

  /// Built by the composition root; the engine only uses it.
  final EngineAtlas atlas;
  late final ChunkManager chunkManager;
  late final SelectionBox selection;
  late final HeldItem heldItem;
  late final ItemMeshes itemMeshes;
  late final MobModels mobModels;

  /// Mobs and arrows exist in the simulation; these keep a component per
  /// entity in step with them.
  late final EntitySync<Mob, MobComponent> _mobs;
  late final EntitySync<Arrow, ArrowComponent> _arrows;

  /// The player this client is looking through.
  ///
  /// `state.solo` used to stand here, and it is `participants.values.single`:
  /// the renderer would have thrown the instant a second player joined.
  Participant get viewer => session.viewer;

  Player get player => viewer.player;

  /// What the renderer reports about itself: frame rate and chunk progress.
  final ValueNotifier<FrameStats> frameStats = ValueNotifier(
    const FrameStats(),
  );

  // --- input ----------------------------------------------------------------

  /// Every input source meets here; the game only reads the finished frame.
  /// The router belongs to the app, because touch and keyboard live outside
  /// the engine.
  final InputRouter input;

  GameState get state => session.state;

  double _fps = 0;

  @override
  ui.Color backgroundColor() => const ui.Color(0xFF88BBEE);

  @override
  Future<void> onLoad() async {
    final terrainMaterial = UnlitMaterial(albedoTexture: atlas.texture)
      ..cullMode = CullMode.backFace;

    chunkManager = ChunkManager(
      world: state.world,
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
    heldItem = HeldItem();

    _mobs = EntitySync(
      world: world,
      source: () => state.mobs,
      build: (mob) =>
          MobComponent(mob: mob, model: mobModels.forKind(mob.kind)),
      sync: (component, _) => component.sync(),
    );
    _arrows = EntitySync(
      world: world,
      source: () => state.arrows,
      build: (arrow) => ArrowComponent(arrow: arrow, mesh: mobModels.arrow),
      sync: (component, _) => component.sync(),
    );

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
    camera.followPlayer(player);
    selection.showFor(viewer.aim);
    _mobs.refresh();
    _arrows.refresh();
    heldItem.syncTo(
      item: viewer.heldItem,
      meshes: itemMeshes,
      eye: player.eye,
      forward: player.lookDirection,
      swinging: input.isHeld(GameAction.primary) && viewer.aim is BlockTarget,
      dt: dt,
    );
    _publishFrameStats();
  }

  // --- telemetry ---------------------------------------------------------

  void _publishFrameStats() => frameStats.value = FrameStats(
    fps: _fps,
    chunksReady: chunkManager.totalChunks - chunkManager.pendingChunks,
    chunksTotal: chunkManager.totalChunks,
  );
}
