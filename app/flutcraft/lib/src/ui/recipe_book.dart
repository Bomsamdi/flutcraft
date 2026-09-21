import 'dart:ui' as ui;

import 'package:flutcraft/src/core/furnace.dart';
import 'package:flutcraft/src/core/inventory.dart';
import 'package:flutcraft/src/core/item.dart';
import 'package:flutcraft/src/core/recipes.dart';
import 'package:flutcraft/src/ui/widgets.dart';
import 'package:flutter/material.dart';

/// Mała komórka siatki przepisu - bez licznika i bez klikania.
class _Cell extends StatelessWidget {
  const _Cell({required this.image, required this.item});

  final ui.Image image;
  final ItemType? item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: item == null ? Colors.white10 : Colors.white24,
        borderRadius: BorderRadius.circular(4),
      ),
      child: item == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(3),
              child: ItemIcon(image: image, item: item!),
            ),
    );
  }
}

/// Jeden wiersz księgi: układ składników, strzałka i wynik.
class RecipeRow extends StatelessWidget {
  const RecipeRow({
    required this.image,
    required this.recipe,
    required this.missing,
    super.key,
  });

  final ui.Image image;
  final Recipe recipe;

  /// Czego i ile brakuje; pusta mapa znaczy "można robić".
  final Map<ItemType, int> missing;

  bool get available => missing.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: available ? Colors.green.withValues(alpha: 0.12) : null,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: available ? Colors.lightGreenAccent : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          _pattern(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward, size: 16, color: Colors.white54),
          ),
          _Cell(image: image, item: recipe.output),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  recipe.outputCount > 1
                      ? '${recipe.output.label} x${recipe.outputCount}'
                      : recipe.output.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _hint(),
                  style: TextStyle(
                    color: available
                        ? Colors.lightGreenAccent
                        : Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _hint() {
    if (available) {
      return recipe.needsTable ? 'Masz składniki - ułóż na stole' : 'Masz składniki';
    }
    // Konkret jest bardziej użyteczny niż samo "nie da się".
    final parts = missing.entries
        .take(2)
        .map((e) => '${e.key.label} x${e.value}')
        .join(', ');
    final more = missing.length > 2 ? ' i ${missing.length - 2} więcej' : '';
    return 'Brakuje: $parts$more';
  }

  Widget _pattern() {
    if (recipe.shapeless) {
      // Bezkształtowy: kolejność nie ma znaczenia, więc rysujemy rządek.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in recipe.ingredients)
            _Cell(image: image, item: item),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < recipe.height; row++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var col = 0; col < recipe.width; col++)
                _Cell(image: image, item: recipe.at(row, col)),
            ],
          ),
      ],
    );
  }
}

/// Wiersz wytopu w piecu.
class SmeltRow extends StatelessWidget {
  const SmeltRow({required this.image, required this.input, super.key});

  final ui.Image image;
  final ItemType input;

  @override
  Widget build(BuildContext context) {
    final output = smeltResult(input);
    if (output == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          _Cell(image: image, item: input),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.local_fire_department,
              size: 16,
              color: Colors.orangeAccent,
            ),
          ),
          _Cell(image: image, item: output),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${input.label} → ${output.label}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Zawartość księgi przepisów.
class RecipeBook extends StatelessWidget {
  const RecipeBook({
    required this.image,
    required this.inventory,
    super.key,
  });

  final ui.Image image;
  final Inventory inventory;

  @override
  Widget build(BuildContext context) {
    final handheld = kRecipes.where((r) => !r.needsTable).toList();
    final tableOnly = kRecipes.where((r) => r.needsTable).toList();

    return SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('W ekwipunku (siatka 2x2)'),
          for (final recipe in handheld)
            RecipeRow(
              image: image,
              recipe: recipe,
              missing: missingFor(recipe, inventory),
            ),
          const SizedBox(height: 10),
          const _SectionTitle('Na stole rzemieślniczym (3x3)'),
          for (final recipe in tableOnly)
            RecipeRow(
              image: image,
              recipe: recipe,
              missing: missingFor(recipe, inventory),
            ),
          const SizedBox(height: 10),
          _SectionTitle(
            'W piecu (paliwo: węgiel, '
            '${FurnaceState.smeltTime.toStringAsFixed(0)} s na sztukę)',
          ),
          for (final input in kSmeltable)
            SmeltRow(image: image, input: input),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.amberAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
