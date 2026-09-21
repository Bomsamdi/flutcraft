// Verifies that the source reads in English — comments included.
//
// The tutorial is recorded in English, so a Polish comment in the code is a
// comment the viewer cannot read. The Polish that *should* exist lives in the
// translation files, and those are the only place this check allows it.
//
// Run from the repository root: `dart run tool/check_english.dart`.
import 'dart:io';

/// Characters that only appear in Polish, never in English.
final _polish = RegExp(
  '[\u0105\u0107\u0119\u0142\u0144\u00f3\u015b\u017a\u017c'
  '\u0104\u0106\u0118\u0141\u0143\u00d3\u015a\u0179\u017b]',
);

/// A line ending in this marker is allowed to contain Polish: a test that
/// asserts a Polish translation has to write one out.
const _escapeHatch = 'polish-ok';

/// Paths whose whole job is to hold Polish.
const _allowed = [
  'packages/flutcraft_l10n/lib/l10n/app_pl.arb',
  'packages/flutcraft_l10n/lib/src/generated/app_localizations_pl.dart',
];

void main() {
  final roots = [
    Directory('packages'),
    Directory('app'),
    Directory('tool'),
  ].where((directory) => directory.existsSync());

  final offenders = <String, int>{};

  for (final root in roots) {
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (!path.endsWith('.dart') && !path.endsWith('.arb')) continue;
      if (_allowed.any(path.endsWith)) continue;
      if (path.contains('/build/') || path.contains('/.dart_tool/')) continue;

      final hits = entity
          .readAsLinesSync()
          .where((line) => !line.contains(_escapeHatch))
          .map((line) => _polish.allMatches(line).length)
          .fold(0, (sum, count) => sum + count);
      if (hits > 0) offenders[path] = hits;
    }
  }

  if (offenders.isEmpty) {
    stdout.writeln('English OK — no stray Polish outside the translations.');
    return;
  }

  stderr.writeln('Polish text found outside the translation files:');
  for (final entry in offenders.entries) {
    stderr.writeln('  ${entry.key}  (${entry.value} characters)');
  }
  stderr.writeln('\nThe series is in English; translations belong in ARB.');
  exit(1);
}
