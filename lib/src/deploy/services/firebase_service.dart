import 'dart:io';
import '../flow_enums.dart';
import '../logger.dart';
import '../utils.dart';
import '../process_runner.dart';

class FirebaseService {
  static Future<bool> isInstalled() async {
    try {
      await ProcessRunner.runCommand(
        'firebase',
        arguments: ['--version'],
        description: 'Checking Firebase CLI',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> initialize({
    required DeployMode mode,
    required DeployPlatform platform,
    required Map<String, dynamic> resolvedIosConfig,
    required Map<String, dynamic> resolvedAndroidConfig,
  }) async {
    final progress = logger.progress('Initializing Firebase CLI');

    if (mode != DeployMode.beta) {
      progress.fail();
      throw Exception(
        'Error: Firebase provider currently supports beta mode only. Use fastlane for update mode.',
      );
    }

    if (!await isInstalled()) {
      progress.fail();
      throw Exception(
        'Error: Firebase CLI is not installed. Install firebase-tools and authenticate before using --provider firebase.',
      );
    }

    switch (platform) {
      case DeployPlatform.all:
        _validateDistributionConfig(DeployPlatform.android, resolvedAndroidConfig);
        _validateDistributionConfig(DeployPlatform.ios, resolvedIosConfig);
        break;
      case DeployPlatform.android:
        _validateDistributionConfig(platform, resolvedAndroidConfig);
        break;
      case DeployPlatform.ios:
        _validateDistributionConfig(platform, resolvedIosConfig);
        break;
    }

    progress.complete('Firebase CLI initialized');
  }

  static void _validateDistributionConfig(
    DeployPlatform targetPlatform,
    Map<String, dynamic> resolvedConfig,
  ) {
    final config = resolvedConfig['firebase_app_distribution'] as Map<String, dynamic>?;

    if (config == null) {
      throw Exception(
        'Missing ${targetPlatform.name}.firebase_app_distribution in .flow_deploy.json',
      );
    }

    final appId = config['app_id']?.toString().trim() ?? '';
    final groups = config['groups']?.toString().trim() ?? '';
    final testers = config['testers']?.toString().trim() ?? '';

    if (appId.isEmpty) {
      throw Exception(
        'Missing ${targetPlatform.name}.firebase_app_distribution.app_id in .flow_deploy.json',
      );
    }

    if (groups.isEmpty && testers.isEmpty) {
      throw Exception(
        'Provide either ${targetPlatform.name}.firebase_app_distribution.groups or testers in .flow_deploy.json',
      );
    }
  }

  static Future<void> uploadToFirebaseAppDistribution({
    required DeployPlatform targetPlatform,
    required String buildFlavor,
    required Map<String, dynamic> resolvedIosConfig,
    required Map<String, dynamic> resolvedAndroidConfig,
  }) async {
    final resolvedConfig =
        targetPlatform == DeployPlatform.android ? resolvedAndroidConfig : resolvedIosConfig;

    final config = resolvedConfig['firebase_app_distribution'] as Map<String, dynamic>;
    final artifactPath = await _firebaseArtifactPath(targetPlatform, buildFlavor);
    final appId = config['app_id']!.toString().trim();
    final groups = config['groups']?.toString().trim() ?? '';
    final testers = config['testers']?.toString().trim() ?? '';
    final releaseNotes = _firebaseReleaseNotes(targetPlatform, resolvedConfig);

    final arguments = [
      'appdistribution:distribute',
      artifactPath,
      '--app',
      appId,
    ];

    if (groups.isNotEmpty) {
      arguments.addAll(['--groups', groups]);
    }

    if (testers.isNotEmpty) {
      arguments.addAll(['--testers', testers]);
    }

    if (releaseNotes.isNotEmpty) {
      arguments.addAll(['--release-notes', releaseNotes]);
    }

    await ProcessRunner.runCommand(
      'firebase',
      arguments: arguments,
      description: 'Uploading ${targetPlatform.name} build to Firebase App Distribution',
    );
  }

  static Future<String> _firebaseArtifactPath(
    DeployPlatform targetPlatform,
    String buildFlavor,
  ) async {
    switch (targetPlatform) {
      case DeployPlatform.android:
        final apkFile = File(Utils.androidApkPath(flavor: buildFlavor));
        if (!apkFile.existsSync()) {
          throw Exception('Android APK not found at ${apkFile.path}');
        }
        return apkFile.path;
      case DeployPlatform.ios:
        return Utils.iosIpaPath;
      case DeployPlatform.all:
        throw Exception('A concrete platform is required for Firebase upload');
    }
  }

  static String _firebaseReleaseNotes(
    DeployPlatform targetPlatform,
    Map<String, dynamic> resolvedConfig,
  ) {
    final config = resolvedConfig['firebase_app_distribution'] as Map<String, dynamic>?;
    final releaseNotes = config?['release_notes']?.toString().trim() ?? '';
    if (releaseNotes.isNotEmpty) return releaseNotes;

    final changelogSource = resolvedConfig['changelog'];
    if (changelogSource is Map<String, dynamic>) {
      for (final value in changelogSource.values) {
        final message = value?.toString().trim() ?? '';
        if (message.isNotEmpty) return message;
      }
    }

    return '';
  }
}
