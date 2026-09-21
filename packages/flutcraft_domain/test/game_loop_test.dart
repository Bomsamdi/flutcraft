import 'dart:math';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

/// The whole game without a GPU: world, player, inventory and loop.
({GameLoop loop, GameState state}) newGame({int size = 32}) {
  final world = VoxelWorld(sizeX: size, sizeY: 16, sizeZ: size);
  for (var z = 0; z < size; z++) {
    for (var x = 0; x < size; x++) {
      world.setRaw(x, 0, z, BlockType.bedrock);
      world.setRaw(x, 1, z, BlockType.stone);
    }
  }
  final state = GameState.solo(
    world: world,
    player: Player(world: world, spawn: Vector3(16.5, 2, 16.5)),
    inventory: Inventory(),
  );
  final loop = GameLoop(
    state: state,
    spawner: MobSpawner(world: world, seed: 1, maxMobs: 0),
    random: Random(1),
  );
  return (loop: loop, state: state);
}

void main() {
  group('GameLoop tyka bez GPU', () {
    test('a thousand frames run without throwing', () {
      final game = newGame();
      for (var i = 0; i < 1000; i++) {
        game.loop.tickSolo(1 / 60, InputFrame.idle);
      }
      expect(game.state.solo.player.position.y, greaterThan(0));
    });

    test('gracz spada na teren', () {
      final game = newGame();
      game.state.solo.player.position.setValues(16.5, 10, 16.5);
      for (var i = 0; i < 300; i++) {
        game.loop.tickSolo(1 / 60, InputFrame.idle);
      }
      expect(game.state.solo.player.position.y, closeTo(2, 0.1));
    });

    test('an open screen freezes the world', () {
      final game = newGame();
      game.state.solo.player.position.setValues(16.5, 10, 16.5);
      game.loop.dispatchSolo(const OpenRoute(UiRoute.inventory));

      for (var i = 0; i < 300; i++) {
        game.loop.tickSolo(1 / 60, InputFrame.idle);
      }
      expect(game.state.solo.player.position.y, 10, reason: 'it did not fall');
    });

    test('the player dying switches the route', () {
      final game = newGame();
      game.state.solo.player.damage(100);
      game.loop.tickSolo(1 / 60, InputFrame.idle);
      expect(game.state.solo.route, UiRoute.dead);
    });
  });

  group('Komendy', () {
    test('selecting a slot changes the held item', () {
      final game = newGame();
      game.state.solo.inventory
        ..add(ItemType.planks, 5)
        ..add(ItemType.coal, 5);

      expect(game.state.solo.heldItem, ItemType.planks);
      game.loop.dispatchSolo(const SelectHotbarSlot(1));
      expect(game.state.solo.heldItem, ItemType.coal);
    });

    test('out of range the slot does not change', () {
      final game = newGame();
      game.loop.dispatchSolo(const SelectHotbarSlot(99));
      expect(game.state.solo.selectedSlot, 0);
    });

    test('scrolling wraps around the ends of the hotbar', () {
      final game = newGame();
      game.loop.dispatchSolo(const CycleHotbarSlot(-1));
      expect(
        game.state.solo.selectedSlot,
        game.state.solo.inventory.hotbarSize - 1,
      );
    });

    test('moving an item through the cursor', () {
      final game = newGame();
      game.state.solo.inventory.add(ItemType.planks, 5);

      game.loop.dispatchSolo(const ClickSlot(InventorySlotRef(0)));
      expect(game.state.solo.cursor?.count, 5);
      expect(game.state.solo.inventory[0], isNull);

      game.loop.dispatchSolo(const ClickSlot(InventorySlotRef(3)));
      expect(game.state.solo.cursor, isNull);
      expect(game.state.solo.inventory[3]?.count, 5);
    });

    test('a split click takes half', () {
      final game = newGame();
      game.state.solo.inventory.add(ItemType.planks, 8);

      game.loop.dispatchSolo(
        const ClickSlot(InventorySlotRef(0), kind: ClickKind.split),
      );
      expect(game.state.solo.cursor?.count, 4);
      expect(game.state.solo.inventory[0]?.count, 4);
    });

    test('closing a screen gives the grid contents back', () {
      final game = newGame();
      game.loop.dispatchSolo(const OpenRoute(UiRoute.inventory));
      game.state.solo.activeGrid[0] = const ItemStack(ItemType.log, 3);
      game.state.solo.cursor = const ItemStack(ItemType.coal, 2);

      game.loop.dispatchSolo(const CloseRoute());

      expect(game.state.solo.activeGrid.isEmpty, isTrue);
      expect(game.state.solo.cursor, isNull);
      expect(game.state.solo.inventory.countOf(ItemType.log), 3);
      expect(game.state.solo.inventory.countOf(ItemType.coal), 2);
    });

    test('crafting: a log gives four planks', () {
      final game = newGame();
      game.loop.dispatchSolo(const OpenRoute(UiRoute.inventory));
      game.state.solo.activeGrid[0] = const ItemStack(ItemType.log, 2);

      game.loop.dispatchSolo(const ClickSlot(CraftResultRef()));

      expect(game.state.solo.cursor?.type, ItemType.planks);
      expect(game.state.solo.cursor?.count, 4);
      expect(
        game.state.solo.activeGrid[0]?.count,
        1,
        reason: 'one was consumed',
      );
    });

    test('the book returns to wherever it was opened from', () {
      final game = newGame();
      game.loop.dispatchSolo(const OpenRoute(UiRoute.craftingTable));
      game.state.solo.activeGrid[0] = const ItemStack(ItemType.planks, 4);

      game.loop.dispatchSolo(const OpenRecipes());
      expect(game.state.solo.route, UiRoute.recipes);

      game.loop.dispatchSolo(const CloseRoute());
      expect(game.state.solo.route, UiRoute.craftingTable);
      expect(
        game.state.solo.activeGrid[0]?.count,
        4,
        reason: 'a glance at the book does not disturb the grid',
      );
    });

    test('flight toggles and reports an event', () {
      final game = newGame();
      final events = game.loop.dispatchSolo(const ToggleFlight());
      expect(game.state.solo.player.flying, isTrue);
      expect(events.single, isA<FlightToggled>());
    });

    test('respawning heals the player and clears the mobs', () {
      final game = newGame();
      game.state.mobs.add(
        Mob(
          kind: MobKind.zombie,
          world: game.state.world,
          spawn: Vector3(16.5, 2, 14.5),
        ),
      );
      game.state.solo.player.damage(100);

      final events = game.loop.dispatchSolo(const Respawn());

      expect(game.state.solo.player.health, Player.maxHealth);
      expect(game.state.mobs, isEmpty);
      expect(game.state.solo.route, UiRoute.none);
      expect(events.single, isA<PlayerRespawned>());
    });

    test('using a table opens the 3x3 crafting screen', () {
      final game = newGame();
      // The table sits at eye level, so the ray hits it.
      game.state.world.setBlock(16, 3, 14, BlockType.craftingTable);
      game.state.solo.player.yaw = 0; // patrzy w -Z
      game.loop.tickSolo(1 / 60, InputFrame.idle);

      game.loop.dispatchSolo(const UseOrPlace());

      expect(game.state.solo.route, UiRoute.craftingTable);
      expect(game.state.solo.activeGrid.size, 3);
    });

    test('using an ordinary block places the held one', () {
      final game = newGame();
      game.state.solo.inventory.add(ItemType.planks, 4);
      game.state.solo.player
        ..yaw = 0
        ..pitch = -1.2;
      game.loop.tickSolo(1 / 60, InputFrame.idle);

      game.loop.dispatchSolo(const UseOrPlace());

      expect(game.state.solo.inventory.countOf(ItemType.planks), 3);
    });
  });
}
