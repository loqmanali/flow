import 'dart:io';
import '../constants.dart';
import '../deploy_initializer.dart';
import '../logger.dart';

class InitCommand {
  Future<void> execute() async {
    final progress = logger.progress('Initializing deployment setup');

    if (File(Constants.gitignorePath).existsSync()) {
      const formattedPath = '/.flow_deploy.json';
      final alreadyIgnored =
          File(Constants.gitignorePath).readAsStringSync().contains(formattedPath);
      DeployConfigInitializer.ensureGitignored();
      if (alreadyIgnored) {
        logger.detail('$formattedPath already in .gitignore');
      } else {
        logger.detail('Added $formattedPath to .gitignore');
      }
    }

    progress.complete('Config directory prepared');

    logger.info(
      'Creating deployment config at ${Constants.deployConfigFilePath}...',
    );
    final configContent = _promptInitConfigTemplate();
    final created = DeployConfigInitializer.writeConfig(configContent);
    if (created) {
      logger.success('Created ${Constants.deployConfigFilePath}');
    } else {
      logger.warn('File ${Constants.deployConfigFilePath} already exists.');
    }
  }

  String _promptInitConfigTemplate() {
    final templateChoice = logger.chooseOne(
      'Select config template to generate:',
      choices: ['Fastlane', 'Firebase App Distribution', 'Both'],
      defaultValue: 'Both',
    );
    final templateKind = switch (templateChoice) {
      'Fastlane' => 'fastlane',
      'Firebase App Distribution' => 'firebase',
      _ => 'both',
    };

    final includeFlavorConfig = logger.confirm(
      'Include flavor configuration?',
    );
    final generateProfiles = logger.confirm(
      'Generate deployment profiles like deploy dev?',
    );

    return DeployConfigInitializer.composeTemplate(
      templateKind: templateKind,
      includeFlavorConfig: includeFlavorConfig,
      generateProfiles: generateProfiles,
    );
  }
}
