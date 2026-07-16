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
    String buildTarget = '',
    String dartDefineFromFile = '',
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
          await buildAndroidApk(
            buildFlavor: buildFlavor,
            buildTarget: buildTarget,
            dartDefineFromFile: dartDefineFromFile,
          );
        } else {
          await buildAndroidAppBundle(
            buildFlavor: buildFlavor,
            buildTarget: buildTarget,
            dartDefineFromFile: dartDefineFromFile,
          );
        }
        await buildIOS(
          buildFlavor: buildFlavor,
          buildTarget: buildTarget,
          dartDefineFromFile: dartDefineFromFile,
        );
        break;
      case DeployPlatform.ios:
        await buildIOS(
          buildFlavor: buildFlavor,
          buildTarget: buildTarget,
          dartDefineFromFile: dartDefineFromFile,
        );
        break;
      case DeployPlatform.android:
        if (mode == DeployMode.beta) {
          await buildAndroidApk(
            buildFlavor: buildFlavor,
            buildTarget: buildTarget,
            dartDefineFromFile: dartDefineFromFile,
          );
        } else {
          await buildAndroidAppBundle(
            buildFlavor: buildFlavor,
            buildTarget: buildTarget,
            dartDefineFromFile: dartDefineFromFile,
          );
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

  static Future<void> buildAndroidApk({
    String buildFlavor = '',
    String buildTarget = '',
    String dartDefineFromFile = '',
  }) async {
    if (await _runProjectFlavorBuild('apk', buildFlavor)) return;

    final arguments = [
      'build',
      'apk',
      '--release',
      ...flavorBuildArguments(buildFlavor, buildTarget, dartDefineFromFile),
    ];
    await ProcessRunner.runCommand(
      'flutter',
      arguments: arguments,
      description: 'Building Android APK',
      environment: _flavorEnvironment(buildFlavor),
    );
  }

  static Future<void> buildAndroidAppBundle({
    String buildFlavor = '',
    String buildTarget = '',
    String dartDefineFromFile = '',
  }) async {
    if (await _runProjectFlavorBuild('appbundle', buildFlavor)) return;

    final arguments = [
      'build',
      'appbundle',
      '--release',
      '--obfuscate',
      '--split-debug-info=build/app/outputs/symbols',
      ...flavorBuildArguments(buildFlavor, buildTarget, dartDefineFromFile),
    ];
    await ProcessRunner.runCommand(
      'flutter',
      arguments: arguments,
      description: 'Building Android AppBundle',
      environment: _flavorEnvironment(buildFlavor),
    );
  }

  static Future<void> buildIOS({
    String buildFlavor = '',
    String buildTarget = '',
    String dartDefineFromFile = '',
  }) async {
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
      ...flavorBuildArguments(buildFlavor, buildTarget, dartDefineFromFile),
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

  /// Resolves the flavor/target/dart-define arguments for a `flutter build`.
  /// Public so both the CLI and embedders (Flow Studio) can verify what a
  /// deploy would pass without running a build.
  /// [projectDir] defaults to the current working directory — the project a
  /// deploy runs against. It is injectable so callers (and tests) can resolve
  /// against a directory without mutating process-wide `Directory.current`.
  static List<String> flavorBuildArguments(
    String buildFlavor,
    String buildTarget,
    String dartDefineFromFile, {
    String? projectDir,
  }) {
    final arguments = <String>[];
    if (buildFlavor.isNotEmpty) {
      // An explicitly configured target wins; otherwise fall back to the
      // `lib/main_<flavor>.dart` convention. Projects whose entrypoints don't
      // follow that naming would silently build the wrong target without this.
      final target = buildTarget.isNotEmpty ? buildTarget : 'lib/main_$buildFlavor.dart';
      arguments.addAll(['--flavor', buildFlavor, '--target', target]);
    } else if (buildTarget.isNotEmpty) {
      arguments.addAll(['--target', buildTarget]);
    }
    arguments.addAll(
      dartDefineArguments(buildFlavor, dartDefineFromFile, projectDir: projectDir),
    );
    return arguments;
  }

  /// Resolves the `--dart-define-from-file` argument for a build.
  ///
  /// Apps commonly read required config (API URLs, keys, the build env marker)
  /// through `String.fromEnvironment`, which is empty unless the defines are
  /// passed at build time. Without this, a `flow`-built release compiles and
  /// distributes fine but is dead on launch — pointing at placeholder hosts or
  /// stuck on the native splash — the moment it reads its missing env.
  ///
  /// Resolution order:
  ///  1. An explicit `build.dart_define_from_file` — a missing file here is a
  ///     hard error, since the project asked for a config that isn't there.
  ///     Silently dropping it is what ships a broken release.
  ///  2. The `.env.<flavor>` convention, when that file exists.
  ///  3. Nothing — but warn when a flavor is set, because a flavored release
  ///     with no defines is far more likely a misconfiguration than intent.
  ///
  /// [projectDir] defaults to the current working directory; see
  /// [flavorBuildArguments].
  static List<String> dartDefineArguments(
    String buildFlavor,
    String dartDefineFromFile, {
    String? projectDir,
  }) {
    final root = projectDir ?? Directory.current.path;
    if (dartDefineFromFile.isNotEmpty) {
      final configured = File('$root/$dartDefineFromFile');
      if (!configured.existsSync()) {
        throw Exception(
          'dart_define_from_file "$dartDefineFromFile" not found at ${configured.path}.\n'
          'Fix the path in .flow_deploy.json, or remove it to use the .env.<flavor> convention.',
        );
      }
      return ['--dart-define-from-file=$dartDefineFromFile'];
    }

    if (buildFlavor.isEmpty) return const [];

    final conventional = File('$root/.env.$buildFlavor');
    if (conventional.existsSync()) {
      return ['--dart-define-from-file=.env.$buildFlavor'];
    }

    logger.warn(
      'No dart-define file for flavor "$buildFlavor": .env.$buildFlavor not found '
      'and build.dart_define_from_file is not set. Building without compile-time '
      'config — if the app reads String.fromEnvironment, this artifact will be broken.',
    );
    return const [];
  }

  /// Extra environment variables exported to the native build so projects that
  /// gate builds behind a flavor guard (a Gradle/Xcode script that aborts unless
  /// it sees the expected flavor) succeed when invoked through `flow`.
  ///
  /// `FLOW_BUILD_FLAVOR` is the single, tool-agnostic name a guard should read.
  /// Anything already set in the caller's environment still wins for other
  /// variables — this only adds the flavor signal. A guard that doesn't read it
  /// is unaffected, so this is safe for any project.
  static Map<String, String> _flavorEnvironment(String buildFlavor) {
    if (buildFlavor.isEmpty) return const {};
    return {'FLOW_BUILD_FLAVOR': buildFlavor};
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
