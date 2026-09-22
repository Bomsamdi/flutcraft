import 'package:flutcraft_l10n/flutcraft_l10n.dart';
import 'package:flutcraft_protocol/flutcraft_protocol.dart';
import 'package:flutter/material.dart';

/// What the sign-in screen hands back when somebody presses a button.
///
/// The screen collects an address and a pair of credentials and knows nothing
/// about sockets: what to do with this belongs to whoever composed the app.
final class SignInAttempt {
  const SignInAttempt({required this.address, required this.credentials});

  final String address;
  final Credentials credentials;
}

/// Why an attempt did not work, in the server's own words or the client's.
///
/// A [KickReason] is what the server said; [unreachable] is what it looks
/// like when there was nobody there to say anything.
final class SignInProblem {
  const SignInProblem.refused(KickReason this.reason);
  const SignInProblem.unreachable() : reason = null;

  final KickReason? reason;

  String describe(GameStrings strings, AppLocalizations t) =>
      reason == null ? t.signInUnreachable : strings.kickReason(reason!);
}

/// Where a player says who they are before the world appears.
///
/// This exists because the alternative was a compile-time define: the name
/// was baked into the binary, so two people on one machine meant two builds
/// of the same game. A text field does the same job and does not need a
/// toolchain.
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    required this.onAttempt,
    this.address = '',
    this.name = '',
    this.onPlayOffline,
    super.key,
  });

  /// Tries to join. Returns the problem, or null when the world is coming.
  final Future<SignInProblem?> Function(SignInAttempt) onAttempt;

  /// What the fields start with — the last server and name that worked.
  final String address;
  final String name;

  /// Offered only where there is a local world to play; a build that can only
  /// join a server does not pass one.
  final VoidCallback? onPlayOffline;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late final TextEditingController _address = TextEditingController(
    text: widget.address,
  );
  late final TextEditingController _name = TextEditingController(
    text: widget.name,
  );
  final TextEditingController _secret = TextEditingController();

  bool _busy = false;
  SignInProblem? _problem;

  @override
  void dispose() {
    _address.dispose();
    _name.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _attempt({required bool registering}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _problem = null;
    });

    final name = _name.text.trim();
    final secret = _secret.text;
    final problem = await widget.onAttempt(
      SignInAttempt(
        address: _address.text.trim(),
        credentials: registering
            ? Credentials.registering(name: name, secret: secret)
            : Credentials.signingIn(name: name, secret: secret),
      ),
    );

    // The widget is gone the moment a sign-in works, because the game takes
    // its place; setting state on it then would throw.
    if (!mounted) return;
    setState(() {
      _busy = false;
      _problem = problem;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final problem = _problem;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.signInHeading,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _address,
                  enabled: !_busy,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: t.signInServer,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  enabled: !_busy,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: t.signInName,
                    helperText: t.signInNameHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _secret,
                  enabled: !_busy,
                  obscureText: true,
                  autocorrect: false,
                  onSubmitted: (_) => _attempt(registering: false),
                  decoration: InputDecoration(
                    labelText: t.signInSecret,
                    helperText: t.signInSecretHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                if (problem != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      problem.describe(context.strings, t),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                FilledButton(
                  onPressed: _busy ? null : () => _attempt(registering: false),
                  child: Text(_busy ? t.signInWorking : t.signInButton),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => _attempt(registering: true),
                  child: Text(t.signUpButton),
                ),
                if (widget.onPlayOffline case final offline?) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : offline,
                    child: Text(t.signInOffline),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
