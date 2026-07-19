import 'package:flow/src/create/services/rename_service.dart';
import 'package:test/test.dart';

void main() {
  group('rewritePackageReferences', () {
    test('rewrites a whole-word package identifier', () {
      expect(
        rewritePackageReferences('flutter_starter', from: 'flutter_starter', to: 'my_app'),
        'my_app',
      );
    });

    test('rewrites package: imports', () {
      expect(
        rewritePackageReferences(
          "import 'package:flutter_starter/app.dart';",
          from: 'flutter_starter',
          to: 'my_app',
        ),
        "import 'package:my_app/app.dart';",
      );
    });

    test('rewrites the pubspec name field', () {
      expect(
        rewritePackageReferences(
          'name: flutter_starter\nversion: 1.0.0\n',
          from: 'flutter_starter',
          to: 'my_app',
        ),
        'name: my_app\nversion: 1.0.0\n',
      );
    });

    // CRITICAL: a plain (non-word-boundary) replaceAll would also mangle
    // this identifier, since it contains "flutter_starter" as a substring.
    test('leaves flutter_starter_legacy untouched', () {
      expect(
        rewritePackageReferences('flutter_starter_legacy', from: 'flutter_starter', to: 'my_app'),
        'flutter_starter_legacy',
      );
    });

    test('leaves a prefixed identifier untouched', () {
      expect(
        rewritePackageReferences('my_flutter_starter', from: 'flutter_starter', to: 'my_app'),
        'my_flutter_starter',
      );
    });
  });

  group('readPubspecName', () {
    test('reads the name field', () {
      expect(readPubspecName('name: flutter_starter\nversion: 1.0.0\n'), 'flutter_starter');
    });

    test('returns null when there is no name field', () {
      expect(readPubspecName('version: 1.0.0\n'), isNull);
    });
  });

  group('isRewritableFile', () {
    test('includes .dart, .yaml, and .md files', () {
      expect(isRewritableFile('/proj/lib/main.dart'), isTrue);
      expect(isRewritableFile('/proj/pubspec.yaml'), isTrue);
      expect(isRewritableFile('/proj/README.md'), isTrue);
    });

    test('excludes .git, build, and .dart_tool', () {
      expect(isRewritableFile('/proj/.git/config'), isFalse);
      expect(isRewritableFile('/proj/build/output.dart'), isFalse);
      expect(isRewritableFile('/proj/.dart_tool/package_config.json'), isFalse);
    });

    test('excludes test/tool/rename_test.dart specifically', () {
      expect(isRewritableFile('/proj/test/tool/rename_test.dart'), isFalse);
    });

    test('excludes unrelated extensions', () {
      expect(isRewritableFile('/proj/android/app/build.gradle.kts'), isFalse);
      expect(isRewritableFile('/proj/ios/Runner/Info.plist'), isFalse);
    });
  });

  group('rewriteAndroidLabel', () {
    test('rewrites android:label', () {
      const manifest =
          '<manifest><application android:label="flutter_starter"></application></manifest>';
      expect(rewriteAndroidLabel(manifest, 'My App'), contains('android:label="My App"'));
    });

    test('returns null when android:label is missing', () {
      expect(rewriteAndroidLabel('<manifest></manifest>', 'My App'), isNull);
    });

    test('escapes XML-sensitive characters', () {
      const manifest = '<manifest><application android:label="x"></application></manifest>';
      expect(
        rewriteAndroidLabel(manifest, 'Ben & Jerry\'s'),
        contains('android:label="Ben &amp; Jerry&apos;s"'),
      );
    });
  });

  group('rewriteIosDisplayName', () {
    const plist = '''
<plist><dict>
<key>CFBundleDisplayName</key>
<string>Flutter Starter</string>
<key>CFBundleName</key>
<string>flutter_starter</string>
</dict></plist>
''';

    test('rewrites both CFBundleDisplayName and CFBundleName', () {
      final updated = rewriteIosDisplayName(plist, 'My App')!;
      expect(updated, contains('<key>CFBundleDisplayName</key>\n<string>My App</string>'));
      expect(updated, contains('<key>CFBundleName</key>\n<string>My App</string>'));
    });

    test('returns null when neither key is present', () {
      expect(rewriteIosDisplayName('<plist></plist>', 'My App'), isNull);
    });
  });

  group('rewriteAndroidApplicationId', () {
    test('rewrites applicationId', () {
      const gradle = 'defaultConfig {\n    applicationId = "com.example.flutter_starter"\n}\n';
      final updated = rewriteAndroidApplicationId(gradle, 'com.acme.my_app')!;
      expect(updated, contains('applicationId = "com.acme.my_app"'));
    });

    test('returns null when applicationId is missing', () {
      expect(rewriteAndroidApplicationId('defaultConfig {}', 'com.acme.my_app'), isNull);
    });
  });

  group('rewriteIosBundleId', () {
    const pbxproj = '''
    PRODUCT_BUNDLE_IDENTIFIER = com.example.flutterStarter;
    PRODUCT_BUNDLE_IDENTIFIER = com.example.flutterStarter.RunnerTests;
    PRODUCT_BUNDLE_IDENTIFIER = com.example.flutterStarter;
''';

    test('rewrites the base id and preserves the .RunnerTests suffix', () {
      final updated = rewriteIosBundleId(pbxproj, 'com.acme.myapp')!;
      expect(updated, contains('PRODUCT_BUNDLE_IDENTIFIER = com.acme.myapp;'));
      expect(updated, contains('PRODUCT_BUNDLE_IDENTIFIER = com.acme.myapp.RunnerTests;'));
      expect(updated, isNot(contains('flutterStarter')));
    });

    test('returns null when no concrete value is found', () {
      const onlyMacro = 'PRODUCT_BUNDLE_IDENTIFIER = \$(inherited);';
      expect(rewriteIosBundleId(onlyMacro, 'com.acme.myapp'), isNull);
    });
  });
}
