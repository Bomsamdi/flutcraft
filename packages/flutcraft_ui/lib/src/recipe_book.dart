import 'dart:ui' as ui;

import 'package:flutcraft_ui/src/widgets.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_l10n/flutcraft_l10n.dart';
import 'package:flutter/material.dart';

/// One cell of a recipe grid: no count, no tapping.
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

/// One row of the book: the ingredient layout, an arrow and the result.
class RecipeRow extends StatelessWidget {
  const RecipeRow({
    required this.image,
    required this.recipe,
    required this.missing,
    super.key,
  });

  final ui.Image image;
  final Recipe recipe;

  /// What is missing and how much of it; an empty map means it can be made.
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
                      ? context.strings.stack(
                          ItemStack(recipe.output, recipe.outputCount),
                        )
                      : context.strings.itemName(recipe.output),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _hint(context),
                  style: TextStyle(
                    color: available ? Colors.lightGreenAccent : Colors.white38,
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

  String _hint(BuildContext context) {
    final strings = context.strings;
    if (available) {
      return recipe.needsTable
          ? context.t.haveIngredientsTable
          : context.t.haveIngredients;
    }
    // Naming what is missing helps more than a bare "cannot craft".
    final parts = missing.entries
        .take(2)
        .map((e) => strings.stack(ItemStack(e.key, e.value)))
        .join(', ');
    final more = missing.length > 2
        ? ' ${context.t.andMore(missing.length - 2)}'
        : '';
    return context.t.missingIngredients('$parts$more');
  }

  Widget _pattern() {
    if (recipe.shapeless) {
      // Shapeless: the order does not matter, so draw a simple row.
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
              '${context.strings.itemName(input)} → '
              '${context.strings.itemName(output)}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// The contents of the recipe book.
class RecipeBook extends StatelessWidget {
  const RecipeBook({required this.image, required this.inventory, super.key});

  final ui.Image image;

  /// The player's slots, used to mark what they are still missing.
  final List<ItemStack?> inventory;

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
          _SectionTitle(context.t.recipesInInventory),
          for (final recipe in handheld)
            RecipeRow(
              image: image,
              recipe: recipe,
              missing: missingFor(recipe, inventory),
            ),
          const SizedBox(height: 10),
          _SectionTitle(context.t.recipesAtTable),
          for (final recipe in tableOnly)
            RecipeRow(
              image: image,
              recipe: recipe,
              missing: missingFor(recipe, inventory),
            ),
          const SizedBox(height: 10),
          _SectionTitle(context.t.smeltSeconds(FurnaceState.smeltTime.round())),
          for (final input in kSmeltable) SmeltRow(image: image, input: input),
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
