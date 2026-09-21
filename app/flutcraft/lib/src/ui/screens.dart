import 'dart:ui' as ui;

import 'package:flutcraft/src/game/flutcraft_game.dart';
import 'package:flutcraft/src/ui/recipe_book.dart';
import 'package:flutcraft/src/ui/slots.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_l10n/flutcraft_l10n.dart';
import 'package:flutter/material.dart';

/// Na niskim ekranie (telefon w poziomie) sloty muszą być mniejsze,
/// inaczej ekwipunek nie mieści się bez przewijania.
bool _isCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).height < 480;

double _slotSize(BuildContext context, {double normal = 42}) =>
    _isCompact(context) ? normal * 0.76 : normal;

/// Wspólna oprawa ekranów zasłaniających świat.
class ScreenFrame extends StatelessWidget {
  const ScreenFrame({
    required this.title,
    required this.onClose,
    required this.child,
    this.onRecipes,
    super.key,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;

  /// Skrót do księgi przepisów; `null` ukrywa przycisk.
  final VoidCallback? onRecipes;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.72),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B2B33),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 24),
                        const Spacer(),
                        if (onRecipes != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: GestureDetector(
                              onTap: onRecipes,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.menu_book,
                                    size: 18,
                                    color: Colors.lightBlueAccent,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    context.t.recipesLink,
                                    style: const TextStyle(
                                      color: Colors.lightBlueAccent,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        GestureDetector(
                          onTap: onClose,
                          child: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plecak (3x9) i pasek szybkiego dostępu - wspólne dla wszystkich ekranów.
class InventoryPanel extends StatelessWidget {
  const InventoryPanel({required this.game, required this.image, super.key});

  final FlutcraftGame game;
  final ui.Image image;

  @override
  Widget build(BuildContext context) {
    final inventory = game.inventory;
    final size = _slotSize(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SlotGrid(
          image: image,
          count: inventory.backpackSize,
          columns: 9,
          size: size,
          stackAt: (i) => inventory[inventory.hotbarSize + i],
          onTap: (i) => game.clickInventorySlot(inventory.hotbarSize + i),
          onSplit: (i) => game.splitInventorySlot(inventory.hotbarSize + i),
        ),
        SizedBox(height: _isCompact(context) ? 4 : 8),
        SlotGrid(
          image: image,
          count: inventory.hotbarSize,
          columns: 9,
          size: size,
          stackAt: (i) => inventory[i],
          onTap: game.clickInventorySlot,
          onSplit: game.splitInventorySlot,
          labelAt: (i) => '${i + 1}',
        ),
      ],
    );
  }
}

/// Ekwipunek z siatką 2x2 albo stół rzemieślniczy z siatką 3x3.
class CraftingScreen extends StatelessWidget {
  const CraftingScreen({
    required this.game,
    required this.image,
    required this.isTable,
    super.key,
  });

  final FlutcraftGame game;
  final ui.Image image;
  final bool isTable;

  @override
  Widget build(BuildContext context) {
    final grid = game.activeGrid;
    final preview = game.craftPreview;

    return ScreenFrame(
      title: isTable
          ? context.t.screenCraftingTable
          : context.t.screenInventory,
      onClose: game.closeScreen,
      onRecipes: game.openRecipes,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SlotGrid(
                image: image,
                count: grid.slots.length,
                columns: grid.size,
                size: _slotSize(context, normal: 44),
                stackAt: (i) => grid[i],
                onTap: game.clickGridSlot,
                onSplit: game.splitGridSlot,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward, color: Colors.white54),
              ),
              ItemSlot(
                image: image,
                stack: preview,
                size: _slotSize(context, normal: 52),
                highlight: preview == null
                    ? Colors.white24
                    : Colors.lightGreenAccent,
                onTap: game.takeCraftResult,
              ),
            ],
          ),
          if (!isTable)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                context.t.craftingTableHint,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          Divider(color: Colors.white24, height: _isCompact(context) ? 14 : 22),
          InventoryPanel(game: game, image: image),
          SizedBox(height: _isCompact(context) ? 6 : 10),
          CursorBar(image: image, stack: game.cursor),
        ],
      ),
    );
  }
}

/// Ekran pieca: wsad, paliwo i wynik wytopu.
class FurnaceScreen extends StatelessWidget {
  const FurnaceScreen({
    required this.game,
    required this.image,
    required this.state,
    super.key,
  });

  final FlutcraftGame game;
  final ui.Image image;
  final FurnaceState state;

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: context.t.screenFurnace,
      onClose: game.closeScreen,
      onRecipes: game.openRecipes,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ItemSlot(
                    image: image,
                    stack: state.input,
                    size: 46,
                    onTap: () => game.clickFurnaceSlot(0),
                    onSplit: () => game.clickFurnaceSlot(0, split: true),
                  ),
                  Text(
                    context.t.furnaceInput,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  SizedBox(
                    height: 26,
                    width: 26,
                    child: Icon(
                      Icons.local_fire_department,
                      color: state.isLit
                          ? Color.lerp(
                              Colors.deepOrange,
                              Colors.amber,
                              state.fuelFraction,
                            )
                          : Colors.white12,
                    ),
                  ),
                  ItemSlot(
                    image: image,
                    stack: state.fuel,
                    size: 46,
                    highlight: state.isLit ? Colors.orangeAccent : null,
                    onTap: () => game.clickFurnaceSlot(1),
                    onSplit: () => game.clickFurnaceSlot(1, split: true),
                  ),
                  Text(
                    context.t.furnaceFuel,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: SizedBox(
                  width: 70,
                  child: Column(
                    children: [
                      const Icon(Icons.arrow_forward, color: Colors.white54),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: state.progress.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(
                          Colors.amberAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ItemSlot(
                image: image,
                stack: state.output,
                size: 52,
                highlight: Colors.lightGreenAccent,
                onTap: () => game.clickFurnaceSlot(2),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.t.furnaceHint,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
          Divider(color: Colors.white24, height: _isCompact(context) ? 14 : 22),
          InventoryPanel(game: game, image: image),
          SizedBox(height: _isCompact(context) ? 6 : 10),
          CursorBar(image: image, stack: game.cursor),
        ],
      ),
    );
  }
}

/// Ekran śmierci gracza.
class DeathScreen extends StatelessWidget {
  const DeathScreen({required this.game, super.key});

  final FlutcraftGame game;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xAA6B0F0F),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.t.youDied,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: game.respawn,
                icon: const Icon(Icons.refresh),
                label: Text(context.t.respawnWithKey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Księga przepisów - co z czego powstaje.
class RecipeScreen extends StatelessWidget {
  const RecipeScreen({required this.game, required this.image, super.key});

  final FlutcraftGame game;
  final ui.Image image;

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: context.t.screenRecipes,
      onClose: game.closeScreen,
      child: RecipeBook(image: image, inventory: game.inventory),
    );
  }
}

/// Wybiera ekran pasujący do stanu gry.
Widget? buildScreen(FlutcraftGame game, ui.Image image, UiRoute screen) {
  return switch (screen) {
    UiRoute.none => null,
    UiRoute.dead => DeathScreen(game: game),
    UiRoute.inventory => CraftingScreen(
      game: game,
      image: image,
      isTable: false,
    ),
    UiRoute.craftingTable => CraftingScreen(
      game: game,
      image: image,
      isTable: true,
    ),
    UiRoute.recipes => RecipeScreen(game: game, image: image),
    UiRoute.furnace => switch (game.openFurnace) {
      final state? => FurnaceScreen(game: game, image: image, state: state),
      _ => null,
    },
  };
}
