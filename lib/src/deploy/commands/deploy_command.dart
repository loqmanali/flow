import 'package:args/args.dart';
import '../flow_config.dart';
import '../flow_enums.dart';
import '../logger.dart';
import 'package:mason_logger/mason_logger.dart' show lightCyan;
import '../services/build_service.dart';
import '../services/fastlane_service.dart';
import '../services/firebase_service.dart';

class DeployCommand {
  final DeployConfig _deployConfig = DeployConfig.instance;

  Future<void> execute(String command, List<String> restArgs) async {
    final parser =
        ArgParser()
          ..addOption(
            'platform',
            allowed: ['ios', 'android'],
            help: 'Target platform',
            abbr: 'p',
          )
          ..addOption(
            'provider',
            allowed: ['fastlane', 'firebase', 'mixed'],
            help: 'Deployment provider',
            abbr: 'r',
          )
          ..addOption(
            'flavor',
            help: 'Flutter flavor / Xcode scheme / Android product flavor',
            abbr: 'f',
          )
          ..addOption(
            'target',
            help: 'Flutter target file, for example lib/main_staging.dart',
            abbr: 't',
          )
          ..addFlag('skip-build', abbr: 's', help: 'Skip build process')
          ..addFlag(
            'increment-version',
            help: 'Bump patch version and build number during deploy',
          )
          ..addFlag(
            'skip-version-increment',
            help: 'Keep the pubspec.yaml version unchanged during deploy',
          );

    final ArgResults args;

    try {
      args = parser.parse(restArgs);
    } catch (e) {
      throw Exception('Error parsing arguments: $e\n${parser.usage}');
    }

    await _deployConfig.load();

    final bool skipBuild = (args['skip-build'] as bool?) ?? false;
    final bool incrementVersion = (args['increment-version'] as bool?) ?? false;
    final bool skipVersionIncrementFlag = (args['skip-version-increment'] as bool?) ?? false;
    if (incrementVersion && skipVersionIncrementFlag) {
      throw Exception(
        'Use either --increment-version or --skip-version-increment, not both.',
      );
    }
    final bool skipVersionIncrement =
        !incrementVersion && (skipVersionIncrementFlag || _deployConfig.skipVersionIncrement);
    final bool isDirectCommand = ['beta', 'update'].contains(command);

    late DeployMode mode;
    late DeployPlatform platform;
    late DeployProvider provider;
    late String buildFlavor;
    late String buildTarget;
    late String dartDefineFromFile;
    late String selectedProfileName;
    Map<String, dynamic>? selectedProfile;

    if (isDirectCommand) {
      mode = _parseMode(command);
      platform = _parsePlatform(args['platform'] as String?) ?? _promptPlatform();
      provider = _parseProvider(args['provider'] as String?) ?? _promptProvider();
      buildFlavor = _firstNonEmpty([
        args['flavor'] as String?,
        _deployConfig.buildFlavor,
      ]);
      buildTarget = _firstNonEmpty([
        args['target'] as String?,
        _deployConfig.buildTarget,
      ]);
      dartDefineFromFile = _deployConfig.dartDefineFromFile;
      selectedProfileName = '';
      selectedProfile = null;
    } else {
      final profile = _deployConfig.profile(command);
      if (profile == null) {
        final availableProfiles = _deployConfig.profileNames;
        if (availableProfiles.isEmpty) {
          throw Exception(
            'No profiles are configured yet. Run deploy init to generate them.',
          );
        }
        throw Exception(
          'Unknown deployment profile "$command". Available profiles: ${availableProfiles.join(', ')}.',
        );
      }

      selectedProfileName = command;
      selectedProfile = profile;

      mode = _parseMode(_requiredProfileValue(profile, 'mode'));
      platform =
          _parsePlatform(args['platform'] as String?) ??
          _parsePlatform(_optionalString(profile['platform'])) ??
          _promptPlatform();
      provider =
          _parseProvider(args['provider'] as String?) ??
          _parseProvider(_optionalString(profile['provider'])) ??
          _promptProvider();
      buildFlavor = _firstNonEmpty([
        args['flavor'] as String?,
        _profileBuildValue(profile, 'flavor'),
        _deployConfig.buildFlavor,
      ]);
      buildTarget = _firstNonEmpty([
        args['target'] as String?,
        _profileBuildValue(profile, 'target'),
        _deployConfig.buildTarget,
      ]);
      // Each profile can point at its own env file (dev -> .env,
      // production -> .env.production), falling back to the root config.
      dartDefineFromFile = _firstNonEmpty([
        _profileBuildValue(profile, 'dart_define_from_file'),
        _deployConfig.dartDefineFromFile,
      ]);
    }

    if (provider == DeployProvider.mixed && platform != DeployPlatform.all) {
      throw Exception(
        'Mixed provider requires both platforms. Remove --platform or use --platform all.',
      );
    }

    logger.detail('Skipping build process: $skipBuild');
    logger.detail('Skipping version increment: $skipVersionIncrement');
    if (selectedProfileName.isNotEmpty) {
      logger.info('Deployment profile: ${lightCyan.wrap(selectedProfileName)}');
    }
    logger.info(
      'Deployment provider: ${lightCyan.wrap(_providerLabel(provider))}',
    );
    logger.info('Platform: ${lightCyan.wrap(platform.name)}');
    if (buildFlavor.isNotEmpty) {
      logger.info('Build flavor: ${lightCyan.wrap(buildFlavor)}');
    }
    if (buildTarget.isNotEmpty) {
      logger.info('Build target: ${lightCyan.wrap(buildTarget)}');
    }
    if (dartDefineFromFile.isNotEmpty) {
      logger.info('Build config: ${lightCyan.wrap(dartDefineFromFile)}');
    }

    final resolvedIosConfig = _mergeConfig(
      _deployConfig.ios,
      selectedProfile?['ios'] as Map<String, dynamic>?,
    );
    final resolvedAndroidConfig = _mergeConfig(
      _deployConfig.android,
      selectedProfile?['android'] as Map<String, dynamic>?,
    );

    await _initializeProvider(
      provider: provider,
      platform: platform,
      mode: mode,
      buildFlavor: buildFlavor,
      resolvedIosConfig: resolvedIosConfig,
      resolvedAndroidConfig: resolvedAndroidConfig,
    );

    if (!skipBuild) {
      await BuildService.runBuildProcess(
        platform: platform,
        mode: mode,
        buildFlavor: buildFlavor,
        buildTarget: buildTarget,
        dartDefineFromFile: dartDefineFromFile,
        skipVersionIncrement: skipVersionIncrement,
      );
    }

    switch (mode) {
      case DeployMode.beta:
        await _handleBetaBuild(
          platform: platform,
          provider: provider,
          buildFlavor: buildFlavor,
          resolvedIosConfig: resolvedIosConfig,
          resolvedAndroidConfig: resolvedAndroidConfig,
        );
        break;
      case DeployMode.update:
        await _handleUpdateBuild(
          platform: platform,
          provider: provider,
          resolvedIosConfig: resolvedIosConfig,
          resolvedAndroidConfig: resolvedAndroidConfig,
        );
        break;
      case DeployMode.none:
        break;
    }
  }

