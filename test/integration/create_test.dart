@Tags(['integration'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

/// Absolute path to `bin/flow.dart` so subprocesses can find it regardless of
/// the working directory used during a test.
final String _binFlow = File('bin/flow.dart').absolute.path;

Future<TestProcess> runFlow(List<String> args, {String? workingDirectory}) {
  return TestProcess.start('dart', [
    'run',
    _binFlow,
    ...args,
  ], workingDirectory: workingDirectory ?? d.sandbox);
}

/// Builds a minimal local git repository that stands in for a real template
/// (like flutter_starter), so tests never touch the network. Returns its
/// absolute path.
///
/// Deliberately includes:
/// - a `package:fixture_template/...` import + pubspec `name:` for the
///   identity-rewrite sweep to rewrite,
/// - `lib/main_dev.dart` / `lib/main_production.dart` so the "next steps"
///   output can be verified,
/// - `lib/legacy.dart`, whose content contains "fixture_template_legacy" as
///   a substring of the old package name — the word-boundary regression
///   this whole feature is built around,
/// - Android + iOS identity files with the same shape as flutter_starter's.
String _createFixtureTemplate() {
  final dir = p.join(d.sandbox, 'template');
  Directory(p.join(dir, 'lib')).createSync(recursive: true);
  Directory(p.join(dir, 'android/app/src/main')).createSync(recursive: true);
  Directory(p.join(dir, 'ios/Runner')).createSync(recursive: true);
  Directory(p.join(dir, 'ios/Runner.xcodeproj')).createSync(recursive: true);

  File(p.join(dir, 'pubspec.yaml')).writeAsStringSync('''
name: fixture_template
description: "Fixture template used only by flow's own integration tests."
publish_to: "none"
version: 1.0.0+1

environment:
  sdk: ^3.7.2
''');

  File(p.join(dir, 'lib/greeting.dart')).writeAsStringSync('''
class Greeting {
  const Greeting();
  String get message => 'hello from fixture_template';
}
''');

  File(p.join(dir, 'lib/main.dart')).writeAsStringSync('''
import 'package:fixture_template/greeting.dart';

void main() {
  // ignore: avoid_print
  print(const Greeting().message);
}
''');

  for (final flavor in ['dev', 'production']) {
    File(p.join(dir, 'lib/main_$flavor.dart')).writeAsStringSync('''
import 'package:fixture_template/greeting.dart';

void main() {
  // ignore: avoid_print
  print('$flavor: \${const Greeting().message}');
}
''');
  }

  File(p.join(dir, 'lib/legacy.dart')).writeAsStringSync('''
// fixture_template_legacy must survive a rename untouched — it only
// *contains* the old package name as a substring, it isn't the identifier.
const fixtureTemplateLegacyMarker = 'fixture_template_legacy';
''');

  File(p.join(dir, 'android/app/build.gradle.kts')).writeAsStringSync('''
plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.fixture_template"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.fixture_template"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }
}
''');

  File(p.join(dir, 'android/app/src/main/AndroidManifest.xml')).writeAsStringSync('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="fixture_template"
        android:name="\${applicationName}"
        android:icon="@mipmap/ic_launcher">
    </application>
</manifest>
''');

  File(p.join(dir, 'ios/Runner/Info.plist')).writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDisplayName</key>
	<string>Fixture Template</string>
	<key>CFBundleName</key>
	<string>fixture_template</string>
</dict>
</plist>
''');

  File(p.join(dir, 'ios/Runner.xcodeproj/project.pbxproj')).writeAsStringSync('''
        PRODUCT_BUNDLE_IDENTIFIER = com.example.fixtureTemplate;
        PRODUCT_BUNDLE_IDENTIFIER = com.example.fixtureTemplate.RunnerTests;
        PRODUCT_BUNDLE_IDENTIFIER = com.example.fixtureTemplate;
''');

  void git(List<String> args) {
    final result = Process.runSync('git', args, workingDirectory: dir);
    if (result.exitCode != 0) {
      fail('git ${args.join(' ')} failed: ${result.stderr}');
    }
  }

  git(['init', '-q', '-b', 'main']);
  git(['config', 'user.email', 'flow-test@example.com']);
  git(['config', 'user.name', 'Flow Test']);
  git(['add', '-A']);
  git(['commit', '-q', '-m', 'fixture template init']);

  return dir;
}

void main() {
  group('flow create (local template fixture)', () {
    test('scaffolds a project and rewrites its identity', () async {
      final template = _createFixtureTemplate();
      final output = p.join(d.sandbox, 'out');
      Directory(output).createSync(recursive: true);

      final process = await runFlow([
        'create',
        'my_app',
        '--org',
        'com.acme',
        '--template',
        template,
        '--ref',
        'main',
        '--output',
        output,
        '--no-pub-get',
      ]);
      final stdout = await process.stdout.rest.join('\n');
      await process.shouldExit(0);

      final target = p.join(output, 'my_app');
      expect(Directory(target).existsSync(), isTrue);

      // History was detached: a fresh, history-less repo, not the template's.
      expect(Directory(p.join(target, '.git')).existsSync(), isTrue);
      final log = Process.runSync('git', ['log'], workingDirectory: target);
      expect(log.exitCode, isNot(0), reason: 'a freshly `git init`-ed repo has no commits yet');

      // pubspec + package: imports were rewritten.
      final pubspec = File(p.join(target, 'pubspec.yaml')).readAsStringSync();
      expect(pubspec, contains('name: my_app'));
      expect(pubspec, isNot(contains('fixture_template')));

      final mainDart = File(p.join(target, 'lib/main.dart')).readAsStringSync();
      expect(mainDart, contains('package:my_app/greeting.dart'));

      // Word-boundary regression: this substring survives untouched.
      final legacy = File(p.join(target, 'lib/legacy.dart')).readAsStringSync();
      expect(legacy, contains('fixture_template_legacy'));

      // Android identity.
      final manifest =
          File(
            p.join(target, 'android/app/src/main/AndroidManifest.xml'),
          ).readAsStringSync();
      expect(manifest, contains('android:label="My App"'));

      final gradle = File(p.join(target, 'android/app/build.gradle.kts')).readAsStringSync();
      expect(gradle, contains('applicationId = "com.acme.my_app"'));

      // iOS identity.
      final plist = File(p.join(target, 'ios/Runner/Info.plist')).readAsStringSync();
      expect(plist, contains('<string>My App</string>'));

      final pbxproj =
          File(
            p.join(target, 'ios/Runner.xcodeproj/project.pbxproj'),
          ).readAsStringSync();
      expect(pbxproj, contains('PRODUCT_BUNDLE_IDENTIFIER = com.acme.my_app;'));
      expect(pbxproj, contains('PRODUCT_BUNDLE_IDENTIFIER = com.acme.my_app.RunnerTests;'));

      // Final output names the flavored entrypoints the template ships.
      expect(stdout, contains('lib/main_dev.dart'));
      expect(stdout, contains('lib/main_production.dart'));
      expect(stdout, contains('--dart-define-from-file=.env.dev'));
    });

    test('an explicit --bundle-id overrides <org>.<name>', () async {
      final template = _createFixtureTemplate();
      final output = p.join(d.sandbox, 'out');
      Directory(output).createSync(recursive: true);

      final process = await runFlow([
        'create',
        'my_app',
        '--org',
        'com.acme',
        '--bundle-id',
        'com.acme.myapp',
        '--template',
        template,
        '--ref',
        'main',
        '--output',
        output,
        '--no-pub-get',
      ]);
      await process.shouldExit(0);

      final target = p.join(output, 'my_app');
      final gradle = File(p.join(target, 'android/app/build.gradle.kts')).readAsStringSync();
      expect(gradle, contains('applicationId = "com.acme.myapp"'));
      final pbxproj =
          File(
            p.join(target, 'ios/Runner.xcodeproj/project.pbxproj'),
          ).readAsStringSync();
      expect(pbxproj, contains('PRODUCT_BUNDLE_IDENTIFIER = com.acme.myapp;'));
    });

    test('--flavors adds productFlavors with a suffix on every non-production flavor', () async {
      final template = _createFixtureTemplate();
      final output = p.join(d.sandbox, 'out');
      Directory(output).createSync(recursive: true);

      final process = await runFlow([
        'create',
        'my_app',
        '--org',
        'com.acme',
        '--template',
        template,
        '--ref',
        'main',
        '--output',
        output,
        '--no-pub-get',
        '--flavors',
        'dev,production',
      ]);
      final stdout = await process.stdout.rest.join('\n');
      final stderr = await process.stderr.rest.join('\n');
      await process.shouldExit(0);

      final target = p.join(output, 'my_app');
      final gradle = File(p.join(target, 'android/app/build.gradle.kts')).readAsStringSync();
      expect(gradle, contains('productFlavors {'));
      expect(gradle, contains('create("dev")'));
      expect(gradle, contains('applicationIdSuffix = ".dev"'));
      expect(gradle, contains('create("production")'));
      expect(gradle, isNot(contains('applicationIdSuffix = ".production"')));

      // AppLogger.warn writes to stderr (mason_logger convention).
      expect(stdout + stderr, contains('iOS schemes were NOT generated'));
    });

    test('fails before creating anything when the name is invalid', () async {
      final template = _createFixtureTemplate();
      final output = p.join(d.sandbox, 'out');
      Directory(output).createSync(recursive: true);

      final process = await runFlow([
        'create',
        'My-App',
        '--template',
        template,
        '--output',
        output,
        '--no-pub-get',
      ]);
      await process.shouldExit(64);
      expect(Directory(p.join(output, 'My-App')).existsSync(), isFalse);
    });

    test('fails before creating anything when the bundle id is invalid', () async {
      final template = _createFixtureTemplate();
      final output = p.join(d.sandbox, 'out');
      Directory(output).createSync(recursive: true);

      final process = await runFlow([
        'create',
        'my_app',
        '--bundle-id',
        'not a bundle id',
        '--template',
        template,
        '--output',
        output,
        '--no-pub-get',
      ]);
      await process.shouldExit(64);
      expect(Directory(p.join(output, 'my_app')).existsSync(), isFalse);
    });

    test('fails when the target directory already exists', () async {
      final template = _createFixtureTemplate();
      final output = p.join(d.sandbox, 'out');
      Directory(p.join(output, 'my_app')).createSync(recursive: true);

      final process = await runFlow([
        'create',
        'my_app',
        '--template',
        template,
        '--output',
        output,
        '--no-pub-get',
      ]);
      await process.shouldExit(64);
    });

    test('a bad --ref reports the real git error and exits non-zero', () async {
      final template = _createFixtureTemplate();
      final output = p.join(d.sandbox, 'out');
      Directory(output).createSync(recursive: true);

      final process = await runFlow([
        'create',
        'my_app',
        '--template',
        template,
        '--ref',
        'no-such-branch',
        '--output',
        output,
        '--no-pub-get',
      ]);
      await process.shouldExit(isNot(0));
      expect(Directory(p.join(output, 'my_app')).existsSync(), isFalse);
    });
  });

  group('flow create is not swallowed by the deploy-run rewrite', () {
    test('`flow create` with no project name fails as a create usage error', () async {
      // A fresh sandbox has no .flow_deploy.json. If `create` were ever
      // dropped from kTopLevelCommands, `flow create` would be rewritten to
      // `flow deploy run create`, which fails with a *different* error
      // ("No profiles are configured...") and a different exit code path.
      final process = await runFlow(['create']);
      final stderr = await process.stderr.rest.join('\n');
      await process.shouldExit(64);
      expect(stderr.toLowerCase(), contains('project name'));
      expect(stderr.toLowerCase(), isNot(contains('profile')));
    });
  });

  group('flow create wizard — CI safety', () {
    // The single most important test in this feature: `flow create` with no
    // name and no terminal must fail fast with a clear usage error, never
    // hang waiting on a prompt nobody can answer. `TestProcess` pipes stdin
    // (no tty attached), so this exercises the exact CI shape. A short
    // explicit timeout turns a regression into a fast, obvious test failure
    // instead of the suite hanging.
    test(
      'a non-tty invocation with no project name exits non-zero instead of hanging',
      () async {
        final process = await runFlow(['create']);
        final stderr = await process.stderr.rest.join('\n');
        // Assert 64 (usage) exactly, not merely non-zero. A crash inside the
        // wizard exits 70, which `isNot(0)` would happily accept — that is
        // precisely how a real regression slipped through: the guard checked
        // only stdin, so a redirected stdout crashed mason_logger with
        // "No terminal attached to stdout" and still "passed" this test.
        await process.shouldExit(64);
        expect(stderr.toLowerCase(), contains('project name'));
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    test(
      '--no-input fails fast with no project name even if it were a real terminal',
      () async {
        final process = await runFlow(['create', '--no-input']);
        final stderr = await process.stderr.rest.join('\n');
        // 64 exactly, for the same reason as the test above: a wizard crash
        // exits 70 and would slip past `isNot(0)`.
        await process.shouldExit(64);
        expect(stderr.toLowerCase(), contains('project name'));
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );
  });
}
