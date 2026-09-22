import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutcraft_domain/flutcraft_domain.dart';
import 'package:flutcraft_protocol/flutcraft_protocol.dart';

/// One registered player: a name, and enough to check a secret against it.
///
/// The secret itself is not here and never was. What is stored is what a
/// slow hash made of it, and the salt that hash was made with.
final class Account {
  const Account({
    required this.name,
    required this.salt,
    required this.hash,
    required this.rounds,
  });

  final String name;
  final String salt;
  final String hash;
  final int rounds;

  PlayerId get id => PlayerId(name);
}

/// Everybody this server has ever let in.
///
/// A file, not a database: a world already lives in a directory, and one more
/// document beside it is the whole of what a game server needs to remember
/// about who its players are.
class AccountStore {
  AccountStore._(this._file, this._accounts, {Random? entropy, int? rounds})
    : _entropy = entropy ?? Random.secure(),
      rounds = rounds ?? defaultRounds;

  /// Accounts kept beside the world, in `accounts.json`.
  factory AccountStore.inDirectory(
    Directory directory, {
    Random? entropy,
    int? rounds,
  }) {
    final file = File('${directory.path}/accounts.json');
    return AccountStore._(file, _read(file), entropy: entropy, rounds: rounds);
  }

  /// Accounts that go when the process does.
  ///
  /// What a server started without `--world` gets: a world nobody keeps has
  /// no business keeping the passwords that went with it.
  factory AccountStore.inMemory({Random? entropy, int? rounds}) =>
      AccountStore._(null, {}, entropy: entropy, rounds: rounds);

  final File? _file;
  final Map<String, Account> _accounts;
  final Random _entropy;

  /// How many times a new secret goes through the hash.
  ///
  /// Injectable because a test that waits a second and a half per sign-in is
  /// a test nobody runs.
  final int rounds;

  /// How many times the secret goes through the hash.
  ///
  /// The point of a slow hash is that a stolen file is not a list of
  /// passwords: every guess has to be made this expensive, so a dictionary
  /// costs an attacker weeks instead of an afternoon.
  ///
  /// Measured here, not assumed: this many rounds take about 1.5 s on this
  /// machine, compiled. That is slow for PBKDF2 — the `crypto` package's HMAC
  /// is plain Dart, roughly ten times slower than the C an attacker runs, so
  /// the defender pays more per round than the attacker does. It is the
  /// honest number for a server written in this language, and the reason the
  /// work happens off the loop. Stored with each account, so raising it later
  /// does not lock anybody out.
  static const int defaultRounds = 120000;

  /// What a name is allowed to be.
  ///
  /// It ends up as a [PlayerId] and as a file name, and it is drawn over
  /// somebody's head, so: letters, digits, dash and underscore.
  static final RegExp nameShape = RegExp(r'^[A-Za-z0-9_-]{3,16}$');

  /// Short enough to guess is not a secret.
  static const int shortestSecret = 6;

  Iterable<String> get names => _accounts.keys;

  bool knows(String name) => _accounts.containsKey(name.toLowerCase());

  /// Claims a name. The reason it could not be claimed, or null on success.
  Future<KickReason?> register(String name, String secret) async {
    final problem = _checkShape(name, secret);
    if (problem != null) return problem;
    if (knows(name)) return KickReason.nameTaken;

    final salt = _freshSalt();
    _accounts[name.toLowerCase()] = Account(
      name: name,
      salt: salt,
      hash: await _hash(secret, salt, rounds),
      rounds: rounds,
    );
    _write();
    return null;
  }

  /// Checks a secret against a name. The account, or null if it does not add
  /// up — which covers both an unknown name and a wrong secret.
  Future<Account?> verify(String name, String secret) async {
    final account = _accounts[name.toLowerCase()];
    if (account == null) {
      // Hash anyway. Returning early would make an unknown name answer in
      // microseconds and a known one in a second and a half, and that
      // difference is a list of this server's players for anybody who times
      // a few guesses.
      await _hash(secret, _freshSalt(), rounds);
      return null;
    }
    final offered = await _hash(secret, account.salt, account.rounds);
    return _sameBytes(offered, account.hash) ? account : null;
  }

  /// Runs the slow part somewhere else.
  ///
  /// The world ticks on this isolate. A sign-in that hashed here would stop
  /// every player's zombie mid-step for as long as it took — one connection
  /// freezing everybody else's game is a poor trade for a password check.
  /// Isolates share no memory, and this needs none: two strings and a number
  /// go over, one string comes back.
  static Future<String> _hash(String secret, String salt, int rounds) =>
      Isolate.run(() => _derive(secret, salt, rounds));

  KickReason? _checkShape(String name, String secret) {
    if (!nameShape.hasMatch(name)) return KickReason.badName;
    if (secret.length < shortestSecret) return KickReason.badName;
    return null;
  }

  String _freshSalt() => base64.encode(
    Uint8List.fromList(List.generate(16, (_) => _entropy.nextInt(256))),
  );

  /// PBKDF2-HMAC-SHA256, written out because it is ten lines and the shape of
  /// it is the point: hash the salt, then hash the result again and again,
  /// mixing every round back in, so the cost cannot be skipped.
  static String _derive(String secret, String salt, int rounds) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    // The block index PBKDF2 appends to the salt. One block of SHA-256 is 32
    // bytes and that is the whole key here, so it is always the first.
    var block = hmac.convert([...base64.decode(salt), 0, 0, 0, 1]).bytes;
    final key = List<int>.from(block);
    for (var round = 1; round < rounds; round++) {
      block = hmac.convert(block).bytes;
      for (var i = 0; i < key.length; i++) {
        key[i] ^= block[i];
      }
    }
    return base64.encode(key);
  }

  /// Compares without giving away where two hashes start to differ.
  static bool _sameBytes(String a, String b) {
    final left = utf8.encode(a);
    final right = utf8.encode(b);
    if (left.length != right.length) return false;
    var difference = 0;
    for (var i = 0; i < left.length; i++) {
      difference |= left[i] ^ right[i];
    }
    return difference == 0;
  }

  static Map<String, Account> _read(File file) {
    if (!file.existsSync()) return {};
    try {
      final raw = json.decode(file.readAsStringSync()) as Map<String, Object?>;
      final list = raw['accounts'] as List<Object?>? ?? const [];
      return {
        for (final entry in list.whereType<Map<String, Object?>>())
          (entry['name']! as String).toLowerCase(): Account(
            name: entry['name']! as String,
            salt: entry['salt']! as String,
            hash: entry['hash']! as String,
            rounds: entry['rounds'] as int? ?? defaultRounds,
          ),
      };
    } on Object catch (error) {
      // Same choice as the world: report it and carry on with what is left.
      // Refusing to start would mean one bad byte locks everybody out.
      stderr.writeln('Could not read ${file.path}: $error');
      return {};
    }
  }

  void _write() {
    final file = _file;
    if (file == null) return;
    try {
      final temporary = File('${file.path}.tmp')
        ..writeAsStringSync(
          json.encode({
            'accounts': [
              for (final account in _accounts.values)
                {
                  'name': account.name,
                  'salt': account.salt,
                  'hash': account.hash,
                  'rounds': account.rounds,
                },
            ],
          }),
          flush: true,
        );
      temporary.renameSync(file.path);
    } on Object catch (error) {
      stderr.writeln('Could not write ${file.path}: $error');
    }
  }
}