  String _providerLabel(DeployProvider provider) {
    return switch (provider) {
      DeployProvider.fastlane => 'fastlane',
      DeployProvider.firebase => 'firebase',
      DeployProvider.mixed => 'mixed (android→firebase, ios→fastlane)',
    };
  }

  Future<void> _initializeProvider({
    required DeployProvider provider,
    required DeployPlatform platform,
    required DeployMode mode,
    required String buildFlavor,
    required Map<String, dynamic> resolvedIosConfig,
    required Map<String, dynamic> resolvedAndroidConfig,
  }) async {
    switch (provider) {
      case DeployProvider.fastlane:
        await FastlaneService.initialize(
          platform: platform,
          mode: mode,
          buildFlavor: buildFlavor,
          resolvedIosConfig: resolvedIosConfig,
          resolvedAndroidConfig: resolvedAndroidConfig,
        );
        break;
      case DeployProvider.firebase:
        await FirebaseService.initialize(
          mode: mode,
          platform: platform,
          resolvedIosConfig: resolvedIosConfig,
          resolvedAndroidConfig: resolvedAndroidConfig,
        );
        break;
      case DeployProvider.mixed:
        await FastlaneService.initialize(
          platform: DeployPlatform.ios,
          mode: mode,
          buildFlavor: buildFlavor,
          resolvedIosConfig: resolvedIosConfig,
          resolvedAndroidConfig: resolvedAndroidConfig,
        );
        await FirebaseService.initialize(
          mode: mode,
          platform: DeployPlatform.android,
          resolvedIosConfig: resolvedIosConfig,
          resolvedAndroidConfig: resolvedAndroidConfig,
        );
        break;
    }
  }

