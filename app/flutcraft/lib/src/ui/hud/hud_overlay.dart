import 'dart:ui' as ui;

import 'package:flutcraft/src/ui/providers/session_providers.dart';
import 'package:flutcraft/src/ui/slots.dart';
import 'package:flutcraft/src/ui/widgets.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Crosshair, target health and the hotbar.
///
/// Reads only from the snapshot and sends only commands, so it renders in a
/// widget test against a headless game — no Flame, no GPU.
class HudOverlay extends ConsumerWidget {
  const HudOverlay({required this.atlas, super.key});

  final ui.Image atlas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aim = ref.watch(aimProvider);
    final snapshot = ref.watch(currentSnapshotProvider);

    return Stack(
      children: [
        if (snapshot.hurtFlash > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Colors.red.withValues(
                  alpha: (snapshot.hurtFlash * 0.9).clamp(0.0, 0.45),
                ),
              ),
            ),
          ),
        Crosshair(
          progress: snapshot.breakProgress,
          hasTarget: aim is! NoAimView,
          hostile: aim is MobAimView,
        ),
        if (aim is MobAimView)
          Align(
            alignment: const Alignment(0, -0.18),
            child: TargetHealthBar(target: aim),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: _BottomBar(atlas: atlas),
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.atlas});

  final ui.Image atlas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotbar = ref.watch(hotbarProvider);
    final selected = ref.watch(selectedSlotProvider);
    final snapshot = ref.watch(currentSnapshotProvider);
    final dispatch = ref.watch(dispatchProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IgnorePointer(
          child: HeartsBar(
            health: snapshot.health,
            maxHealth: snapshot.maxHealth,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < hotbar.length; i++)
                ItemSlot(
                  image: atlas,
                  stack: hotbar[i],
                  selected: i == selected,
                  label: '${i + 1}',
                  size: 44,
                  onTap: () => dispatch(SelectHotbarSlot(i)),
                ),
              GestureDetector(
                onTap: () => dispatch(const OpenRoute(UiRoute.inventory)),
                child: Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amberAccent),
                  ),
                  child: const Icon(
                    Icons.backpack,
                    color: Colors.amberAccent,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
