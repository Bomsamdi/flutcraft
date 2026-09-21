import 'package:flutcraft/src/ui/providers/engine_providers.dart';
import 'package:flutcraft/src/ui/providers/session_providers.dart';
import 'package:flutcraft/src/ui/recipe_book.dart';
import 'package:flutcraft/src/ui/slots.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_l10n/flutcraft_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// On a short screen (a phone held sideways) the slots have to shrink, or
/// the inventory will not fit without scrolling.
bool _isCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).height < 480;

double _slotSize(BuildContext context, {double normal = 42}) =>
    _isCompact(context) ? normal * 0.76 : normal;

/// The screen that belongs to the route the player is on.
///
/// Every screen reads what it needs from providers and sends commands back,
/// so none of them knows the engine exists — which is what lets all of them
/// be rendered in a widget test.
class GameScreens extends ConsumerWidget {
  const GameScreens({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(routeProvider)) {
      UiRoute.none => const SizedBox.shrink(),
      UiRoute.dead => const DeathScreen(),
      UiRoute.inventory => const CraftingScreen(isTable: false),
      UiRoute.craftingTable => const CraftingScreen(isTable: true),
      UiRoute.recipes => const RecipeScreen(),
      UiRoute.furnace => const FurnaceScreen(),
    };
  }
}

/// Shared frame around the screens that cover the world.
class ScreenFrame extends ConsumerWidget {
  const ScreenFrame({
    required this.title,
    required this.child,
    this.showRecipes = false,
    super.key,
  });

  final String title;
  final Widget child;

  /// Whether to offer the shortcut to the recipe book.
  final bool showRecipes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dispatch = ref.watch(dispatchProvider);

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
                        if (showRecipes)
                          Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: GestureDetector(
                              onTap: () => dispatch(const OpenRecipes()),
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
                          onTap: () => dispatch(const CloseRoute()),
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

/// The backpack (3x9) and the hotbar — shared by every screen.
class InventoryPanel extends ConsumerWidget {
  const InventoryPanel({super.key});

  /// How many slots the hotbar has; the rest of the inventory is backpack.
  static const int hotbarSize = 9;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(inventoryProvider);
    final image = ref.watch(atlasImageProvider);
    final dispatch = ref.watch(dispatchProvider);
    final size = _slotSize(context);

    void click(int index, {required bool split}) => dispatch(
      ClickSlot(
        InventorySlotRef(index),
        kind: split ? ClickKind.split : ClickKind.primary,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SlotGrid(
          image: image,
          count: inventory.length - hotbarSize,
          columns: 9,
          size: size,
          stackAt: (i) => inventory[hotbarSize + i],
          onTap: (i) => click(hotbarSize + i, split: false),
          onSplit: (i) => click(hotbarSize + i, split: true),
        ),
        SizedBox(height: _isCompact(context) ? 4 : 8),
        SlotGrid(
          image: image,
          count: hotbarSize,
          columns: 9,
          size: size,
          stackAt: (i) => inventory[i],
          onTap: (i) => click(i, split: false),
          onSplit: (i) => click(i, split: true),
          labelAt: (i) => '${i + 1}',
        ),
      ],
    );
  }
}

/// What the player is dragging, shown under the inventory.
class CursorPanel extends ConsumerWidget {
  const CursorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => CursorBar(
    image: ref.watch(atlasImageProvider),
    stack: ref.watch(cursorProvider),
  );
}

/// The inventory with its 2x2 grid, or a crafting table with a 3x3 one.
class CraftingScreen extends ConsumerWidget {
  const CraftingScreen({required this.isTable, super.key});

  final bool isTable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = ref.watch(gridProvider);
    final columns = ref.watch(gridSizeProvider);
    final preview = ref.watch(craftPreviewProvider);
    final image = ref.watch(atlasImageProvider);
    final dispatch = ref.watch(dispatchProvider);

    return ScreenFrame(
      title: isTable
          ? context.t.screenCraftingTable
          : context.t.screenInventory,
      showRecipes: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SlotGrid(
                image: image,
                count: grid.length,
                columns: columns,
                size: _slotSize(context, normal: 44),
                stackAt: (i) => grid[i],
                onTap: (i) => dispatch(ClickSlot(GridSlotRef(i))),
                onSplit: (i) =>
                    dispatch(ClickSlot(GridSlotRef(i), kind: ClickKind.split)),
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
                onTap: () => dispatch(const ClickSlot(CraftResultRef())),
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
          const InventoryPanel(),
          SizedBox(height: _isCompact(context) ? 6 : 10),
          const CursorPanel(),
        ],
      ),
    );
  }
}

/// The furnace: what goes in, what burns and what comes out.
class FurnaceScreen extends ConsumerWidget {
  const FurnaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final furnace = ref.watch(furnaceProvider);
    if (furnace == null) return const SizedBox.shrink();

    final image = ref.watch(atlasImageProvider);
    final dispatch = ref.watch(dispatchProvider);

    void click(FurnaceSlot slot, {bool split = false}) => dispatch(
      ClickSlot(
        FurnaceSlotRef(slot),
        kind: split ? ClickKind.split : ClickKind.primary,
      ),
    );

    return ScreenFrame(
      title: context.t.screenFurnace,
      showRecipes: true,
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
                    stack: furnace.input,
                    size: 46,
                    onTap: () => click(FurnaceSlot.input),
                    onSplit: () => click(FurnaceSlot.input, split: true),
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
                      color: furnace.isLit
                          ? Color.lerp(
                              Colors.deepOrange,
                              Colors.amber,
                              furnace.fuelFraction,
                            )
                          : Colors.white12,
                    ),
                  ),
                  ItemSlot(
                    image: image,
                    stack: furnace.fuel,
                    size: 46,
                    highlight: furnace.isLit ? Colors.orangeAccent : null,
                    onTap: () => click(FurnaceSlot.fuel),
                    onSplit: () => click(FurnaceSlot.fuel, split: true),
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
                        value: furnace.progress.clamp(0.0, 1.0),
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
                stack: furnace.output,
                size: 52,
                highlight: Colors.lightGreenAccent,
                onTap: () => click(FurnaceSlot.output),
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
          const InventoryPanel(),
          SizedBox(height: _isCompact(context) ? 6 : 10),
          const CursorPanel(),
        ],
      ),
    );
  }
}

/// Shown when the player has died.
class DeathScreen extends ConsumerWidget {
  const DeathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                onPressed: () => ref.read(dispatchProvider)(const Respawn()),
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

/// The recipe book: what is made from what.
class RecipeScreen extends ConsumerWidget {
  const RecipeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ScreenFrame(
    title: context.t.screenRecipes,
    child: RecipeBook(
      image: ref.watch(atlasImageProvider),
      inventory: ref.watch(inventoryProvider),
    ),
  );
}
