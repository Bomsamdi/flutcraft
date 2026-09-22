import 'messages.dart';
import 'wire_values.dart';

/// Who a client says it is, and what it offers as proof.
///
/// Carried as one value rather than two strings and a flag, because the three
/// always travel together and the pair alone does not say whether the player
/// meant to sign in or to claim the name.
final class Credentials {
  /// Somebody who already has an account here.
  const Credentials.signingIn({required this.name, required this.secret})
    : registering = false;

  /// Somebody claiming a name for the first time.
  const Credentials.registering({required this.name, required this.secret})
    : registering = true;

  final String name;
  final String secret;
  final bool registering;

  /// How this introduces itself on the wire.
  ///
  /// The credentials know which message they are, so nothing above has to
  /// branch on the flag again.
  ClientMessage get greeting =>
      registering ? SignUp(name, secret) : SignIn(name, secret);
}

/// The server said no.
///
/// Thrown rather than returned so that a refusal cannot be mistaken for a
/// session; the caller has to deal with it to get anything to play.
final class SignInRefused implements Exception {
  const SignInRefused(this.reason);

  final KickReason reason;

  @override
  String toString() => 'The server refused the sign-in: ${reason.name}';
}
