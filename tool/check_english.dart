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

/// Polish words that carry no diacritics, so the letters alone would not
/// give them away. Not a dictionary — just enough of the common ones that a
/// stray sentence trips over one.
final _polishWords = RegExp(
  r'\b(nie|jest|przez|oraz|tylko|wiec|czyli|dla|sie|jako|ale|zawsze|' // polish-ok
  r'kiedy|prototyp|silnik|gra|gry|bloku|bloki|swiat|potwor|potwory)\b', // polish-ok
  caseSensitive: false,
);

/// A line ending in this marker is allowed to contain Polish: a test that
/// asserts a Polish translation has to write one out.
const _escapeHatch = 'polish-ok';

/// Paths whose whole job is to hold Polish.
const _allowed = [
  'packages/flutcraft_l10n/lib/l10n/app_pl.arb',
  'packages/flutcraft_l10n/lib/src/generated/app_localizations_pl.dart',
];

/// File types worth reading: code, translations, docs and CI config.
const _checkedExtensions = ['.dart', '.arb', '.md', '.yaml'];

void main() {
  final offenders = <String, int>{};

  for (final file in _filesToCheck()) {
    final hits = file
        .readAsLinesSync()
        .where((line) => !line.contains(_escapeHatch))
        .map(
          (line) =>
              _polish.allMatches(line).length +
              _polishWords.allMatches(line).length,
        )
        .fold(0, (sum, count) => sum + count);
    if (hits > 0) offenders[file.path] = hits;
  }

  if (offenders.isEmpty) {
    stdout.writeln('English OK — no stray Polish outside the translations.');
    return;
  }

  stderr.writeln('Polish text found outside the translation files:');
  for (final entry in offenders.entries) {
    stderr.writeln('  ${entry.key}  (${entry.value} hits)');
  }
  stderr.writeln('\nThe series is in English; translations belong in ARB.');
  exit(1);
}

/// Every file worth checking: the docs at the root, plus the packages, the
/// app, the tools and the CI config.
Iterable<File> _filesToCheck() {
  final roots = [
    Directory('packages'),
    Directory('app'),
    Directory('tool'),
    Directory('.github'),
  ].where((directory) => directory.existsSync());

  return [
    ...Directory('.').listSync().whereType<File>(),
    ...roots.expand((root) => root.listSync(recursive: true)).whereType<File>(),
  ].where(
    (file) =>
        _checkedExtensions.any(file.path.endsWith) &&
        !_allowed.any(file.path.endsWith) &&
        !file.path.contains('/build/') &&
        !file.path.contains('/.dart_tool/'),
  );
}
