// Runs a Flutcraft world and lets clients play in it.
//
// Usage: flutcraft_server [--port 8787] [--seed 1337] [--world <directory>]
//
// Without --world the server keeps everything in memory and forgets it when
// it stops, which is what a test wants and never what a real one does.
import 'dart:async';
import 'dart:io';

import 'package:flutcraft_server/flutcraft_server.dart';

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  final store = options.world == null
      ? null
      : WorldStore(Directory(options.world!));
  final host = store == null
      ? GameHost.newWorld(seed: options.seed)
      : GameHost.fromStore(store, seed: options.seed);
  // Accounts live beside the world. A world nobody keeps has no business
  // keeping the passwords that went with it, so in memory they go together.
  final accounts = options.world == null
      ? AccountStore.inMemory()
      : AccountStore.inDirectory(Directory(options.world!));
  final server = WebSocketHost(host, accounts: accounts);

  await server.start(address: InternetAddress.anyIPv4, port: options.port);
  stdout.writeln(
    'Flutcraft on port ${server.port}, world ${host.state.world.seed}'
    '${store == null ? ' (in memory)' : ' in ${options.world}'}, '
    '${accounts.names.length} account(s)',
  );

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
  // A container stops with a signal, so this is the only chance to write the
  // world down. Without it, the last minute of everybody's building is gone.
  host.saveNow();
  stdout.writeln('World written down.');
}

/// The few knobs a server has.
class _Options {
  const _Options({required this.port, required this.seed, this.world});

  factory _Options.parse(List<String> arguments) {
    var port = 8787;
    var seed = 1337;
    String? world;

    for (var i = 0; i + 1 < arguments.length; i += 2) {
      final value = arguments[i + 1];
      switch (arguments[i]) {
        case '--port':
          port = int.tryParse(value) ?? port;
        case '--seed':
          seed = int.tryParse(value) ?? seed;
        case '--world':
          world = value;
      }
    }
    return _Options(port: port, seed: seed, world: world);
  }

  final int port;
  final int seed;

  /// Where to keep the world, or `null` to keep it only in memory.
  final String? world;
}
