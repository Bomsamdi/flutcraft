import 'dart:io';

import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_protocol/flutcraft_protocol.dart';
import 'package:test/test.dart';

import 'socket_channel.dart';

/// The last claim the project makes: put up a building, restart the server,
/// and the building is still there.
///
/// Every layer below this one is already tested — `world_store_test` proves
/// the files, `end_to_end_test` proves the sockets — but none of them proves
/// the image. A wrong `ENTRYPOINT` form swallows the SIGTERM that triggers
/// the save, and a missing `VOLUME` throws the world away with the
/// container; both would pass every other test in the repository.
///
/// Set FLUTCRAFT_IMAGE to a built image to run this; skipped otherwise, so
/// `dart test` stays useful on a machine without a Docker daemon.
void main() {
  final image = Platform.environment['FLUTCRAFT_IMAGE'];

  const port = 8802;
  const name = 'flutcraft-container-test';
  const volume = 'flutcraft-container-test-world';

  Future<String> docker(List<String> arguments) async {
    final result = await Process.run('docker', arguments);
    if (result.exitCode != 0) {
      fail('docker ${arguments.join(' ')} failed: ${result.stderr}');
    }
    return (result.stdout as String).trim();
  }

  /// A container answers its port some time after `docker run` returns.
  Future<SocketChannel> waitForServer() async {
    for (var i = 0; i < 100; i++) {
      try {
        return await SocketChannel.connect(port);
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    fail('the container never answered on port $port');
  }

  Future<RemoteGameSession> join(PlayerId who) async =>
      RemoteGameSession.join(await waitForServer(), who);

  test(
    'a building outlives the container it was built in',
    () async {
      addTearDown(() async {
        await Process.run('docker', ['rm', '--force', name]);
        await Process.run('docker', ['volume', 'rm', '--force', volume]);
      });
      await Process.run('docker', ['rm', '--force', name]);
      await Process.run('docker', ['volume', 'rm', '--force', volume]);

      // A fixed seed so the ground under the spawn is the same ground every
      // run; arguments after the image are appended to the entry point.
      await docker([
        'run',
        '--detach',
        '--name',
        name,
        '--publish',
        '$port:8787',
        '--volume',
        '$volume:/world',
        image!,
        '--seed',
        '4242',
      ]);

      final builder = await join(const PlayerId('builder'));

      // Straight down would put the block inside the player, and the server
      // would rightly refuse it. Look down and a little forward.
      for (var i = 0; i < 16; i++) {
        builder.tick(1 / 60, const InputFrame(lookPitch: -0.05));
        await Future<void>.delayed(const Duration(milliseconds: 8));
      }
      builder.dispatch(const UseOrPlace());

      Iterable<MapEntry<BlockPos, BlockType>> standing(GameState state) =>
          state.world.edits.entries.where((e) => e.value != BlockType.air);

      await eventually(() => standing(builder.state).isNotEmpty);
      final built = standing(builder.state).toList();
      expect(built, isNotEmpty, reason: 'the builder never placed anything');
      await builder.close();

      // `docker stop` sends SIGTERM and waits; the server saves on it. This
      // is the whole reason the entry point is in exec form.
      await docker(['restart', '--time', '15', name]);

      final visitor = await join(const PlayerId('visitor'));
      addTearDown(visitor.close);

      expect(
        standing(visitor.state).map((e) => e.key),
        containsAll(built.map((e) => e.key)),
        reason: 'the world came back empty: the save or the volume is lost',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip: image == null ? 'set FLUTCRAFT_IMAGE to a built image' : null,
  );
}
