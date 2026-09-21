// Verifies platform configuration that no Dart test can meaningfully cover:
// orientation locks and the Impeller / Flutter GPU flags the renderer needs.
//
// This used to live in `orientation_test.dart`, where it read files through
// `dart:io` with relative paths — a configuration lint wearing a test's
// clothes. It breaks under a different working directory and mixes two
// unrelated concerns in one `flutter test` run.
import 'dart:io';

const _appRoot = 'app/flutcraft';

const _landscapeOnly = [
  'UIInterfaceOrientationLandscapeLeft',
  'UIInterfaceOrientationLandscapeRight',
];

void main() {
  final problems = <String>[
    ..._checkIosOrientation(),
    ..._checkAndroidOrientation(),
    ..._checkRendererFlags(),
    ..._checkNetworkEntitlement(),
  ];

  if (problems.isEmpty) {
    stdout.writeln('Platform configuration OK.');
    return;
  }
  stderr.writeln('Platform configuration problems:\n');
  for (final problem in problems) {
    stderr.writeln('  $problem');
  }
  exit(1);
}

String _read(String path) {
  final file = File('$_appRoot/$path');
  if (!file.existsSync()) {
    stderr.writeln('Missing $path — run this from the repository root.');
    exit(2);
  }
  return file.readAsStringSync();
}

List<String> _orientationsFor(String plist, String key) {
  final match = RegExp(
    '<key>$key</key>\\s*<array>(.*?)</array>',
    dotAll: true,
  ).firstMatch(plist);
  if (match == null) return const [];
  return RegExp(
    '<string>(\\w+)</string>',
  ).allMatches(match.group(1)!).map((m) => m.group(1)!).toList();
}

List<String> _checkIosOrientation() {
  final plist = _read('ios/Runner/Info.plist');
  final problems = <String>[];

  for (final key in [
    'UISupportedInterfaceOrientations',
    'UISupportedInterfaceOrientations~ipad',
  ]) {
    final found = _orientationsFor(plist, key);
    if (found.isEmpty) {
      problems.add('ios/Runner/Info.plist is missing $key');
    } else if (!_sameOrder(found, _landscapeOnly)) {
      problems.add(
        'ios/Runner/Info.plist $key allows $found; the game is '
        'landscape-only because a portrait frame crops the view and leaves '
        'no room for touch controls',
      );
    }
  }
  return problems;
}

List<String> _checkAndroidOrientation() {
  final manifest = _read('android/app/src/main/AndroidManifest.xml');
  if (manifest.contains('android:screenOrientation="sensorLandscape"')) {
    return const [];
  }
  return const [
    'AndroidManifest.xml is missing '
        'android:screenOrientation="sensorLandscape" on MainActivity',
  ];
}

/// A sandboxed macOS app may not open an outgoing connection without asking.
///
/// Worth checking rather than remembering: without the entitlement, joining a
/// server fails with "Operation not permitted" and nothing points at the
/// sandbox. It is also exactly the kind of file that gets regenerated.
List<String> _checkNetworkEntitlement() {
  const needed = 'com.apple.security.network.client';
  final problems = <String>[];

  for (final name in ['DebugProfile', 'Release']) {
    final path = 'macos/Runner/$name.entitlements';
    if (!_read(path).contains(needed)) {
      problems.add(
        '$path is missing $needed, so the game cannot join a '
        'server on macOS',
      );
    }
  }
  return problems;
}

/// flutter_gpu only runs on Impeller, and only when explicitly enabled.
List<String> _checkRendererFlags() {
  final problems = <String>[];

  final ios = _read('ios/Runner/Info.plist');
  if (!ios.contains('FLTEnableFlutterGPU')) {
    problems.add('ios/Runner/Info.plist is missing FLTEnableFlutterGPU');
  }

  final macos = _read('macos/Runner/Info.plist');
  for (final key in ['FLTEnableImpeller', 'FLTEnableFlutterGPU']) {
    if (!macos.contains(key)) {
      problems.add('macos/Runner/Info.plist is missing $key');
    }
  }

  final android = _read('android/app/src/main/AndroidManifest.xml');
  if (!android.contains('io.flutter.embedding.android.EnableFlutterGPU')) {
    problems.add(
      'AndroidManifest.xml is missing the EnableFlutterGPU metadata',
    );
  }
  return problems;
}

bool _sameOrder(List<String> a, List<String> b) =>
    a.length == b.length &&
    List.generate(a.length, (i) => a[i] == b[i]).every((equal) => equal);
