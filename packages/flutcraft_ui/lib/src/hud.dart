import 'package:flutcraft_ui/src/providers/engine_providers.dart';
import 'package:flutcraft_ui/src/providers/message_provider.dart';
import 'package:flutcraft_ui/src/providers/session_providers.dart';
import 'package:flutcraft_ui/src/screens.dart';
import 'package:flutcraft_ui/src/slots.dart';
import 'package:flutcraft_ui/src/widgets.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_l10n/flutcraft_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The whole 2D layer over the world: crosshair, health, hotbar, touch
/// controls and the screens.
///
/// Every part reads its own slice of the snapshot, so a changing item count
/// does not rebuild the crosshair and a moving player does not rebuild the
/// inventory.
class Hud extends ConsumerWidget {
  const Hud({
    required this.showTouchControls,
    required this.onToggleTouchControls,
    required this.onToggleHelp,
    required this.helpVisible,
    super.key,
  });

  final bool showTouchControls;
  final VoidCallback onToggleTouchControls;
  final VoidCallback onToggleHelp;
  final bool helpVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(routeProvider) == UiRoute.none;

    return Stack(
      children: [
        const _HurtFlash(),
        if (playing) ...[
          const _AimOverlay(),
          _TopBar(
            onToggleTouchControls: onToggleTouchControls,
            onToggleHelp: onToggleHelp,
            touchControls: showTouchControls,
          ),
          const _MessageBanner(),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              // Clears the thumb row: the sticks are 132 tall plus their
              // padding, so anything lower puts the hotbar under a thumb.
              padding: EdgeInsets.only(bottom: showTouchControls ? 160 : 18),
              child: const _BottomBar(),
            ),
          ),
          if (showTouchControls) const _TouchControls(),
          if (helpVisible) _HelpOverlay(onClose: onToggleHelp),
        ],
        const GameScreens(),
      ],
    );
  }
}

/// Red wash right after taking a hit.
class _HurtFlash extends ConsumerWidget {
  const _HurtFlash();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flash = ref.watch(hurtFlashProvider);
    if (flash <= 0) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Colors.red.withValues(alpha: (flash * 0.9).clamp(0.0, 0.45)),
        ),
      ),
    );
  }
}

/// Crosshair, plus the health bar of whatever is under it.
class _AimOverlay extends ConsumerWidget {
  const _AimOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aim = ref.watch(aimProvider);

    return Stack(
      children: [
        Crosshair(
          progress: ref.watch(breakProgressProvider),
          hasTarget: aim is! NoAimView,
          hostile: aim is MobAimView,
        ),
        if (aim case final MobAimView target)
          Align(
            alignment: const Alignment(0, -0.18),
            child: TargetHealthBar(target: target),
          ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontFamily: 'monospace',
        ),
        child: child,
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.onToggleTouchControls,
    required this.onToggleHelp,
    required this.touchControls,
  });

  final VoidCallback onToggleTouchControls;
  final VoidCallback onToggleHelp;
  final bool touchControls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IgnorePointer(child: _Panel(child: _StatusText())),
            const Spacer(),
            _IconToggle(
              icon: Icons.gamepad,
              active: touchControls,
              onTap: onToggleTouchControls,
            ),
            const SizedBox(width: 8),
            _IconToggle(
              icon: Icons.menu_book,
              active: false,
              onTap: () => ref.read(dispatchProvider)(const OpenRecipes()),
            ),
            const SizedBox(width: 8),
            _IconToggle(
              icon: Icons.help_outline,
              active: false,
              onTap: onToggleHelp,
            ),
          ],
        ),
      ),
    );
  }
}

/// Position, frame rate and what the crosshair is on.
class _StatusText extends ConsumerWidget {
  const _StatusText();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(positionProvider);
    final aim = ref.watch(aimProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FrameStatsText(),
        Text('XYZ  ${position.x} / ${position.y} / ${position.z}'),
        Text(switch (aim) {
          NoAimView() => context.t.noTarget,
          BlockAimView(:final block) => context.t.hudTarget(
            context.strings.blockName(block),
          ),
          MobAimView(:final kind) => context.t.hudTarget(
            context.strings.mobName(kind),
          ),
        }),
        Text(context.t.hudMobs(ref.watch(mobCountProvider))),
        if (ref.watch(flyingProvider)) Text(context.t.flying),
      ],
    );
  }
}

/// Frame rate and chunk progress.
///
/// These change every single frame, so they are listened to separately —
/// nothing else in the HUD should rebuild sixty times a second.
class _FrameStatsText extends ConsumerWidget {
  const _FrameStatsText();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<FrameStats>(
      valueListenable: ref.watch(frameStatsProvider),
      builder: (context, stats, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t.hudFps(stats.fps.toStringAsFixed(0))),
          if (stats.isLoading)
            Text(
              context.t.hudChunks(stats.chunksReady, stats.chunksTotal),
              style: const TextStyle(color: Colors.amberAccent),
            ),
        ],
      ),
    );
  }
}

