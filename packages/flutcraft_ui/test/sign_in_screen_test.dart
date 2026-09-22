import 'dart:async';

import 'package:flutcraft_l10n/flutcraft_l10n.dart';
import 'package:flutcraft_protocol/flutcraft_protocol.dart';
import 'package:flutcraft_ui/flutcraft_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

/// Fills the three fields in, whatever order they are laid out in.
Future<void> typeCredentials(
  WidgetTester tester, {
  String address = 'ws://127.0.0.1:8787',
  String name = 'alice',
  String secret = 'open sesame',
}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), address);
  await tester.enterText(fields.at(1), name);
  await tester.enterText(fields.at(2), secret);
}

void main() {
  group('Signing in', () {
    testWidgets('what the player typed is what gets sent', (tester) async {
      SignInAttempt? attempted;
      await tester.pumpWidget(
        wrap(
          SignInScreen(
            onAttempt: (attempt) async {
              attempted = attempt;
              return null;
            },
          ),
        ),
      );

      await typeCredentials(tester, name: 'bob');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(attempted!.address, 'ws://127.0.0.1:8787');
      expect(attempted!.credentials.name, 'bob');
      expect(attempted!.credentials.secret, 'open sesame');
      expect(
        attempted!.credentials.registering,
        isFalse,
        reason: 'the log-in button must not quietly create an account',
      );
    });

    testWidgets('the other button registers instead', (tester) async {
      SignInAttempt? attempted;
      await tester.pumpWidget(
        wrap(
          SignInScreen(
            onAttempt: (attempt) async {
              attempted = attempt;
              return null;
            },
          ),
        ),
      );

      await typeCredentials(tester);
      await tester.tap(find.byType(OutlinedButton));
      await tester.pump();

      expect(attempted!.credentials.registering, isTrue);
    });

    testWidgets('a name with spaces around it is trimmed', (tester) async {
      // A name typed with a trailing space is a name the server refuses, and
      // the player cannot see what is wrong with it.
      SignInAttempt? attempted;
      await tester.pumpWidget(
        wrap(
          SignInScreen(
            onAttempt: (attempt) async {
              attempted = attempt;
              return null;
            },
          ),
        ),
      );

      await typeCredentials(tester, name: '  alice ');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(attempted!.credentials.name, 'alice');
    });

    testWidgets('the server\'s reason is shown in the player\'s language', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SignInScreen(
            onAttempt: (_) async =>
                const SignInProblem.refused(KickReason.nameTaken),
          ),
        ),
      );

      await typeCredentials(tester);
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      // Not the enum name: the server sends a code precisely so that the
      // client is the one that picks the words.
      expect(find.textContaining('already called that'), findsOneWidget);
      expect(find.textContaining('nameTaken'), findsNothing);
    });

    testWidgets('a server that is not there says so too', (tester) async {
      await tester.pumpWidget(
        wrap(
          SignInScreen(
            onAttempt: (_) async => const SignInProblem.unreachable(),
          ),
        ),
      );

      await typeCredentials(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('No server answered'), findsOneWidget);
    });

    testWidgets('the buttons go quiet while the server is thinking', (
      tester,
    ) async {
      // Checking a secret is slow on purpose. Two taps would be two sockets
      // and two accounts' worth of hashing for one player.
      var attempts = 0;
      final answer = Completer<SignInProblem?>();
      await tester.pumpWidget(
        wrap(
          SignInScreen(
            onAttempt: (_) {
              attempts++;
              return answer.future;
            },
          ),
        ),
      );

      await typeCredentials(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(attempts, 1);

      answer.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('playing alone is offered when there is a world here', (
      tester,
    ) async {
      var offline = 0;
      await tester.pumpWidget(
        wrap(
          SignInScreen(
            onAttempt: (_) async => null,
            onPlayOffline: () => offline++,
          ),
        ),
      );

      await tester.tap(find.byType(TextButton));
      await tester.pump();

      expect(offline, 1);
    });

    testWidgets('and is not offered when there is not', (tester) async {
      await tester.pumpWidget(wrap(SignInScreen(onAttempt: (_) async => null)));

      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('the last server and name come back filled in', (tester) async {
      await tester.pumpWidget(
        wrap(
          SignInScreen(
            address: 'ws://elsewhere:8787',
            name: 'alice',
            onAttempt: (_) async => null,
          ),
        ),
      );

      expect(find.text('ws://elsewhere:8787'), findsOneWidget);
      expect(find.text('alice'), findsOneWidget);
      // The password is never one of them.
      expect(find.text('open sesame'), findsNothing);
    });
  });
}
