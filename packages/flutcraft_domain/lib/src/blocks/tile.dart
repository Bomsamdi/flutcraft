/// Pojedyncze kafelki 16x16 px w proceduralnym atlasie tekstur.
///
/// The order sets the column layout in the atlas, so do not change it
/// bez regeneracji [TextureAtlas].
enum Tile {
  // --- bloki ---
  grassTop,
  grassSide,
  dirt,
  stone,
  cobblestone,
  sand,
  gravel,
  logSide,
  logTop,
  leaves,
  planks,
  bedrock,
  coalOre,
  ironOre,
  brick,
  craftingTableTop,
  craftingTableSide,
  furnaceTop,
  furnaceSide,
  furnaceFront,
  furnaceFrontLit,

  // --- materials for the 3D models ---
  metal,
  handle,

  // --- material icons ---
  stickIcon,
  coalIcon,
  rawIronIcon,
  ironIngotIcon,
  boneIcon,
  stringIcon,
  gunpowderIcon,
  arrowIcon,

  // --- tool icons ---
  woodPickIcon,
  stonePickIcon,
  ironPickIcon,
  woodSwordIcon,
  stoneSwordIcon,
  ironSwordIcon,

  // --- mob skins ---
  zombieSkin,
  zombieFace,
  skeletonSkin,
  skeletonFace,
  spiderSkin,
  spiderFace,
  creeperSkin,
  creeperFace,
}

/// Shading levels baked into the atlas instead of computed in a shader.
/// That is what lets the world render with an unlit material and one draw call
/// na chunk.
enum Shade {
  /// The top of a block: full brightness.
  top(1.0),

  /// Faces along Z.
  sideZ(0.86),

  /// Faces along X, slightly darker so the shape reads.
  sideX(0.70),

  /// The bottom of a block.
  bottom(0.52);

  const Shade(this.factor);

  final double factor;
}
