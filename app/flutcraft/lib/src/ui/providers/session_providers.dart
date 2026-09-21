import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The running game.
///
/// Declared without an implementation on purpose: the app overrides it with
/// a real session wired to the engine, and a test overrides it with a
/// headless [LoopGameSession]. That single seam is what lets every screen be
/// rendered in `flutter test` without a GPU.
final gameSessionProvider = Provider<GameSession>((ref) {
  throw UnimplementedError(
    'gameSessionProvider must be overridden in ProviderScope',
  );
});

/// The latest picture of the game, refreshed at the session's rate.
final snapshotProvider = StreamProvider<GameSnapshot>((ref) {
  final session = ref.watch(gameSessionProvider);
  return session.snapshots;
});

/// The current snapshot, falling back to the session's own value before the
/// first stream event arrives.
final currentSnapshotProvider = Provider<GameSnapshot>((ref) {
  final session = ref.watch(gameSessionProvider);
  return ref.watch(snapshotProvider).value ?? session.snapshot;
});

/// Sends a command to the game.
///
/// Widgets depend on this rather than on the session itself, so they cannot
/// accidentally reach for anything else on it.
final dispatchProvider = Provider<void Function(GameCommand)>(
  (ref) => ref.watch(gameSessionProvider).dispatch,
);

// --- derived views -----------------------------------------------------
// Each uses `select` so a widget rebuilds only when its own slice changes,
// not on every snapshot.

final routeProvider = Provider<UiRoute>(
  (ref) => ref.watch(currentSnapshotProvider.select((s) => s.route)),
);

final hotbarProvider = Provider<List<ItemStack?>>(
  (ref) => ref.watch(currentSnapshotProvider.select((s) => s.hotbar)),
);

final selectedSlotProvider = Provider<int>(
  (ref) => ref.watch(currentSnapshotProvider.select((s) => s.selectedSlot)),
);

final aimProvider = Provider<AimView>(
  (ref) => ref.watch(currentSnapshotProvider.select((s) => s.aim)),
);

final furnaceProvider = Provider<FurnaceView?>(
  (ref) => ref.watch(currentSnapshotProvider.select((s) => s.furnace)),
);

final cursorProvider = Provider<ItemStack?>(
  (ref) => ref.watch(currentSnapshotProvider.select((s) => s.cursor)),
);

final inventoryProvider = Provider<List<ItemStack?>>(
  (ref) => ref.watch(currentSnapshotProvider.select((s) => s.inventory)),
);

final gridProvider = Provider<List<ItemStack?>>(
  (ref) => ref.watch(currentSnapshotProvider.select((s) => s.grid)),
);

final gridSizeProvider = Provider<int>(
  (ref) => ref.watch(currentSnapshotProvider.select((s) => s.gridSize)),
);

final craftPreviewProvider = Provider<ItemStack?>(
  (ref) => ref.watch(currentSnapshotProvider.select((s) => s.craftPreview)),
);

final healthProvider = Provider<(int, int)>(
  (ref) =>
      ref.watch(currentSnapshotProvider.select((s) => (s.health, s.maxHealth))),
);

final hurtFlashProvider = Provider<double>(
  (ref) => ref.watch(currentSnapshotProvider.select((s) => s.hurtFlash)),
);

final breakProgressProvider = Provider<double>(
  (ref) => ref.watch(currentSnapshotProvider.select((s) => s.breakProgress)),
);

final positionProvider = Provider<BlockPos>(
  (ref) => ref.watch(currentSnapshotProvider.select((s) => s.position)),
);

final mobCountProvider = Provider<int>(
  (ref) => ref.watch(currentSnapshotProvider.select((s) => s.mobCount)),
);

final flyingProvider = Provider<bool>(
  (ref) => ref.watch(currentSnapshotProvider.select((s) => s.flying)),
);