  DeployPlatform _promptPlatform() {
    final choice = logger.chooseOne(
      'Select platform:',
      choices: ['All', 'iOS', 'Android'],
    );
    return switch (choice) {
      'iOS' => DeployPlatform.ios,
      'Android' => DeployPlatform.android,
      _ => DeployPlatform.all,
    };
  }

  DeployProvider _promptProvider() {
    final choice = logger.chooseOne(
      'Select provider:',
      choices: [
        'Fastlane',
        'Firebase App Distribution',
        'Mixed (Android→Firebase, iOS→Fastlane)',
      ],
    );
    return switch (choice) {
      'Firebase App Distribution' => DeployProvider.firebase,
      'Mixed (Android→Firebase, iOS→Fastlane)' => DeployProvider.mixed,
      _ => DeployProvider.fastlane,
    };
  }

  Future<void> _handleBetaBuild({
    required DeployPlatform platform,
    required DeployProvider provider,
    required String buildFlavor,
    required Map<String, dynamic> resolvedIosConfig,
    required Map<String, dynamic> resolvedAndroidConfig,
  }) async {
    switch (provider) {
      case DeployProvider.firebase:
        await _uploadAllPlatformsToFirebase(
          platform,
          buildFlavor,
          resolvedIosConfig,
          resolvedAndroidConfig,
        );
        return;
      case DeployProvider.mixed:
        await FirebaseService.uploadToFirebaseAppDistribution(
          targetPlatform: DeployPlatform.android,
          buildFlavor: buildFlavor,
          resolvedIosConfig: resolvedIosConfig,
          resolvedAndroidConfig: resolvedAndroidConfig,
        );
        await FastlaneService.uploadToTestFlight();
        return;
      case DeployProvider.fastlane:
        break;
    }

    switch (platform) {
      case DeployPlatform.all:
        await FastlaneService.uploadToTestFlight();
        logger.warn(
          'Android beta builds are created locally only when using fastlane. Use --provider firebase to distribute Android betas.',
        );
        break;
      case DeployPlatform.ios:
        await FastlaneService.uploadToTestFlight();
        break;
      case DeployPlatform.android:
        throw Exception(
          'Android beta distribution is not supported with fastlane in this tool. Use --provider firebase instead.',
        );
    }
  }

  Future<void> _uploadAllPlatformsToFirebase(
    DeployPlatform platform,
    String buildFlavor,
    Map<String, dynamic> resolvedIosConfig,
    Map<String, dynamic> resolvedAndroidConfig,
  ) async {
    switch (platform) {
      case DeployPlatform.all:
        await FirebaseService.uploadToFirebaseAppDistribution(
          targetPlatform: DeployPlatform.android,
          buildFlavor: buildFlavor,
          resolvedIosConfig: resolvedIosConfig,
          resolvedAndroidConfig: resolvedAndroidConfig,
        );
        await FirebaseService.uploadToFirebaseAppDistribution(
          targetPlatform: DeployPlatform.ios,
          buildFlavor: buildFlavor,
          resolvedIosConfig: resolvedIosConfig,
          resolvedAndroidConfig: resolvedAndroidConfig,
        );
        break;
      case DeployPlatform.ios:
        await FirebaseService.uploadToFirebaseAppDistribution(
          targetPlatform: DeployPlatform.ios,
          buildFlavor: buildFlavor,
          resolvedIosConfig: resolvedIosConfig,
          resolvedAndroidConfig: resolvedAndroidConfig,
        );
        break;
      case DeployPlatform.android:
        await FirebaseService.uploadToFirebaseAppDistribution(
          targetPlatform: DeployPlatform.android,
          buildFlavor: buildFlavor,
          resolvedIosConfig: resolvedIosConfig,
          resolvedAndroidConfig: resolvedAndroidConfig,
        );
        break;
    }
  }

