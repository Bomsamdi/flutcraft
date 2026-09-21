/// The rectangle of one tile inside the atlas, in texture coordinates.
class TileUv {
  const TileUv(this.u0, this.v0, this.u1, this.v1);

  final double u0;
  final double v0;
  final double u1;
  final double v1;
}
