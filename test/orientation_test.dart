import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Konfiguracja platformowa bywa nadpisywana przez `flutter create`,
/// więc pilnujemy jej testem zamiast pamiętać o niej ręcznie.
void main() {
  group('iOS Info.plist', () {
    late String plist;

    setUpAll(() {
      plist = File('ios/Runner/Info.plist').readAsStringSync();
    });

    List<String> orientationsFor(String key) {
      final match = RegExp(
        '<key>$key</key>\\s*<array>(.*?)</array>',
        dotAll: true,
      ).firstMatch(plist);
      expect(match, isNotNull, reason: 'brak klucza $key');
      return RegExp('<string>(\\w+)</string>')
          .allMatches(match!.group(1)!)
          .map((m) => m.group(1)!)
          .toList();
    }

    test('telefon dopuszcza wyłącznie orientacje poziome', () {
      expect(orientationsFor('UISupportedInterfaceOrientations'), [
        'UIInterfaceOrientationLandscapeLeft',
        'UIInterfaceOrientationLandscapeRight',
      ]);
    });

    test('iPad też jest zablokowany w poziomie', () {
      expect(orientationsFor(r'UISupportedInterfaceOrientations~ipad'), [
        'UIInterfaceOrientationLandscapeLeft',
        'UIInterfaceOrientationLandscapeRight',
      ]);
    });

    test('Flutter GPU i Impeller pozostają włączone', () {
      expect(plist, contains('FLTEnableFlutterGPU'));
    });
  });

  group('AndroidManifest', () {
    late String manifest;

    setUpAll(() {
      manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
    });

    test('aktywność jest zablokowana w poziomie', () {
      expect(
        manifest,
        contains('android:screenOrientation="sensorLandscape"'),
      );
    });

    test('Flutter GPU pozostaje włączone', () {
      expect(
        manifest,
        contains('io.flutter.embedding.android.EnableFlutterGPU'),
      );
    });
  });

  group('macOS', () {
    test('Impeller pozostaje włączony', () {
      final plist = File('macos/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('FLTEnableImpeller'));
      expect(plist, contains('FLTEnableFlutterGPU'));
    });
  });
}