  Future<void> _handleUpdateBuild({
    required DeployPlatform platform,
    required DeployProvider provider,
    required Map<String, dynamic> resolvedIosConfig,
    required Map<String, dynamic> resolvedAndroidConfig,
  }) async {
    if (provider == DeployProvider.mixed) {
      await FastlaneService.handleIOSUpdateBuild(resolvedIosConfig);
      await FastlaneService.handleAndroidUpdateBuild(resolvedAndroidConfig);
      return;
    }

    switch (platform) {
      case DeployPlatform.all:
        await FastlaneService.handleIOSUpdateBuild(resolvedIosConfig);
        await FastlaneService.handleAndroidUpdateBuild(resolvedAndroidConfig);
        break;
      case DeployPlatform.ios:
        await FastlaneService.handleIOSUpdateBuild(resolvedIosConfig);
        break;
      case DeployPlatform.android:
        await FastlaneService.handleAndroidUpdateBuild(resolvedAndroidConfig);
        break;
    }
  }

  Map<String, dynamic> _mergeConfig(
    Map<String, dynamic> base,
    Map<String, dynamic>? override,
  ) {
    final merged = Map<String, dynamic>.from(base);
    if (override != null) {
      for (final entry in override.entries) {
        final baseValue = merged[entry.key];
        final overrideValue = entry.value;

        if (baseValue is Map && overrideValue is Map) {
          merged[entry.key] = _mergeConfig(
            Map<String, dynamic>.from(baseValue),
            Map<String, dynamic>.from(overrideValue),
          );
        } else {
          merged[entry.key] = overrideValue;
        }
      }
    }
    return merged;
  }

  String? _profileBuildValue(Map<String, dynamic> profile, String key) {
    final buildConfig = profile['build'] as Map<String, dynamic>?;
    return _optionalString(buildConfig?[key]) ?? _optionalString(profile[key]);
  }

  String _requiredProfileValue(Map<String, dynamic> profile, String key) {
    final value = _optionalString(profile[key]);
    if (value == null) {
      throw Exception(
        'Missing profiles value for $key in .flow_deploy.json',
      );
    }
    return value;
  }

  DeployMode _parseMode(String value) {
    final mode = value.trim().toLowerCase().toDeployMode();
    if (mode == DeployMode.none) {
      throw Exception(
        'Invalid deployment mode "$value". Must be one of: beta, update.',
      );
    }
    return mode;
  }

  DeployPlatform? _parsePlatform(String? value) {
    final normalized = _optionalString(value);
    if (normalized == null) {
      return null;
    }
    return normalized.toLowerCase().toDeployPlatform();
  }

  DeployProvider? _parseProvider(String? value) {
    final normalized = _optionalString(value?.toString().toLowerCase());
    if (normalized == null) {
      return null;
    }

    switch (normalized) {
      case 'fastlane':
      case 'firebase':
      case 'mixed':
        return normalized.toDeployProvider();
      default:
        throw Exception(
          'Invalid deployment provider "$value". Must be one of: fastlane, firebase, mixed.',
        );
    }
  }

  String _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final normalized = _optionalString(value);
      if (normalized != null) {
        return normalized;
      }
    }
    return '';
  }

  String? _optionalString(dynamic value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
