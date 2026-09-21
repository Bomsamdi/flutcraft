import 'block_type.dart';

/// What happens when the player uses a block.
///
/// A sealed type rather than a callback so the UI layer can decide how to
/// present each interaction without the domain knowing about screens.
sealed class BlockInteraction {
  const BlockInteraction();
}

/// Opens the 3x3 crafting grid.
final class OpenCraftingTable extends BlockInteraction {
  const OpenCraftingTable();
}

/// Opens the furnace at the block that was used.
final class OpenFurnace extends BlockInteraction {
  const OpenFurnace();
}

/// Which blocks react to being used, and how.
///
/// Replaces a chain of identity comparisons on [BlockType]. Adding an
/// interactive block is now an entry in this table, not an edit to a getter
/// that every block type shares.
class BlockRegistry {
  const BlockRegistry(this._interactions);

  final Map<BlockType, BlockInteraction> _interactions;

  static const standard = BlockRegistry({
    BlockType.craftingTable: OpenCraftingTable(),
    BlockType.furnace: OpenFurnace(),
    BlockType.furnaceLit: OpenFurnace(),
  });

  BlockInteraction? interactionFor(BlockType block) => _interactions[block];

  bool isInteractive(BlockType block) => _interactions.containsKey(block);
}
