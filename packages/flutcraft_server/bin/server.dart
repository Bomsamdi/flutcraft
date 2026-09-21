// Runs a Flutcraft world and lets clients play in it.
//
// Usage: flutcraft_server [--port 8787] [--seed 1337] [--world <directory>]
import 'dart:async';
import 'dart:io';

import 'package:flutcraft_server/flutcraft_server.dart';

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  final host = GameHost.newWorld(seed: options.seed);
  final server = WebSocketHost(host);

  await server.start(address: InternetAddress.anyIPv4, port: options.port);
  stdout.writeln('Flutcraft on port ${server.port}, world ${options.seed}');

  // A container stops a process with SIGTERM; shutting down cleanly is what
  // makes the difference between a saved world and a lost one.
  final stopping = Completer<void>();
  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    signal.watch().listen((_) {
      if (!stopping.isCompleted) stopping.complete();
    });
  }
  await stopping.future;
  stdout.writeln('Stopping.');
  await server.stop();
}

/// The few knobs a server has.
class _Options {
  const _Options({required this.port, required this.seed});

  factory _Options.parse(List<String> arguments) {
    var port = 8787;
    var seed = 1337;
    for (var i = 0; i + 1 < arguments.length; i += 2) {
      final value = int.tryParse(arguments[i + 1]);
      if (value == null) continue;
      if (arguments[i] == '--port') port = value;
      if (arguments[i] == '--seed') seed = value;
    }
    return _Options(port: port, seed: seed);
  }

  final int port;
  final int seed;
}
