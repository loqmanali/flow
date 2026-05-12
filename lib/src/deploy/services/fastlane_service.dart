import 'dart:io';
import '../flow_enums.dart';
import '../constants.dart';
import '../logger.dart';
import '../templates.dart';
import '../utils.dart';
import '../pubspec_utils.dart';
import '../process_runner.dart';

class FastlaneService {
  static Future<bool> isInstalled() async {
    try {
      await ProcessRunner.runCommand(
        'fastlane',
        arguments: ['--version'],
        description: 'Checking Fastlane',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> initialize({
    required DeployPlatform platform,
    required DeployMode mode,
    required String buildFlavor,
    required Map<String, dynamic> resolvedIosConfig,
    required Map<String, dynamic> resolvedAndroidConfig,
    required bool skipBuild,
  }) async {
    final progress = logger.progress('Initializing Fastlane');
    if (!await isInstalled()) {
      progress.fail();
      throw Exception(
        'Error: Fastlane is not installed. Please install fastlane and try again.',
      );
    }
    if (platform == DeployPlatform.all) {
      await _initializeIos(
        mode: mode,
        buildFlavor: buildFlavor,
        resolvedIosConfig: resolvedIosConfig,
        skipBuild: skipBuild,
      );
      await _initializeAndroid(
        buildFlavor: buildFlavor,
        resolvedAndroidConfig: resolvedAndroidConfig,
      );
    } else if (platform == DeployPlatform.ios) {
      await _initializeIos(
        mode: mode,
        buildFlavor: buildFlavor,
        resolvedIosConfig: resolvedIosConfig,
        skipBuild: skipBuild,
      );
    } else if (platform == DeployPlatform.android) {
      await _initializeAndroid(
        buildFlavor: buildFlavor,
        resolvedAndroidConfig: resolvedAndroidConfig,
      );
    }
    progress.complete('Fastlane initialized');
  }

  static Future<void> _initializeIos({
    required DeployMode mode,
    required String buildFlavor,
    required Map<String, dynamic> resolvedIosConfig,
    required bool skipBuild,
  }) async {
    try {
      final iosDir = Directory(Constants.iosDirPath);
      if (!iosDir.existsSync()) {
        throw Exception(
          'iOS directory not found at ${Constants.iosDirPath}. Ensure this is a valid Flutter project with an iOS module.',
        );
      }

      final fastlaneDir = Directory(Constants.iosFastlaneDirPath);
      if (!fastlaneDir.existsSync()) {
        await fastlaneDir.create(recursive: true);
      }

      await _createIosFastfile(
        resolvedIosConfig: resolvedIosConfig,
        skipBuild: skipBuild,
      );
    } catch (e) {
      throw Exception('Failed to initialize iOS Fastlane: $e');
    }
  }

  static Future<void> _initializeAndroid({
    required String buildFlavor,
    required Map<String, dynamic> resolvedAndroidConfig,
  }) async {
    try {
      final androidDir = Directory(Constants.androidDirPath);
      if (!androidDir.existsSync()) {
        throw Exception(
          'Android directory not found at ${Constants.androidDirPath}. Ensure this is a valid Flutter project with an Android module.',
        );
      }

      final fastlaneDir = Directory(Constants.androidFastlaneDirPath);
      if (!fastlaneDir.existsSync()) {
        await fastlaneDir.create(recursive: true);
      }

      await _createAndroidFastfile(
        buildFlavor: buildFlavor,
        resolvedAndroidConfig: resolvedAndroidConfig,
      );
    } on Exception catch (e) {
      throw Exception('Failed to initialize Android Fastlane: $e');
    }
  }

  static Future<void> _createIosFastfile({
    required Map<String, dynamic> resolvedIosConfig,
    required bool skipBuild,
  }) async {
    try {
      final appStoreConfig = resolvedIosConfig['app_store_connect'] as Map<String, dynamic>?;

      if (appStoreConfig == null) {
        throw Exception(
          'Missing ios.app_store_connect in .flow_deploy.json',
        );
      }

      final keyId = appStoreConfig['key_id']?.toString();
      final issuerId = appStoreConfig['issuer_id']?.toString();
      final keyFilepath = appStoreConfig['key_filepath']?.toString();

      if ((keyId?.isEmpty ?? true) ||
          (issuerId?.isEmpty ?? true) ||
          (keyFilepath?.isEmpty ?? true)) {
        throw Exception(
          'Missing key_id, issuer_id, or key_filepath in .flow_deploy.json',
        );
      }

      final appIdentifier =
          _optionalString(resolvedIosConfig['app_identifier']) ?? await Utils.iosBundleId;

      final testflightConfig = resolvedIosConfig['testflight'] as Map<String, dynamic>?;
      final enableExternalTesting = testflightConfig?['enable_external_testing'] as bool? ?? false;

      String externalTestingConfig = '';
      if (enableExternalTesting) {
        externalTestingConfig = _buildExternalTestingConfig(testflightConfig!);
      }

      const fastlaneTemplate = Templates.iosFastFileContent;

      if ([
        '%key_id%',
        '%issuer_id%',
        '%key_filepath%',
        '%display_name%',
        '%app_identifier%',
      ].any((placeholder) => !fastlaneTemplate.contains(placeholder))) {
        throw Exception(
          'Error: Missing one of the required placeholders in the iOS Fastlane template: %key_id%, %issuer_id%, %key_filepath%, %display_name%, %app_identifier%',
        );
      }

      String fastlaneContent = fastlaneTemplate
          .replaceAll('%key_id%', keyId!)
          .replaceAll('%issuer_id%', issuerId!)
          .replaceAll('%key_filepath%', keyFilepath!)
          .replaceAll('%app_identifier%', appIdentifier)
          .replaceAll(
            '%enable_external_testing%',
            enableExternalTesting.toString(),
          )
          .replaceAll('%external_testing_config%', externalTestingConfig);

      if (skipBuild) {
        final iosIpaName = await Utils.iosIpaName;
        fastlaneContent = fastlaneContent.replaceAll(
          '%display_name%',
          iosIpaName,
        );
      }

      final fastfile = File(Constants.iosFastfilePath);
      await fastfile.writeAsString(fastlaneContent);
    } on Exception {
      rethrow;
    }
  }

  static String _buildExternalTestingConfig(
    Map<String, dynamic> testflightConfig,
  ) {
    final groups = testflightConfig['groups']?.toString();
    final betaAppFeedbackEmail = testflightConfig['beta_app_feedback_email']?.toString();
    final betaAppReviewInfo = testflightConfig['beta_app_review_info'] as Map<String, dynamic>?;

    if (groups?.isEmpty ?? true) {
      throw Exception(
        'Missing testflight.groups in .flow_deploy.json (required for external testing)',
      );
    }

    if (betaAppFeedbackEmail?.isEmpty ?? true) {
      throw Exception(
        'Missing testflight.beta_app_feedback_email in .flow_deploy.json (required for external testing)',
      );
    }

    if (betaAppReviewInfo == null) {
      throw Exception(
        'Missing testflight.beta_app_review_info in .flow_deploy.json (required for external testing)',
      );
    }

    final requiredReviewFields = [
      'contact_email',
      'contact_first_name',
      'contact_last_name',
      'contact_phone',
    ];

    for (final field in requiredReviewFields) {
      final value = betaAppReviewInfo[field]?.toString();
      if (value?.isEmpty ?? true) {
        throw Exception(
          'Missing testflight.beta_app_review_info.$field in .flow_deploy.json (required for external testing)',
        );
      }
    }

    final demoAccountRequired = betaAppReviewInfo['demo_account_required'] as bool? ?? false;

    if (demoAccountRequired) {
      final demoAccountFields = ['demo_account_name', 'demo_account_password'];
      for (final field in demoAccountFields) {
        final value = betaAppReviewInfo[field]?.toString();
        if (value?.isEmpty ?? true) {
          throw Exception(
            'Missing testflight.beta_app_review_info.$field in .flow_deploy.json (required when demo_account_required is true)',
          );
        }
      }
    }

    final notes = betaAppReviewInfo['notes']?.toString() ?? '';
    final buffer = StringBuffer();
    buffer.writeln();
    buffer.writeln('      groups: "$groups",');
    buffer.writeln('      beta_app_feedback_email: "$betaAppFeedbackEmail",');
    buffer.writeln('      beta_app_review_info: {');
    buffer.writeln(
      '        contact_email: "${betaAppReviewInfo['contact_email']}",',
    );
    buffer.writeln(
      '        contact_first_name: "${betaAppReviewInfo['contact_first_name']}",',
    );
    buffer.writeln(
      '        contact_last_name: "${betaAppReviewInfo['contact_last_name']}",',
    );
    buffer.writeln(
      '        contact_phone: "${betaAppReviewInfo['contact_phone']}",',
    );
    buffer.writeln('        demo_account_required: $demoAccountRequired,');
    if (demoAccountRequired) {
      buffer.writeln(
        '        demo_account_name: "${betaAppReviewInfo['demo_account_name']}",',
      );
      buffer.writeln(
        '        demo_account_password: "${betaAppReviewInfo['demo_account_password']}",',
      );
    }
    if (notes.isNotEmpty) {
      buffer.writeln('        notes: "$notes",');
    }
    buffer.write('      },');
    return buffer.toString();
  }

  static Future<void> _createAndroidFastfile({
    required String buildFlavor,
    required Map<String, dynamic> resolvedAndroidConfig,
  }) async {
    try {
      final jsonKeyPath = resolvedAndroidConfig['json_key_path']?.toString();
      final packageName =
          _optionalString(resolvedAndroidConfig['package_name']) ?? await Utils.androidPackageName;
      final aabPath = Utils.androidAabPath(flavor: buildFlavor);
      final mappingPath = Utils.androidMappingPath(flavor: buildFlavor);

      if (jsonKeyPath?.isEmpty ?? true) {
        throw Exception('Missing json_key_path in .flow_deploy.json');
      }

      const fastlaneTemplate = Templates.androidFastFileContent;

      final fastlaneContent = fastlaneTemplate
          .replaceAll('%json_key_path%', jsonKeyPath!)
          .replaceAll('%package_name%', packageName)
          .replaceAll('%aab_path%', aabPath)
          .replaceAll('%mapping_path%', mappingPath);

      final fastfile = File(Constants.androidFastfilePath);
      await fastfile.writeAsString(fastlaneContent);

      logger.detail(
        'Android Fastfile created at ${Constants.androidFastfilePath}',
      );
    } on Exception {
      rethrow;
    }
  }

  static Future<void> uploadToTestFlight() async {
    await ProcessRunner.runCommand(
      'fastlane',
      arguments: ['beta'],
      description: 'Uploading to TestFlight',
      workingDir: 'ios',
    );
  }

  static Future<void> handleIOSUpdateBuild(
    Map<String, dynamic> resolvedIosConfig,
  ) async {
    try {
      final Map<String, dynamic>? changeLog =
          resolvedIosConfig['changelog'] as Map<String, dynamic>?;
      if (changeLog == null || changeLog.isEmpty) {
        throw Exception(
          'Changelog required for update mode\nNo changelog found in .flow_deploy.json',
        );
      } else {
        for (final locale in changeLog.keys) {
          final message = changeLog[locale] as String;
          if (message.isEmpty) {
            throw Exception(
              'Changelog required for update mode\nNo changelog found in .flow_deploy.json',
            );
          }
        }
      }

      logger.detail('Changelog extracted successfully.');

      final deliverFile = File(Constants.iosDeliverfilePath);
      if (!deliverFile.existsSync()) {
        deliverFile.createSync();
        logger.detail(
          'Deliverfile not found at ${Constants.iosDeliverfilePath}, creating...',
        );
      }

      String content = await deliverFile.readAsString();

      final buffer = StringBuffer('\nrelease_notes({');
      for (final locale in changeLog.keys) {
        final message = changeLog[locale] as String;
        final escapedMessage = message.replaceAll('"', r'\"').replaceAll('\n', r'\n');
        buffer.writeln("  '$locale' => \"$escapedMessage\",");
      }
      buffer.write('})');
      final releaseNotesContent = buffer.toString();

      final releaseNotesPattern = RegExp(
        r'release_notes\s*\(\s*\{[^}]*\}\s*\)',
        multiLine: true,
      );

      if (releaseNotesPattern.hasMatch(content)) {
        logger.detail('Existing release notes found. Replacing...');
        content = content.replaceFirst(
          releaseNotesPattern,
          releaseNotesContent,
        );
      } else {
        logger.detail('No existing release notes found. Appending...');
        content += releaseNotesContent;
      }

      await deliverFile.writeAsString(content);
      logger.detail('Deliverfile updated successfully.');

      await ProcessRunner.runCommand(
        'fastlane',
        arguments: ['new_update'],
        description: 'Uploading iOS update to distribution',
        workingDir: 'ios',
      );
    } on Exception {
      rethrow;
    }
  }

  static Future<void> handleAndroidUpdateBuild(
    Map<String, dynamic> resolvedAndroidConfig,
  ) async {
    try {
      final Map<String, dynamic>? changeLog =
          resolvedAndroidConfig['changelog'] as Map<String, dynamic>?;
      if (changeLog == null || changeLog.isEmpty) {
        throw Exception(
          'Changelog required for update mode\nNo changelog found in .flow_deploy.json',
        );
      } else {
        for (final locale in changeLog.keys) {
          final message = changeLog[locale] as String;
          if (message.isEmpty) {
            throw Exception(
              'Changelog required for update mode\nNo changelog found in .flow_deploy.json',
            );
          }
        }
      }

      logger.detail('Changelog extracted successfully.');

      final metadataDir = Directory(Constants.androidFastlaneMetadataDirPath);
      if (!metadataDir.existsSync()) {
        metadataDir.createSync();
      }

      final appVersion = await PubspecUtils.appVersion;
      final versionCode = appVersion.split('+').last;

      for (final locale in changeLog.keys) {
        final message = changeLog[locale] as String;
        final escapedMessage = message.replaceAll('"', r'\"').replaceAll('\n', r'\n');

        final changelogDirPath = '${metadataDir.path}/android/$locale/changelogs';
        final changelogsDir = Directory(changelogDirPath);

        if (!changelogsDir.existsSync()) {
          changelogsDir.createSync(recursive: true);
        } else {
          changelogsDir.listSync().forEach((file) {
            file.deleteSync();
          });
        }

        final changelogFile = File('$changelogDirPath/$versionCode.txt');
        if (!changelogFile.existsSync()) {
          changelogFile.createSync(recursive: true);
        }

        await changelogFile.writeAsString(escapedMessage);
        logger.detail('Changelog for $locale created in ${changelogFile.path}');
      }

      await ProcessRunner.runCommand(
        'fastlane',
        arguments: ['new_update'],
        description: 'Uploading Android update to distribution',
        workingDir: 'android',
      );
    } on Exception {
      rethrow;
    }
  }

  static String? _optionalString(dynamic value) {
    final stringValue = value?.toString().trim();
    if (stringValue == null || stringValue.isEmpty) return null;
    return stringValue;
  }
}
