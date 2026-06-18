import 'dart:io';
import '../flow_enums.dart';
import '../logger.dart';
import '../pubspec_utils.dart';
import '../process_runner.dart';

class BuildService {
  static Future<void> runBuildProcess({
    required DeployPlatform platform,
    required DeployMode mode,
    required String buildFlavor,
    required bool skipVersionIncrement,
  }) async {
    await ProcessRunner.runCommand(
      'flutter',
      arguments: ['clean'],
      description: 'Cleaning project',
    );
    await ProcessRunner.runCommand(
      'flutter',
      arguments: ['pub', 'get'],
      description: 'Fetching dependencies',
    );

    await _cleanupLegacyFlutterAndroidArtifacts();

    if (!skipVersionIncrement) {
      await PubspecUtils.incrementPatch();
    }

    switch (platform) {
      case DeployPlatform.all:
        if (mode == DeployMode.beta) {
          await buildAndroidApk(buildFlavor: buildFlavor);
        } else {
          await buildAndroidAppBundle(buildFlavor: buildFlavor);
        }
        await buildIOS(buildFlavor: buildFlavor);
        break;
      case DeployPlatform.ios:
        await buildIOS(buildFlavor: buildFlavor);
        break;
      case DeployPlatform.android:
        if (mode == DeployMode.beta) {
          await buildAndroidApk(buildFlavor: buildFlavor);
        } else {
          await buildAndroidAppBundle(buildFlavor: buildFlavor);
        }
        break;
    }

    await _uploadSentrySymbolsIfConfigured();
  }

  /// Uploads Dart obfuscation maps and native debug symbols to Sentry via
  /// `sentry_dart_plugin`. No-op when the project has no `sentry.properties`
  /// — keeps this shared package usable in non-Sentry projects. Failures are
  /// logged but never abort the deploy, since the release artifact is already
  /// built and queued for distribution by this point.
  static Future<void> _uploadSentrySymbolsIfConfigured() async {
    final sentryProperties = File(
      '${Directory.current.path}/sentry.properties',
    );
    if (!sentryProperties.existsSync()) {
      logger.detail(
        'Skipping Sentry symbol upload: sentry.properties not found',
      );
      return;
    }

    try {
      await ProcessRunner.runCommand(
        'dart',
        arguments: ['run', 'sentry_dart_plugin'],
        description: 'Uploading debug symbols to Sentry',
      );
    } catch (e) {
      logger.warn('Sentry symbol upload failed: $e');
      logger.warn('Continuing — release artifact already built');
    }
  }

  static Future<void> buildAndroidApk({String buildFlavor = ''}) async {
    if (await _runProjectFlavorBuild('apk', buildFlavor)) return;

    final arguments = [
      'build',
      'apk',
      '--release',
      ..._flavorBuildArguments(buildFlavor),
    ];
    await ProcessRunner.runCommand(
      'flutter',
      arguments: arguments,
      description: 'Building Android APK',
      environment: _flavorEnvironment(buildFlavor),
    );
  }

  static Future<void> buildAndroidAppBundle({String buildFlavor = ''}) async {
    if (await _runProjectFlavorBuild('appbundle', buildFlavor)) return;

    final arguments = [
      'build',
      'appbundle',
      '--release',
      '--obfuscate',
      '--split-debug-info=build/app/outputs/symbols',
      ..._flavorBuildArguments(buildFlavor),
    ];
    await ProcessRunner.runCommand(
      'flutter',
      arguments: arguments,
      description: 'Building Android AppBundle',
      environment: _flavorEnvironment(buildFlavor),
    );
  }

  static Future<void> buildIOS({String buildFlavor = ''}) async {
    if (await _runProjectFlavorBuild('ipa', buildFlavor)) return;

    await ProcessRunner.runCommand(
      'pod',
      arguments: ['install'],
      description: 'Installing CocoaPods',
      workingDir: 'ios',
    );
    final arguments = [
      'build',
      'ipa',
      '--release',
      '--obfuscate',
      '--split-debug-info=build/ios/symbols',
      ..._flavorBuildArguments(buildFlavor),
    ];
    await ProcessRunner.runCommand(
      'flutter',
      arguments: arguments,
      description: 'Building iOS IPA',
      environment: _flavorEnvironment(buildFlavor),
    );
  }

