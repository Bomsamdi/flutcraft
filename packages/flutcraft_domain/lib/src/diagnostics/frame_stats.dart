import 'package:meta/meta.dart';

/// What the renderer reports about itself.
///
/// The simulation neither produces nor reads these numbers. They live in the
/// domain because the engine that measures them and the HUD that displays
/// them depend on this package and on nothing else in common — a shared
/// vocabulary here is cheaper than a dependency between those two.
@immutable
final class FrameStats {
  const FrameStats({this.fps = 0, this.chunksReady = 0, this.chunksTotal = 0});

  final double fps;

  /// Chunks whose mesh is built and on screen.
  final int chunksReady;

  final int chunksTotal;

  /// Whether the world is still being built around the player.
  bool get isLoading => chunksReady < chunksTotal;

  @override
  bool operator ==(Object other) =>
      other is FrameStats &&
      other.fps == fps &&
      other.chunksReady == chunksReady &&
      other.chunksTotal == chunksTotal;

  @override
  int get hashCode => Object.hash(fps, chunksReady, chunksTotal);
}
