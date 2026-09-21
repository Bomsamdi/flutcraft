// Verifies that no user-facing text is written straight into a widget.
//
// A literal in a widget is a string nobody can translate: it never reaches an
// ARB file, so the Polish build silently shows English. The compiler cannot
// see the difference between a label and a font name, so this script looks at
// the few places where text reaches the screen.
//
// Run from the repository root:
// `dart run tool/check_no_translatable_literals.dart`.
import 'dart:io';

/// Widget arguments that end up in front of a player.
final _suspects = <RegExp>[
  RegExp(r"""Text\(\s*(['"])([^'"$]{3,})\1"""),
  RegExp(
    r"""(?:label|tooltip|hintText|semanticLabel)\s*:\s*(['"])([^'"$]{3,})\1""",
  ),
];

/// Literals that are not text: identifiers the framework expects verbatim.
const _notText = ['monospace', 'sans-serif', 'serif'];

/// A line with this marker may hold a literal — a debug string, or a value
/// the format itself defines.
const _escapeHatch = 'not-translatable';

void main() {
  final ui = Directory('packages/flutcraft_ui/lib');
  if (!ui.existsSync()) {
    stderr.writeln('Run this from the repository root.');
    exit(2);
  }

  final findings = <String>[];

  for (final file in ui.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;

    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains(_escapeHatch)) continue;

      for (final pattern in _suspects) {
        final match = pattern.firstMatch(line);
        if (match == null) continue;

        final literal = match.group(2)!;
        if (_notText.contains(literal)) continue;
        findings.add('${file.path}:${i + 1}  "$literal"');
      }
    }
  }

  if (findings.isEmpty) {
    stdout.writeln('No translatable literals — every string comes from ARB.');
    return;
  }

  stderr.writeln('User-facing text written directly into a widget:');
  for (final finding in findings) {
    stderr.writeln('  $finding');
  }
  stderr.writeln(
    '\nPut it in app_en.arb and app_pl.arb, then read it through '
    'context.t or context.strings.',
  );
  exit(1);
}
