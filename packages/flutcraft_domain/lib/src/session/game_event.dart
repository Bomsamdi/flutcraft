import '../actors/mob.dart';
import '../blocks/block_pos.dart';
import '../blocks/block_type.dart';
import '../items/item_type.dart';

/// Something worth telling the player about.
///
/// Events carry data, never text. The simulation has no `BuildContext` and
/// no business knowing which language the player reads — it says *what*
/// happened and the presentation layer decides how to word it. This is also
/// what makes the domain testable without a localisation delegate.
sealed class GameEvent {
  const GameEvent();
}

/// A block was mined and its drops went to the inventory.
final class BlockBroken extends GameEvent {
  const BlockBroken(this.pos, this.block, this.drops);

  final BlockPos pos;
  final BlockType block;
  final List<ItemStack> drops;
}

/// The block was destroyed but the held tool was too weak to yield drops.
final class ToolTooWeak extends GameEvent {
  const ToolTooWeak(this.block);

  final BlockType block;
}

/// Something could not be picked up because there was no room.
final class InventoryFull extends GameEvent {
  const InventoryFull(this.item);

  final ItemType item;
}

/// Why a block could not be placed.
enum PlacementRejection {
  /// The selected hotbar entry is a tool or a raw material.
  notABlock,

  /// The target cell overlaps the player.
  insidePlayer,

  /// The target cell overlaps a mob.
  insideMob,
}

final class PlacementRejected extends GameEvent {
  const PlacementRejected(this.reason);

  final PlacementRejection reason;
}

final class MobKilled extends GameEvent {
  const MobKilled(this.kind, this.loot);

  final MobKind kind;
  final List<ItemStack> loot;
}

final class CreeperExploded extends GameEvent {
  const CreeperExploded();
}

final class FlightToggled extends GameEvent {
  const FlightToggled(this.enabled);

  final bool enabled;
}

final class PlayerRespawned extends GameEvent {
  const PlayerRespawned();
}

/// The game was written to storage, automatically or on request.
final class GameSaved extends GameEvent {
  const GameSaved();
}
