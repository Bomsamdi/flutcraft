import 'dart:ui' as ui;

import 'package:flutcraft/src/game/flutcraft_game.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_l10n/flutcraft_l10n.dart';
import 'package:flutcraft/src/game/hud_state.dart';
import 'package:flutcraft/src/ui/screens.dart';
import 'package:flutcraft/src/ui/slots.dart';
import 'package:flutcraft/src/ui/widgets.dart';
import 'package:flutter/material.dart';

/// Cała warstwa 2D nad grą: celownik, zdrowie, pasek przedmiotów,
/// sterowanie dotykowe i ekrany ekwipunku.
class Hud extends StatelessWidget {
  const Hud({
    required this.game,
    required this.snapshot,
    required this.showTouchControls,
    required this.onToggleTouchControls,
    required this.onToggleHelp,
    required this.helpVisible,
    super.key,
  });

  final FlutcraftGame game;
  final HudSnapshot snapshot;
  final bool showTouchControls;
  final VoidCallback onToggleTouchControls;
  final VoidCallback onToggleHelp;
  final bool helpVisible;

  @override
  Widget build(BuildContext context) {
    final image = game.atlasImage;
    final screen = image == null
        ? null
        : buildScreen(game, image, snapshot.screen);

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
        if (snapshot.screen == UiRoute.none) ...[
          Crosshair(
            progress: snapshot.breakProgress,
            hasTarget: snapshot.aim is! NoAimView,
            hostile: snapshot.targetMob != null,
          ),
          if (snapshot.targetMob case final target?)
            Align(
              alignment: const Alignment(0, -0.18),
              child: TargetHealthBar(target: target),
            ),
          _TopBar(
            snapshot: snapshot,
            onToggleTouchControls: onToggleTouchControls,
            onToggleHelp: onToggleHelp,
            onOpenRecipes: game.openRecipes,
            touchControls: showTouchControls,
          ),
          if (snapshot.event case final event?)
            Builder(
              builder: (context) {
                final text = context.strings.event(event);
                if (text.isEmpty) return const SizedBox.shrink();
                return Align(
                  alignment: const Alignment(0, -0.35),
                  child: IgnorePointer(
                    child: _Panel(
                      child: Text(
                        text,
                        style: const TextStyle(color: Colors.amberAccent),
                      ),
                    ),
                  ),
                );
              },
            ),
          if (image != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: showTouchControls ? 116 : 18,
                ),
                child: _BottomBar(
                  game: game,
                  image: image,
                  snapshot: snapshot,
                ),
              ),
            ),
          if (showTouchControls) _TouchControls(game: game),
          if (helpVisible) _HelpOverlay(onClose: onToggleHelp),
        ],
        ?screen,
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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.snapshot,
    required this.onToggleTouchControls,
    required this.onToggleHelp,
    required this.onOpenRecipes,
    required this.touchControls,
  });

  final HudSnapshot snapshot;
  final VoidCallback onToggleTouchControls;
  final VoidCallback onToggleHelp;
  final VoidCallback onOpenRecipes;
  final bool touchControls;

  @override
  Widget build(BuildContext context) {
    final (x, y, z) = snapshot.position;
    final loading = snapshot.chunksPending > 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IgnorePointer(
              child: _Panel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t.hudFps(snapshot.fps.toStringAsFixed(0))),
                    Text('XYZ  $x / $y / $z'),
                    Text(switch (snapshot.aim) {
                      NoAimView() => context.t.noTarget,
                      BlockAimView(:final block) => context.t.hudTarget(
                        context.strings.blockName(block),
                      ),
                      MobAimView(:final kind) => context.t.hudTarget(
                        context.strings.mobName(kind),
                      ),
                    }),
                    Text(context.t.hudMobs(snapshot.mobCount)),
                    if (snapshot.flying) Text(context.t.flying),
                    if (loading)
                      Text(
                        context.t.hudChunks(
                          snapshot.chunksTotal - snapshot.chunksPending,
                          snapshot.chunksTotal,
                        ),
                        style: const TextStyle(color: Colors.amberAccent),
                      ),
                  ],
                ),
              ),
            ),
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
              onTap: onOpenRecipes,
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

/// Serca i pasek przedmiotów u dołu ekranu.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.game,
    required this.image,
    required this.snapshot,
  });

  final FlutcraftGame game;
  final ui.Image image;
  final HudSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
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
              for (var i = 0; i < snapshot.hotbar.length; i++)
                ItemSlot(
                  image: image,
                  stack: snapshot.hotbar[i],
                  selected: i == snapshot.selected,
                  label: '${i + 1}',
                  size: 44,
                  onTap: () => game.selectSlot(i),
                ),
              GestureDetector(
                onTap: game.toggleInventory,
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

class _TouchControls extends StatelessWidget {
  const _TouchControls({required this.game});

  final FlutcraftGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            VirtualJoystick(onChanged: game.setMoveAxis),
            const Spacer(),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    HoldButton(
                      label: context.t.buttonMineHit,
                      icon: Icons.construction,
                      color: Colors.amberAccent,
                      onChanged: game.setMining,
                    ),
                    const SizedBox(width: 10),
                    HoldButton(
                      label: context.t.buttonUse,
                      icon: Icons.add_box_outlined,
                      color: Colors.lightGreenAccent,
                      onChanged: game.setPlacing,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    HoldButton(
                      label: context.t.buttonJump,
                      icon: Icons.arrow_upward,
                      onChanged: game.setJump,
                    ),
                    const SizedBox(width: 10),
                    HoldButton(
                      label: context.t.buttonFly,
                      icon: Icons.flight,
                      color: Colors.lightBlueAccent,
                      onChanged: (down) {
                        if (down) game.toggleFly();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpOverlay extends StatelessWidget {
  const _HelpOverlay({required this.onClose});

  final VoidCallback onClose;

  /// Pary (klawisz, akcja) budowane z tłumaczeń, a nie wpisane w kod —
  /// dzięki temu nie da się przetłumaczyć jednej kolumny i zapomnieć drugiej.
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
