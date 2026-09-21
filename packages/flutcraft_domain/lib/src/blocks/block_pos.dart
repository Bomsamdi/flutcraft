import 'package:vector_math/vector_math.dart';

/// Integer coordinates of a single block in the world.
///
/// Exists so that block positions can be map keys without anyone
/// hand-rolling an index formula. Packing coordinates into an `int` and
/// unpacking them elsewhere is the kind of duplication that survives a
/// refactor and then silently misplaces data when the array layout changes.
class BlockPos {
  const BlockPos(this.x, this.y, this.z);

  /// The block containing [point]; fractional coordinates round down.
  factory BlockPos.of(Vector3 point) =>
      BlockPos(point.x.floor(), point.y.floor(), point.z.floor());

  final int x;
  final int y;
  final int z;

  /// The neighbour offset by the given deltas.
  BlockPos offset(int dx, int dy, int dz) =>
      BlockPos(x + dx, y + dy, z + dz);

  /// The centre of this block in world space.
  Vector3 get center => Vector3(x + 0.5, y + 0.5, z + 0.5);

  @override
  bool operator ==(Object other) =>
      other is BlockPos && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'BlockPos($x, $y, $z)';
}
