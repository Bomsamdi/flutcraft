/// Pojedyncze kafelki 16x16 px w proceduralnym atlasie tekstur.
///
/// Kolejność wyznacza układ kolumn w atlasie, więc nie zmieniaj jej
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

  // --- materiały modeli 3D ---
  metal,
  handle,

  // --- ikony surowców ---
  stickIcon,
  coalIcon,
  rawIronIcon,
  ironIngotIcon,
  boneIcon,
  stringIcon,
  gunpowderIcon,
  arrowIcon,

  // --- ikony narzędzi ---
  woodPickIcon,
  stonePickIcon,
  ironPickIcon,
  woodSwordIcon,
  stoneSwordIcon,
  ironSwordIcon,

  // --- skóry potworów ---
  zombieSkin,
  zombieFace,
  skeletonSkin,
  skeletonFace,
  spiderSkin,
  spiderFace,
  creeperSkin,
  creeperFace,
}

/// Poziomy przyciemnienia wypalone w atlasie (zamiast liczenia światła
/// w shaderze). Dzięki temu wystarczy [UnlitMaterial] i jeden draw call
/// na chunk.
enum Shade {
  /// Góra bloku - pełna jasność.
  top(1.0),

  /// Ściany wzdłuż osi Z.
  sideZ(0.86),

  /// Ściany wzdłuż osi X - nieco ciemniejsze, żeby czytać bryłę.
  sideX(0.70),

  /// Spód bloku.
  bottom(0.52);

  const Shade(this.factor);

  final double factor;
}
