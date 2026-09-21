/// What a mob or an arrow is called on the wire.
///
/// An extension type over an int, so it costs nothing at run time and cannot
/// be mixed up with a count, a slot index or a tick number.
///
/// Deliberately *not* used for equality. Mobs and arrows compare by
/// identity, because the renderer keeps a component per entity in a map keyed
/// by the object itself: two zombies standing on the same square with the
/// same health would collapse into one component the moment equality became
/// a question of values, and one of them would silently vanish.
extension type const EntityId(int value) {}
