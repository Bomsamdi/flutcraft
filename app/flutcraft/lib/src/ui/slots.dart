import 'dart:ui' as ui;

import 'package:flutcraft/src/ui/widgets.dart';
import 'package:flutcraft_l10n/flutcraft_l10n.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutter/material.dart';

/// Pojedynczy slot ekwipunku: ikona, licznik sztuk i ramka zaznaczenia.
class ItemSlot extends StatelessWidget {
  const ItemSlot({
    required this.image,
    required this.stack,
    this.onTap,
    this.onSplit,
    this.selected = false,
    this.size = 46,
    this.label,
    this.highlight,
    super.key,
  });

  final ui.Image image;
  final ItemStack? stack;
  final VoidCallback? onTap;

  /// Prawy przycisk myszy albo przytrzymanie palcem - dzieli stos.
  final VoidCallback? onSplit;
  final bool selected;
  final double size;

  /// Numer klawisza albo podpis slotu (np. "paliwo").
  final String? label;

  /// Kolor obwódki dla slotów specjalnych (wynik craftingu, wytop).
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final item = stack?.type;

    return GestureDetector(
      onTap: onTap,
      onSecondaryTap: onSplit,
      onLongPress: onSplit,
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? Colors.white : (highlight ?? Colors.white24),
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            if (item != null)
              Padding(
                padding: EdgeInsets.all(size * 0.14),
                child: ItemIcon(image: image, item: item),
              ),
            if (label != null)
              Positioned(
                left: 3,
                top: 1,
                child: Text(
                  label!,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (stack != null && stack!.count > 1)
              Positioned(
                right: 3,
                bottom: 1,
                child: Text(
                  '${stack!.count}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 2)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Siatka slotów o zadanej liczbie kolumn.
class SlotGrid extends StatelessWidget {
  const SlotGrid({
    required this.image,
    required this.count,
    required this.columns,
    required this.stackAt,
    required this.onTap,
    this.onSplit,
    this.size = 46,
    this.labelAt,
    super.key,
  });

  final ui.Image image;
  final int count;
  final int columns;
  final ItemStack? Function(int index) stackAt;
  final void Function(int index) onTap;
  final void Function(int index)? onSplit;
  final double size;
  final String? Function(int index)? labelAt;

  @override
  Widget build(BuildContext context) {
    final rows = (count / columns).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < rows; row++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var col = 0; col < columns; col++)
                if (row * columns + col < count)
                  ItemSlot(
                    image: image,
                    stack: stackAt(row * columns + col),
                    onTap: () => onTap(row * columns + col),
                    onSplit: onSplit == null
                        ? null
                        : () => onSplit!(row * columns + col),
                    size: size,
                    label: labelAt?.call(row * columns + col),
                  ),
            ],
          ),
      ],
    );
  }
}

/// Pasek pokazujący, co gracz trzyma "na kursorze" podczas przekładania.
class CursorBar extends StatelessWidget {
  const CursorBar({required this.image, required this.stack, super.key});

  final ui.Image image;
  final ItemStack? stack;

  @override
  Widget build(BuildContext context) {
    final held = stack;
    return AnimatedOpacity(
      opacity: held == null ? 0.35 : 1,
      duration: const Duration(milliseconds: 120),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ItemSlot(image: image, stack: held, size: 38),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              held == null
                  ? context.t.cursorEmptyHint
                  : context.t.cursorHolding(context.strings.stack(held)),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
