// Enforces per-package test coverage from the lcov files CI collects.
//
// The thresholds differ on purpose. The domain is pure logic and has no
// excuse; the interface has widgets whose every branch is not worth a test;
// the engine is left out entirely, because covering it means owning a GPU in
// CI, and a threshold nobody can meet is a threshold everybody ignores.
//
// Usage: `dart run tool/check_coverage.dart` after generating coverage with
// `flutter test --coverage` (or `dart test --coverage=coverage`).
import 'dart:io';

/// Minimum percentage of executable lines covered, per package.
const thresholds = <String, int>{
  'flutcraft_domain': 90,
  'flutcraft_atlas': 85,
  'flutcraft_ui': 70,
};

void main() {
  var failed = false;

  for (final entry in thresholds.entries) {
    final lcov = File('packages/${entry.key}/coverage/lcov.info');
    if (!lcov.existsSync()) {
      stderr.writeln('${entry.key}: no coverage report at ${lcov.path}');
      failed = true;
      continue;
    }

    final percent = _coverageOf(lcov);
    final ok = percent >= entry.value;
    final verdict = ok ? 'ok' : 'below ${entry.value}%';
    stdout.writeln(
      '${entry.key.padRight(18)} ${percent.toStringAsFixed(1)}%  $verdict',
    );
    if (!ok) failed = true;
  }

  if (failed) exit(1);
}

/// Percentage of executable lines hit, read from the `DA:` records.
double _coverageOf(File lcov) {
  var total = 0;
  var hit = 0;

  for (final line in lcov.readAsLinesSync()) {
    if (!line.startsWith('DA:')) continue;
    final parts = line.substring(3).split(',');
    if (parts.length < 2) continue;
    total++;
    if ((int.tryParse(parts[1]) ?? 0) > 0) hit++;
  }

  return total == 0 ? 0 : hit * 100 / total;
}
