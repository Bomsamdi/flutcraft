// Verifies the architectural boundaries that the compiler cannot express
// on its own. Run from the repository root: `dart run tool/check_layering.dart`.
//
// A dependency rule is only real if something fails when it is broken. Lints
// cannot see across packages, so this script is the enforcement point.
import 'dart:io';

/// Package names that must never appear in a package's dependency graph.
const forbiddenDependencies = <String, List<String>>{
  'flutcraft_domain': ['flutter', 'flame', 'flame_3d', 'flutcraft_ui'],
  'flutcraft_atlas': ['flutter', 'flame', 'flame_3d'],
  'flutcraft_ui': ['flame', 'flame_3d', 'flutcraft_engine'],
  'flutcraft_engine': ['flutcraft_ui', 'flutcraft_l10n'],
  'flutcraft_l10n': ['flame', 'flame_3d', 'flutcraft_ui'],
  'flutcraft_server': [
    'flutter',
    'flame',
    'flame_3d',
    'flutcraft_ui',
    'flutcraft_engine',
    'flutcraft_l10n',
  ],
  'flutcraft_protocol': [
    'flutter',
    'flame',
    'flame_3d',
    'flutcraft_ui',
    'flutcraft_engine',
    'flutcraft_l10n',
  ],
};

/// Import prefixes banned inside a package's `lib/`, with the reason shown
/// when one is found.
const forbiddenImports = <String, Map<String, String>>{
  'flutcraft_domain': {
    'package:flutter/': 'the domain must stay pure Dart',
    'package:flame': 'the domain must not know about the renderer',
  },
  'flutcraft_atlas': {
    'package:flutter/': 'atlas generation is pure arithmetic',
    'package:flame': 'atlas generation must not touch the GPU',
  },
  'flutcraft_ui': {'package:flame': 'every screen must render without a GPU'},
  'flutcraft_server': {
    'package:flutter/': 'a server has no screen',
    'package:flame': 'a server draws nothing',
    'package:flutcraft_l10n': 'a server never formats a sentence',
  },
  'flutcraft_protocol': {
    'package:flutter/': 'the protocol has to compile into a server binary',
    'package:flame': 'a message is data, not something that draws',
    'dart:io': 'a message must decode in a test that opens no socket',
  },
};

void main() {
  final root = Directory.current;
  final packages = _findPackages(root);
  if (packages.isEmpty) {
    stderr.writeln('No packages found. Run this from the repository root.');
    exit(2);
  }

  final violations = <String>[];
  for (final package in packages) {
    violations.addAll(_checkDependencies(package));
    violations.addAll(_checkImports(package));
  }

  if (violations.isEmpty) {
    stdout.writeln('Layering OK — ${packages.length} packages checked.');
    return;
  }
  stderr.writeln('Layering violations:\n');
  for (final violation in violations) {
    stderr.writeln('  $violation');
  }
  exit(1);
}

class _Package {
  _Package(this.name, this.directory, this.pubspec);

  final String name;
  final Directory directory;
  final String pubspec;
}

List<_Package> _findPackages(Directory root) {
  final result = <_Package>[];
  for (final base in ['packages', 'app']) {
    final dir = Directory('${root.path}/$base');
    if (!dir.existsSync()) continue;
    for (final entry in dir.listSync().whereType<Directory>()) {
      final pubspec = File('${entry.path}/pubspec.yaml');
      if (!pubspec.existsSync()) continue;
      final text = pubspec.readAsStringSync();
      final name = RegExp(
        r'^name:\s*(\S+)',
        multiLine: true,
      ).firstMatch(text)?.group(1);
      if (name != null) result.add(_Package(name, entry, text));
    }
  }
  return result;
}

/// Reads dependency names from `dependencies:` only — `dev_dependencies`
/// may legitimately contain lint packages and test harnesses.
Set<String> _declaredDependencies(String pubspec) {
  final lines = pubspec.split('\n');
  final names = <String>{};
  var inside = false;
  for (final line in lines) {
    if (line.startsWith('dependencies:')) {
      inside = true;
      continue;
    }
    if (inside && line.isNotEmpty && !line.startsWith(' ')) break;
    if (!inside) continue;
    final match = RegExp(r'^  (\w[\w_]*):').firstMatch(line);
    if (match != null) names.add(match.group(1)!);
  }
  return names;
}

List<String> _checkDependencies(_Package package) {
  final banned = forbiddenDependencies[package.name];
  if (banned == null) return const [];
  final declared = _declaredDependencies(package.pubspec);
  return [
    for (final name in banned)
      if (declared.contains(name))
        '${package.name}/pubspec.yaml depends on "$name", which this layer '
            'must not see',
  ];
}

List<String> _checkImports(_Package package) {
  final rules = forbiddenImports[package.name];
  if (rules == null) return const [];

  final lib = Directory('${package.directory.path}/lib');
  if (!lib.existsSync()) return const [];

  final violations = <String>[];
  final files = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final match = RegExp(
        r"""^\s*import\s+['"]([^'"]+)['"]""",
      ).firstMatch(lines[i]);
      if (match == null) continue;
      final uri = match.group(1)!;
      for (final entry in rules.entries) {
        if (uri.startsWith(entry.key)) {
          final relative = file.path.replaceFirst(
            '${Directory.current.path}/',
            '',
          );
          violations.add('$relative:${i + 1} imports "$uri" — ${entry.value}');
        }
      }
    }
  }
  return violations;
}
