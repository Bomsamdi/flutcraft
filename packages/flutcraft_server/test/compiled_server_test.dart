import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_protocol/flutcraft_protocol.dart';
import 'package:test/test.dart';

/// The same world, run as the artefact that actually ships.
///
/// Worth its own test because AOT is not a faster JIT: asserts are compiled
/// out, so anything the server relies on an `assert` to catch does not exist
/// in the binary, and timings taken under `dart run` say nothing about it.
///
/// Set FLUTCRAFT_SERVER to a compiled binary to run this; skipped otherwise,
/// so `dart test` stays useful on a machine that has not built one.
void main() {
  final binary = Platform.environment['FLUTCRAFT_SERVER'];

  test(
    'two clients play in a world run by the compiled binary',
    () async {
      const codec = JsonMessageCodec();
      final process = await Process.start(binary!, ['--port', '8801']);
      addTearDown(process.kill);

      final ready = Completer<void>();
      process.stdout.transform(utf8.decoder).listen((line) {
        if (line.contains('Flutcraft on port') && !ready.isCompleted) {
          ready.complete();
        }
      });
      await ready.future.timeout(const Duration(seconds: 10));

      final alice = await WebSocket.connect('ws://127.0.0.1:8801');
      final bob = await WebSocket.connect('ws://127.0.0.1:8801');
      addTearDown(alice.close);
      addTearDown(bob.close);

      var welcomeBytes = 0;
      var sawHerMove = false;
      final welcomed = Completer<void>();
      bob.listen((raw) {
        final bytes = raw is Uint8List
            ? raw
            : Uint8List.fromList(raw as List<int>);
        final message = codec.decodeServer(bytes);
        if (message is Welcome) {
          welcomeBytes = bytes.length;
          if (!welcomed.isCompleted) welcomed.complete();
        }
        if (message is PlayerStates) {
          final her = message.players
              .where((p) => p.id == const PlayerId('alice'))
              .firstOrNull;
          if (her != null && her.position.length > 0.5) sawHerMove = true;
        }
      });

      alice.add(codec.encodeClient(const SignUp('alice', 'open sesame')));
      bob.add(codec.encodeClient(const SignUp('bob', 'open sesame')));

      // Waiting a fixed moment here would be guessing. Registering runs a
      // deliberately slow hash — about a second and a half of it — so the
      // test waits for the welcome that says it is over.
      await welcomed.future.timeout(const Duration(seconds: 30));

      for (var i = 0; i < 120 && !sawHerMove; i++) {
        alice.add(
          codec.encodeClient(
            InputTick(
              i,
              const InputFrame(forward: 1, held: {GameAction.moveForward}),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }

      expect(sawHerMove, isTrue, reason: 'Bob never saw Alice move');
      expect(welcomeBytes, greaterThan(0));
      // A whole world, on a wire, in less than a kilobyte.
      expect(welcomeBytes, lessThan(1024));
    },
    skip: binary == null ? 'set FLUTCRAFT_SERVER to a compiled binary' : null,
  );
}
