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
    );
  }

  static Future<void> buildAndroidAppBundle({String buildFlavor = ''}) async {
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
    );
  }

  static Future<void> buildIOS({String buildFlavor = ''}) async {
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
    );
  }

  static List<String> _flavorBuildArguments(String buildFlavor) {
    final arguments = <String>[];
    if (buildFlavor.isNotEmpty) {
      arguments.addAll(['--flavor', buildFlavor]);
    }
    return arguments;
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
