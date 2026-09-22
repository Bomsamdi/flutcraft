import 'dart:convert';
import 'dart:io';

import 'package:flutcraft_protocol/flutcraft_protocol.dart';
import 'package:flutcraft_server/flutcraft_server.dart';
import 'package:test/test.dart';

/// Cost factor for the tests.
///
/// The real one takes about a second and a half per sign-in, by design. A
/// suite that paid that a dozen times over is a suite nobody runs.
const cheap = 500;

void main() {
  group('Registering', () {
    late AccountStore accounts;

    setUp(() => accounts = AccountStore.inMemory(rounds: cheap));

    test('a free name is taken, and then it is not free', () async {
      expect(await accounts.register('alice', 'open sesame'), isNull);
      expect(
        await accounts.register('alice', 'something else'),
        KickReason.nameTaken,
      );
    });

    test('the name is taken whatever case it is typed in', () async {
      await accounts.register('alice', 'open sesame');

      // Two players called Alice and alice would be two accounts and one
      // name over their heads.
      expect(
        await accounts.register('ALICE', 'open sesame'),
        KickReason.nameTaken,
      );
    });

    test('a name has to be usable as a name', () async {
      // It becomes a PlayerId, a file name and a label above somebody's head.
      expect(await accounts.register('..', 'open sesame'), KickReason.badName);
      expect(
        await accounts.register('../../etc/passwd', 'open sesame'),
        KickReason.badName,
      );
      expect(
        await accounts.register('a' * 17, 'open sesame'),
        KickReason.badName,
      );
    });

    test('a secret too short to be one is refused', () async {
      expect(await accounts.register('alice', 'abc'), KickReason.badName);
      expect(accounts.knows('alice'), isFalse);
    });
  });

  group('Signing in', () {
    late AccountStore accounts;

    setUp(() async {
      accounts = AccountStore.inMemory(rounds: cheap);
      await accounts.register('alice', 'open sesame');
    });

    test('the right secret gets in', () async {
      expect((await accounts.verify('alice', 'open sesame'))!.name, 'alice');
    });

    test('the wrong secret does not', () async {
      expect(await accounts.verify('alice', 'Open Sesame'), isNull);
    });

    test('a name nobody registered does not', () async {
      expect(await accounts.verify('mallory', 'open sesame'), isNull);
    });

    test('an unknown name costs about what a known one costs', () async {
      // Told apart by the clock, an early return is a list of this server's
      // players for anybody willing to time a few thousand guesses.
      Future<Duration> time(Future<void> Function() work) async {
        final clock = Stopwatch()..start();
        await work();
        return clock.elapsed;
      }

      // Warm first: the first isolate of a process pays for starting one.
      await accounts.verify('alice', 'wrong');

      final known = await time(() => accounts.verify('alice', 'wrong'));
      final unknown = await time(() => accounts.verify('mallory', 'wrong'));

      final ratio = known.inMicroseconds / unknown.inMicroseconds;
      expect(ratio, closeTo(1, 0.9), reason: 'known $known, unknown $unknown');
    });
  });

  group('What is written down', () {
    late Directory directory;
    late AccountStore accounts;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('flutcraft_acc');
      accounts = AccountStore.inDirectory(directory, rounds: cheap);
    });
    tearDown(() => directory.deleteSync(recursive: true));

    test('an account outlives the process', () async {
      await accounts.register('alice', 'open sesame');

      final later = AccountStore.inDirectory(directory, rounds: cheap);

      expect((await later.verify('alice', 'open sesame'))!.name, 'alice');
    });

    test('the secret itself is nowhere in the file', () async {
      await accounts.register('alice', 'open sesame');

      final written = File(
        '${directory.path}/accounts.json',
      ).readAsStringSync();

      expect(written, isNot(contains('open sesame')));
      expect(written, contains('alice'));
    });

    test('two accounts with one secret do not share a hash', () async {
      await accounts.register('alice', 'open sesame');
      await accounts.register('bob', 'open sesame');

      final raw =
          json.decode(
                File('${directory.path}/accounts.json').readAsStringSync(),
              )
              as Map<String, Object?>;
      final written = (raw['accounts']! as List<Object?>)
          .cast<Map<String, Object?>>();

      // What the salt is for: without one, a stolen file says at a glance who
      // shares a password, and one cracked hash opens every account that had
      // it.
      expect(written.map((a) => a['hash']).toSet(), hasLength(2));
      expect(written.map((a) => a['salt']).toSet(), hasLength(2));
    });

    test('an account remembers what it cost to make', () async {
      // So that raising the cost later does not lock out everybody who
      // registered before.
      await accounts.register('alice', 'open sesame');

      final stricter = AccountStore.inDirectory(directory, rounds: cheap * 4);

      expect((await stricter.verify('alice', 'open sesame'))!.rounds, cheap);
    });

    test('a file that will not parse is not the end of the server', () async {
      File('${directory.path}/accounts.json').writeAsStringSync('nope');

      // Refusing to start would mean one bad byte locks everybody out of a
      // world that is otherwise perfectly fine.
      final store = AccountStore.inDirectory(directory, rounds: cheap);

      expect(store.names, isEmpty);
      expect(await store.register('alice', 'open sesame'), isNull);
    });
  });
}