  /// Uses the app's guarded flavor build when available.
  ///
  /// Project wrappers commonly validate env files, select native Firebase
  /// configuration, and enforce production safety checks. Bypassing them can
  /// produce an installable artifact that fails during startup.
  static Future<bool> _runProjectFlavorBuild(
    String target,
    String buildFlavor,
  ) async {
    if (buildFlavor.isEmpty || !File('${Directory.current.path}/tool/flavor.dart').existsSync()) {
      return false;
    }

    await ProcessRunner.runCommand(
      'dart',
      arguments: [
        'run',
        'tool/flavor.dart',
        'build',
        target,
        buildFlavor,
      ],
      description: 'Building $buildFlavor $target with project flavor guard',
    );
    return true;
  }

  static List<String> _flavorBuildArguments(String buildFlavor) {
    final arguments = <String>[];
    if (buildFlavor.isNotEmpty) {
      arguments.addAll([
        '--flavor',
        buildFlavor,
        '--target',
        'lib/main_$buildFlavor.dart',
      ]);
    }
    arguments.addAll(_dartDefineArguments(buildFlavor));
    return arguments;
  }

  /// Injects the flavor's compile-time configuration via
  /// `--dart-define-from-file=.env.<flavor>` when that file exists at the
  /// project root.
  ///
  /// Apps commonly read required config (API URLs, keys, the build env marker)
  /// through `String.fromEnvironment`, which is empty unless the defines are
  /// passed at build time. Without this, a `flow`-built release compiles and
  /// distributes fine but crashes on launch (stuck on the native splash) the
  /// moment it validates its missing env. Mirrors how a project's own flavor
  /// runner passes the defines. No file → no args, so this is safe for projects
  /// that don't use dart-define files.
  static List<String> _dartDefineArguments(String buildFlavor) {
    if (buildFlavor.isEmpty) return const [];
    final envFile = File('${Directory.current.path}/.env.$buildFlavor');
    if (!envFile.existsSync()) return const [];
    return ['--dart-define-from-file=.env.$buildFlavor'];
  }

  /// Extra environment variables exported to the native build so projects that
  /// gate builds behind a flavor guard (a Gradle/Xcode script that aborts unless
  /// it sees the expected flavor) succeed when invoked through `flow`.
  ///
  /// `FLOW_BUILD_FLAVOR` is the generic, tool-agnostic name guards should prefer.
  /// `SAMNAN_BUILD_FLAVOR` is kept for this project's existing guard. Anything
  /// already set in the caller's environment still wins for other variables —
  /// these only add the flavor signal. A guard that doesn't read them is
  /// unaffected, so this is safe for any project.
  static Map<String, String> _flavorEnvironment(String buildFlavor) {
    if (buildFlavor.isEmpty) return const {};
    return {
      'FLOW_BUILD_FLAVOR': buildFlavor,
      'SAMNAN_BUILD_FLAVOR': buildFlavor,
    };
  }

  static Future<void> _cleanupLegacyFlutterAndroidArtifacts() async {
    final manifestFile = File(
      '${Directory.current.path}/android/app/src/main/AndroidManifest.xml',
    );
    final registrantFile = File(
      '${Directory.current.path}/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java',
    );

    if (!manifestFile.existsSync() || !registrantFile.existsSync()) {
      return;
    }

    final manifestContent = await manifestFile.readAsString();
    final usesFlutterEmbeddingV2 =
        manifestContent.contains('android:name="flutterEmbedding"') &&
        manifestContent.contains('android:value="2"');

    if (!usesFlutterEmbeddingV2) {
      return;
    }

    await registrantFile.delete();
    logger.detail(
      'Removed legacy GeneratedPluginRegistrant.java for Flutter embedding v2',
    );
  }
}
