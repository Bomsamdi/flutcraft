/// Who a piece of state, or a killing blow, belongs to.
///
/// An extension type rather than a bare `String`: it costs nothing at run
/// time and makes it impossible to pass a block name, a save slot or any
/// other string where a player was meant.
///
/// Lives beside the player rather than in the session layer because a mob has
/// to be able to remember who hit it without knowing what a session is.
extension type const PlayerId(String value) {}
