import 'dart:math';

import '../blocks/block_type.dart';
import '../items/item_type.dart';
import 'loot_table.dart';

/// What each block drops when mined.
///
/// Kept beside the block table rather than inside [BlockType] because item
/// types already point back at block types; a field here would make the two
/// enums reference each other during constant initialisation.
final Map<BlockType, LootTable> kBlockLoot = {
  // Stone family yields its cooked/broken form, exactly like the original.
  BlockType.stone: LootTable.single(ItemType.cobblestone),
  BlockType.grass: LootTable.single(ItemType.dirt),
  BlockType.coalOre: LootTable.single(ItemType.coal),
  BlockType.ironOre: LootTable.single(ItemType.rawIron),
  BlockType.furnaceLit: LootTable.single(ItemType.furnace),
  // Leaves and bedrock deliberately drop nothing.
  BlockType.leaves: LootTable.empty,
  BlockType.bedrock: LootTable.empty,
  BlockType.air: LootTable.empty,
};

/// What [block] drops when broken while holding [heldItem].
///
/// Returns an empty list when the tool is too weak — mining stone bare-handed
/// destroys it without a drop, as in the original.
List<ItemStack> blockDrops(BlockType block, ItemType? heldItem, Random rng) {
  final tier = heldItem?.tool == ToolType.pickaxe ? heldItem!.tier : 0;
  if (block.requiredTier > tier) return const [];

  final table =
      kBlockLoot[block] ??
      switch (ItemType.forBlock(block)) {
        final item? => LootTable.single(item),
        _ => LootTable.empty,
      };
  return table.roll(rng);
}
