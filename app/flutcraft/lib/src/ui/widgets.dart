import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutcraft/src/core/block.dart';
import 'package:flutcraft/src/core/item.dart';
import 'package:flutcraft/src/game/hud_state.dart';
import 'package:flutcraft/src/core/tiles.dart';
import 'package:flutcraft/src/render/atlas.dart';
import 'package:flutter/material.dart';

/// Rysuje kafelek z atlasu tekstur - ta sama grafika co w świecie 3D.
class TilePainter extends CustomPainter {
  TilePainter({required this.image, required this.tile, this.shade = Shade.top});

  final ui.Image image;
  final Tile tile;
  final Shade shade;

  @override
  void paint(Canvas canvas, Size size) {
    final t = TextureAtlas.tilePx.toDouble();
    final src = Rect.fromLTWH(tile.index * t, shade.index * t, t, t);
    canvas.drawImageRect(
      image,
      src,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(TilePainter old) =>
      old.image != image || old.tile != tile || old.shade != shade;
}

/// Ikona bloku w pasku: ścianka boczna + skos góry, żeby czytać bryłę.
class BlockIcon extends StatelessWidget {
  const BlockIcon({required this.image, required this.block, super.key});

  final ui.Image image;
  final BlockType block;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: CustomPaint(
            painter: TilePainter(image: image, tile: block.topTile),
            size: Size.infinite,
          ),
        ),
        Expanded(
          flex: 5,
          child: CustomPaint(
            painter: TilePainter(
              image: image,
              tile: block.sideTile,
              shade: Shade.sideZ,
            ),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }
}

/// Ikona dowolnego przedmiotu: bloki jako bryłka, reszta jako płaska ikona.
class ItemIcon extends StatelessWidget {
  const ItemIcon({required this.image, required this.item, super.key});

  final ui.Image image;
  final ItemType item;

  @override
  Widget build(BuildContext context) {
    if (item.isBlock) {
      return BlockIcon(image: image, block: item.block!);
    }
    return CustomPaint(
      painter: TilePainter(image: image, tile: item.icon),
      size: Size.infinite,
    );
  }
}

/// Pasek zdrowia w serduszkach - każde serce to 2 punkty życia.
class HeartsBar extends StatelessWidget {
  const HeartsBar({
    required this.health,
    required this.maxHealth,
    super.key,
  });

  final int health;
  final int maxHealth;

  @override
  Widget build(BuildContext context) {
    final hearts = maxHealth ~/ 2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < hearts; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              health >= (i + 1) * 2
                  ? Icons.favorite
                  : health >= i * 2 + 1
                  ? Icons.heart_broken
                  : Icons.favorite_border,
              size: 18,
              color: health >= i * 2 + 1
                  ? Colors.redAccent
                  : Colors.white24,
              shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
            ),
          ),
      ],
    );
  }
}

/// Celownik z pierścieniem postępu kopania.
class Crosshair extends StatelessWidget {
  const Crosshair({
    required this.progress,
    required this.hasTarget,
    this.hostile = false,
    super.key,
  });

  final double progress;
  final bool hasTarget;

  /// Na celowniku jest potwór - celownik zmienia się w czerwony krzyżyk.
  final bool hostile;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: CustomPaint(
          size: const Size(52, 52),
          painter: _CrosshairPainter(
            progress: progress,
            active: hasTarget,
            hostile: hostile,
          ),
        ),
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  _CrosshairPainter({
    required this.progress,
    required this.active,
    required this.hostile,
  });

  final double progress;
  final bool active;
  final bool hostile;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()
      ..color = hostile
          ? Colors.redAccent
          : (active ? Colors.white : Colors.white70)
      ..strokeWidth = hostile ? 3 : 2
      ..strokeCap = StrokeCap.round;

    const arm = 8.0;
    const gap = 3.0;

    if (hostile) {
      // Skośny krzyżyk czytelnie mówi "tu można uderzyć".
      canvas
        ..drawLine(c.translate(-arm, -arm), c.translate(-gap, -gap), paint)
        ..drawLine(c.translate(gap, gap), c.translate(arm, arm), paint)
        ..drawLine(c.translate(arm, -arm), c.translate(gap, -gap), paint)
        ..drawLine(c.translate(-gap, gap), c.translate(-arm, arm), paint);
      return;
    }

    canvas
      ..drawLine(c.translate(-arm - gap, 0), c.translate(-gap, 0), paint)
      ..drawLine(c.translate(gap, 0), c.translate(arm + gap, 0), paint)
      ..drawLine(c.translate(0, -arm - gap), c.translate(0, -gap), paint)
      ..drawLine(c.translate(0, gap), c.translate(0, arm + gap), paint);

    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: 18),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0, 1),
      false,
      Paint()
        ..color = Colors.amberAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CrosshairPainter old) =>
      old.progress != progress ||
      old.active != active ||
      old.hostile != hostile;
}

/// Pasek życia potwora na celowniku.
class TargetHealthBar extends StatelessWidget {
  const TargetHealthBar({required this.target, super.key});

  final TargetMob target;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            target.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(blurRadius: 3, color: Colors.black)],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 140,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white38),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: target.fraction,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.lerp(
                    Colors.red,
                    Colors.lightGreenAccent,
                    target.fraction,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wirtualny drążek - zwraca wektor -1..1 na obu osiach.
class VirtualJoystick extends StatefulWidget {
  const VirtualJoystick({required this.onChanged, this.size = 132, super.key});

  final void Function(double strafe, double forward) onChanged;
  final double size;

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _knob = Offset.zero;
  int? _pointer;

  double get _radius => widget.size / 2;

  void _update(Offset local) {
    var delta = local - Offset(_radius, _radius);
    if (delta.distance > _radius) {
      delta = delta / delta.distance * _radius;
    }
    setState(() => _knob = delta);
    widget.onChanged(delta.dx / _radius, -delta.dy / _radius);
  }

  void _reset() {
    setState(() => _knob = Offset.zero);
    widget.onChanged(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        _pointer = e.pointer;
        _update(e.localPosition);
      },
      onPointerMove: (e) {
        if (e.pointer == _pointer) _update(e.localPosition);
      },
      onPointerUp: (e) {
        if (e.pointer == _pointer) {
          _pointer = null;
          _reset();
        }
      },
      onPointerCancel: (_) {
        _pointer = null;
        _reset();
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.25),
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: Center(
          child: Transform.translate(
            offset: _knob,
            child: Container(
              width: widget.size * 0.38,
              height: widget.size * 0.38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Przycisk reagujący na przytrzymanie (kopanie, skok, stawianie).
class HoldButton extends StatefulWidget {
  const HoldButton({
    required this.label,
    required this.icon,
    required this.onChanged,
    this.color = Colors.white,
    super.key,
  });

  final String label;
  final IconData icon;
  final ValueChanged<bool> onChanged;
  final Color color;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton> {
  bool _held = false;

  void _set(bool value) {
    if (_held == value) return;
    setState(() => _held = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: _held ? 0.55 : 0.3),
          border: Border.all(
            color: _held ? widget.color : Colors.white24,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: widget.color, size: 26),
            const SizedBox(height: 2),
            Text(
              widget.label,
              style: TextStyle(
                color: widget.color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
