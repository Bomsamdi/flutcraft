import 'dart:ui' as ui;

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The texture atlas the HUD draws item icons from.
///
/// Built by the composition root before the game starts, not by the renderer,
/// so the interface has its icons from the very first frame and no widget
/// has to cope with a null image.
final atlasImageProvider = Provider<ui.Image>((ref) {
  throw UnimplementedError('atlasImageProvider must be overridden');
});

/// Where every input source pushes what the player is doing.
final inputRouterProvider = Provider<InputRouter>((ref) {
  throw UnimplementedError('inputRouterProvider must be overridden');
});

/// What the renderer reports about itself, updated every frame.
///
/// A [ValueListenable] rather than a provider of values: these numbers change
/// sixty times a second and only the debug panel cares, so they must not
/// rebuild anything else.
final frameStatsProvider = Provider<ValueListenable<FrameStats>>((ref) {
  throw UnimplementedError('frameStatsProvider must be overridden');
});
