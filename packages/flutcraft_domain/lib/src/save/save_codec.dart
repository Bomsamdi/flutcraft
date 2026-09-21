import 'dart:convert';
import 'dart:typed_data';

import '../blocks/block_pos.dart';
import '../blocks/block_type.dart';
import '../items/item_type.dart';
import 'save_data.dart';

/// Turns a [SaveData] into bytes and back.
///
/// Enums are written by name, never by index. An index is the same trap as a
/// packed block key: reordering `ItemType` would silently turn every pickaxe
/// in every save into sand, with nothing failing to compile.
class SaveCodec {
  const SaveCodec();

  /// Bump when the shape changes, and add a migration for the old one.
  static const int currentVersion = 1;

  /// Bump when terrain generation changes, which invalidates edits that were
  /// recorded against the old terrain.
  static const int terrainVersion = 1;

  Uint8List encode(SaveData data) => utf8.encode(json.encode(toJson(data)));

  Map<String, Object?> toJson(SaveData data) => {
    'version': currentVersion,
    'terrainVersion': terrainVersion,
    'savedAt': (data.savedAt ?? DateTime.now()).toUtc().toIso8601String(),
    'seed': data.seed,
    'edits': [
      for (final entry in data.edits.entries)
        {
          'p': [entry.key.x, entry.key.y, entry.key.z],
          'b': entry.value.name,
        },
    ],
    'player': {
      'pos': [data.player.x, data.player.y, data.player.z],
      'yaw': data.player.yaw,
      'pitch': data.player.pitch,
      'health': data.player.health,
      'flying': data.player.flying,
    },
    'selected': data.selectedSlot,
    'inventory': [for (final stack in data.inventory) _stackToJson(stack)],
    'furnaces': [
      for (final furnace in data.furnaces)
        {
          'p': [furnace.pos.x, furnace.pos.y, furnace.pos.z],
          'in': _stackToJson(furnace.input),
          'fuel': _stackToJson(furnace.fuel),
          'out': _stackToJson(furnace.output),
          'burnLeft': furnace.burnLeft,
          'burnTotal': furnace.burnTotal,
          'progress': furnace.progress,
        },
    ],
  };

  LoadResult decode(Uint8List bytes) =>
      fromJson(json.decode(utf8.decode(bytes)) as Map<String, Object?>);

  /// Reads a save tolerantly: an unknown item or block is skipped with a
  /// warning rather than throwing away the whole world.
  LoadResult fromJson(Map<String, Object?> raw) {
    final version = raw['version'] as int? ?? 0;
    if (version > currentVersion) {
      throw SaveTooNewException(version, currentVersion);
    }

    final warnings = <SaveWarning>[];
    final edits = <BlockPos, BlockType>{};
    for (final entry in (raw['edits'] as List? ?? const [])) {
      final map = entry as Map<String, Object?>;
      final block = _blockByName(map['b'] as String?, warnings);
      if (block == null) continue;
      final pos = (map['p'] as List).cast<int>();
      edits[BlockPos(pos[0], pos[1], pos[2])] = block;
    }

    final player = raw['player'] as Map<String, Object?>? ?? const {};
    final position = (player['pos'] as List? ?? const [0, 0, 0])
        .cast<num>()
        .map((n) => n.toDouble())
        .toList();

    return LoadResult(
      SaveData(
        seed: raw['seed'] as int? ?? 0,
        edits: edits,
        player: SavedPlayer(
          x: position[0],
          y: position[1],
          z: position[2],
          yaw: (player['yaw'] as num? ?? 0).toDouble(),
          pitch: (player['pitch'] as num? ?? 0).toDouble(),
          health: player['health'] as int? ?? 20,
          flying: player['flying'] as bool? ?? false,
        ),
        inventory: [
          for (final entry in (raw['inventory'] as List? ?? const []))
            _stackFromJson(entry as Map<String, Object?>?, warnings),
        ],
        selectedSlot: raw['selected'] as int? ?? 0,
        furnaces: [
          for (final entry in (raw['furnaces'] as List? ?? const []))
            _furnaceFromJson(entry as Map<String, Object?>, warnings),
        ],
        savedAt: DateTime.tryParse(raw['savedAt'] as String? ?? ''),
      ),
      warnings,
    );
  }

  Map<String, Object?>? _stackToJson(ItemStack? stack) =>
      stack == null ? null : {'item': stack.type.name, 'count': stack.count};

  ItemStack? _stackFromJson(
    Map<String, Object?>? raw,
    List<SaveWarning> warnings,
  ) {
    if (raw == null) return null;
    final name = raw['item'] as String?;
    final item = ItemType.values.where((i) => i.name == name).firstOrNull;
    if (item == null) {
      warnings.add(SaveWarning('Unknown item "$name" was dropped'));
      return null;
    }
    return ItemStack(item, raw['count'] as int? ?? 1);
  }

  SavedFurnace _furnaceFromJson(
    Map<String, Object?> raw,
    List<SaveWarning> warnings,
  ) {
    final pos = (raw['p'] as List).cast<int>();
    return SavedFurnace(
      pos: BlockPos(pos[0], pos[1], pos[2]),
      input: _stackFromJson(raw['in'] as Map<String, Object?>?, warnings),
      fuel: _stackFromJson(raw['fuel'] as Map<String, Object?>?, warnings),
      output: _stackFromJson(raw['out'] as Map<String, Object?>?, warnings),
      burnLeft: (raw['burnLeft'] as num? ?? 0).toDouble(),
      burnTotal: (raw['burnTotal'] as num? ?? 0).toDouble(),
      progress: (raw['progress'] as num? ?? 0).toDouble(),
    );
  }

  BlockType? _blockByName(String? name, List<SaveWarning> warnings) {
    final block = BlockType.values.where((b) => b.name == name).firstOrNull;
    if (block == null) {
      warnings.add(SaveWarning('Unknown block "$name" was skipped'));
    }
    return block;
  }
}
