import 'dart:io';
import '../constants.dart';
import '../logger.dart';
import '../templates.dart';

class InitCommand {
  Future<void> execute() async {
    final progress = logger.progress('Initializing deployment setup');

    if (File(Constants.gitignorePath).existsSync()) {
      const formattedPath = '/.flow_deploy.json';
      final gitignoreContent = File(Constants.gitignorePath).readAsStringSync();

      if (!gitignoreContent.contains(formattedPath)) {
        File(
          Constants.gitignorePath,
        ).writeAsStringSync('$gitignoreContent\n$formattedPath');
        logger.detail('Added $formattedPath to .gitignore');
      } else {
        logger.detail('$formattedPath already in .gitignore');
      }
    }

    progress.complete('Config directory prepared');

    logger.info(
      'Creating deployment config at ${Constants.deployConfigFilePath}...',
    );
    final configContent = _promptInitConfigTemplate();
    _writeToFile(Constants.deployConfigFilePath, content: configContent);
  }

  String _promptInitConfigTemplate() {
    final templateKind = logger.chooseOne(
      'Select config template to generate:',
      choices: ['Fastlane', 'Firebase App Distribution', 'Both'],
      defaultValue: 'Both',
    );

    late String templateContent;

    switch (templateKind) {
      case 'Fastlane':
        templateContent = Templates.deployConfigFastlaneContent;
        break;
      case 'Firebase App Distribution':
        templateContent = Templates.deployConfigFirebaseContent;
        break;
      case 'Both':
        templateContent = Templates.deployConfigContent;
        break;
    }

    final includeFlavorConfig = logger.confirm(
      'Include flavor configuration?',
    );
    if (includeFlavorConfig) {
      templateContent = Templates.withFlavorConfig(templateContent);
    }

    if (logger.confirm(
      'Generate deployment profiles like deploy dev?',
    )) {
      templateContent = Templates.withProfilesConfig(
        templateContent,
        templateKind:
            templateKind == 'Fastlane'
                ? 'fastlane'
                : templateKind == 'Firebase App Distribution'
                ? 'firebase'
                : 'both',
        includeFlavorConfig: includeFlavorConfig,
      );
    }

    return templateContent;
  }

  void _writeToFile(String path, {String? content}) {
    if (!File(path).existsSync()) {
      File(path).createSync();
      if (content != null) {
        File(path).writeAsStringSync(content);
      }
      logger.success('Created $path');
    } else {
      logger.warn('File $path already exists.');
    }
  }
}
