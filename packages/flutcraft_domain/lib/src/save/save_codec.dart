import 'dart:convert';
import 'dart:typed_data';

import '../actors/player_id.dart';
import '../blocks/block_pos.dart';
import '../blocks/block_type.dart';
import '../items/item_type.dart';
import 'save_data.dart';

/// Turns a [SaveData] into bytes and back.
///
/// Enums are written by name, never by index. An index is the same trap as a
/// packed block key: reordering `ItemType` would silently turn every pickaxe
/// in every save into sand, with nothing failing to compile.
///
/// The world and the players are separate documents, so a server can rewrite
/// `world.json` on its own schedule and touch a player's file only when that
/// player does something. A single-player game puts both in one file.
class SaveCodec {
  const SaveCodec();

  /// Bump when the shape changes, and read the old one below.
  ///
  /// Version 2 replaced the single player with a roster.
  static const int currentVersion = 2;

  /// Bump when terrain generation changes, which invalidates edits that were
  /// recorded against the old terrain.
  static const int terrainVersion = 1;

  /// The id a version 1 save's only player is given.
  ///
  /// It had none — there was nobody to tell it apart from.
  static const PlayerId legacyPlayer = PlayerId('solo');

  Uint8List encode(SaveData data) => utf8.encode(json.encode(toJson(data)));

  Map<String, Object?> toJson(SaveData data) => {
    'version': currentVersion,
    'terrainVersion': terrainVersion,
    'savedAt': (data.savedAt ?? DateTime.now()).toUtc().toIso8601String(),
    'world': worldToJson(data.world),
    'players': [for (final player in data.players) playerToJson(player)],
  };

  /// A world on its own — what a server rewrites when it autosaves.
  Map<String, Object?> worldToJson(WorldSave world) => {
    'seed': world.seed,
    'edits': [
      for (final entry in world.edits.entries)
        {
          'p': [entry.key.x, entry.key.y, entry.key.z],
          'b': entry.value.name,
        },
    ],
    'furnaces': [
      for (final furnace in world.furnaces)
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

  /// One player on their own — what a server writes when that player leaves.
  Map<String, Object?> playerToJson(PlayerSave player) => {
    'id': player.id.value,
    'pos': [player.x, player.y, player.z],
    'yaw': player.yaw,
    'pitch': player.pitch,
    'health': player.health,
    'flying': player.flying,
    'selected': player.selectedSlot,
    'inventory': [for (final stack in player.inventory) _stackToJson(stack)],
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
    final savedAt = DateTime.tryParse(raw['savedAt'] as String? ?? '');

    // Version 1 kept the world and its one player flat in the same map.
    final worldRaw = raw['world'] as Map<String, Object?>? ?? raw;
    final playersRaw = raw['players'] as List? ?? [raw];

    return LoadResult(
      SaveData(
        world: worldFromJson(worldRaw, warnings),
        players: [
          for (final entry in playersRaw)
            playerFromJson(entry as Map<String, Object?>, warnings),
        ],
        savedAt: savedAt,
      ),
      warnings,
    );
  }

  /// Reads a world document.
  WorldSave worldFromJson(
    Map<String, Object?> raw,
    List<SaveWarning> warnings,
  ) {
    final edits = <BlockPos, BlockType>{};
    for (final entry in (raw['edits'] as List? ?? const [])) {
      final map = entry as Map<String, Object?>;
      final block = _blockByName(map['b'] as String?, warnings);
      if (block == null) continue;
      final pos = (map['p'] as List).cast<int>();
      edits[BlockPos(pos[0], pos[1], pos[2])] = block;
    }

    return WorldSave(
      seed: raw['seed'] as int? ?? 0,
      edits: edits,
      furnaces: [
        for (final entry in (raw['furnaces'] as List? ?? const []))
          _furnaceFromJson(entry as Map<String, Object?>, warnings),
      ],
    );
  }

  /// Reads a player document.
  ///
  /// A version 1 save has no id; its only player becomes [legacyPlayer], so
  /// an old world opens with the inventory it was left with.
  PlayerSave playerFromJson(
    Map<String, Object?> raw,
    List<SaveWarning> warnings,
  ) {
    final flat = raw['player'] as Map<String, Object?>?;
    final body = flat ?? raw;
    final position = (body['pos'] as List? ?? const [0, 0, 0])
        .cast<num>()
        .map((n) => n.toDouble())
        .toList();

    return PlayerSave(
      id: PlayerId(raw['id'] as String? ?? legacyPlayer.value),
      x: position[0],
      y: position[1],
      z: position[2],
      yaw: (body['yaw'] as num? ?? 0).toDouble(),
      pitch: (body['pitch'] as num? ?? 0).toDouble(),
      health: body['health'] as int? ?? 20,
      flying: body['flying'] as bool? ?? false,
      selectedSlot: raw['selected'] as int? ?? 0,
      inventory: [
        for (final entry in (raw['inventory'] as List? ?? const []))
          _stackFromJson(entry as Map<String, Object?>?, warnings),
      ],
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
