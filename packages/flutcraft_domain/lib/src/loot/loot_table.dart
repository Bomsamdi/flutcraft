import 'dart:math';

import '../items/item_type.dart';

/// One possible drop: an item, how many of it, and how likely it is.
class LootEntry {
  const LootEntry(this.type, {this.min = 1, this.max = 1, this.chance = 1.0})
    : assert(min >= 1, 'a drop of zero items is just no entry'),
      assert(max >= min, 'max must not be below min'),
      assert(chance > 0 && chance <= 1, 'chance must be within (0, 1]');

  final ItemType type;

  /// Inclusive bounds on the amount.
  final int min;
  final int max;

  /// Probability that this entry drops at all.
  final double chance;

  /// Rolls this entry; returns `null` when the chance check fails.
  ItemStack? roll(Random rng) {
    if (chance < 1 && rng.nextDouble() >= chance) return null;
    final count = min == max ? min : min + rng.nextInt(max - min + 1);
    return ItemStack(type, count);
  }
}

/// What something drops when it is destroyed.
///
/// Blocks and mobs used to have two unrelated mechanisms for the same idea —
/// a `switch` returning a single stack for blocks, another `switch` building
/// a list for mobs. One type covers both.
class LootTable {
  const LootTable(this.entries);

  /// Always drops exactly one of [type] — the common case for blocks.
  LootTable.single(ItemType type) : entries = [LootEntry(type)];

  final List<LootEntry> entries;

  /// Drops nothing at all.
  static const empty = LootTable([]);

  List<ItemStack> roll(Random rng) {
    final drops = <ItemStack>[];
    for (final entry in entries) {
      final stack = entry.roll(rng);
      if (stack != null) drops.add(stack);
    }
    return drops;
  }

  bool get isEmpty => entries.isEmpty;
}