/// The last thing worth telling the player, in their language.
class _MessageBanner extends ConsumerWidget {
  const _MessageBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(messageProvider);
    if (event == null) return const SizedBox.shrink();

    final text = context.strings.event(event);
    if (text.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: const Alignment(0, -0.35),
      child: IgnorePointer(
        child: _Panel(
          child: Text(text, style: const TextStyle(color: Colors.amberAccent)),
        ),
      ),
    );
  }
}

class _IconToggle extends StatelessWidget {
  const _IconToggle({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? Colors.amberAccent : Colors.white24,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? Colors.amberAccent : Colors.white70,
        ),
      ),
    );
  }
}

/// Hearts and the hotbar along the bottom of the screen.
class _BottomBar extends ConsumerWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (health, maxHealth) = ref.watch(healthProvider);
    final hotbar = ref.watch(hotbarProvider);
    final selected = ref.watch(selectedSlotProvider);
    final image = ref.watch(atlasImageProvider);
    final dispatch = ref.watch(dispatchProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IgnorePointer(
          child: HeartsBar(health: health, maxHealth: maxHealth),
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
                  image: image,
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

/// Joystick and buttons for playing with a thumb.
class _TouchControls extends ConsumerWidget {
  const _TouchControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(inputRouterProvider);

    // Fills the stack on purpose: a non-positioned child of a Stack is sized
    // to its content and pinned to the top-left, which put the controls in
    // the sky. `end` only means the bottom of the screen if the row is as
    // tall as the screen.
    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              VirtualJoystick(
                onChanged: (x, y) => router.setStick(forward: y, strafe: x),
              ),
              const Spacer(),
              // One row rather than a 2x2 block: stacked, the buttons grew
              // taller than the sticks and reached up into the hotbar.
              Row(
                children: [
                  HoldButton(
                    label: context.t.buttonMineHit,
                    icon: Icons.construction,
                    color: Colors.amberAccent,
                    onChanged: (down) =>
                        router.hold(GameAction.primary, down: down),
                  ),
                  const SizedBox(width: 10),
                  HoldButton(
                    label: context.t.buttonUse,
                    icon: Icons.add_box_outlined,
                    color: Colors.lightGreenAccent,
                    onChanged: (down) =>
                        router.hold(GameAction.secondary, down: down),
                  ),
                  const SizedBox(width: 10),
                  HoldButton(
                    label: context.t.buttonJump,
                    icon: Icons.arrow_upward,
                    onChanged: (down) =>
                        router.hold(GameAction.jump, down: down),
                  ),
                  const SizedBox(width: 10),
                  HoldButton(
                    label: context.t.buttonFly,
                    icon: Icons.flight,
                    color: Colors.lightBlueAccent,
                    onChanged: (down) =>
                        router.hold(GameAction.toggleFlight, down: down),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // The right stick, where a thumb rests on a gamepad. Dragging the
              // screen still works, but a drag ends at the edge of the screen,
              // so turning right around took four of them.
              VirtualJoystick(
                color: Colors.lightBlueAccent,
                onChanged: (x, y) => router.setLookStick(x: x, y: y),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpOverlay extends StatelessWidget {
  const _HelpOverlay({required this.onClose});

  final VoidCallback onClose;

  /// Pairs of (key, action) built from the translations rather than written
  /// out here, so one column cannot be translated while the other is missed.
  List<(String, String)> _controls(AppLocalizations t) => [
    (t.helpMove, t.helpMoveAction),
    (t.helpLook, t.helpLookAction),
    (t.helpMineKey, t.helpMineAction),
    (t.helpUseKey, t.helpUseAction),
    (t.helpInventoryKey, t.helpInventoryAction),
    (t.helpRecipesKey, t.helpRecipesAction),
    (t.helpHotbarKey, t.helpHotbarAction),
    (t.helpSplitKey, t.helpSplitAction),
    (t.helpJumpKey, t.helpJumpAction),
    (t.helpSprintKey, t.helpSprintAction),
    (t.helpFlyKey, t.helpFlyAction),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Positioned.fill(
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.78),
          alignment: Alignment.center,
          child: SingleChildScrollView(
            child: _Panel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.helpTitle.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amberAccent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final (key, action) in _controls(t))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 220,
                            child: Text(
                              key,
                              style: const TextStyle(
                                color: Colors.lightBlueAccent,
                              ),
                            ),
                          ),
                          Expanded(child: Text(action)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    t.helpCombatTitle.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amberAccent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      t.helpCombatBody,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      '${t.helpRecipesHint}\n${t.helpFooter}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
