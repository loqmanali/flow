import 'dart:io';
import '../flow_config.dart';
import '../constants.dart';
import '../logger.dart';
import 'package:mason_logger/mason_logger.dart' show lightCyan;
import 'deploy_command.dart';
import 'init_command.dart';

class DeployWizard {
  final DeployConfig _deployConfig = DeployConfig.instance;

  Future<void> run() async {
    logger.info('');
    final action = logger.chooseOne(
      'What do you want to do?',
      choices: [
        'Deploy a profile',
        'Beta (build & upload for testing)',
        'Update (build & submit to stores)',
        'Initialize configuration',
      ],
    );

    switch (action) {
      case 'Initialize configuration':
        await InitCommand().execute();
        break;
      case 'Deploy a profile':
        await _deployProfile();
        break;
      case 'Beta (build & upload for testing)':
        await DeployCommand().execute('beta', []);
        break;
      case 'Update (build & submit to stores)':
        await DeployCommand().execute('update', []);
        break;
    }
  }

  Future<void> _deployProfile() async {
    final configFile = File(Constants.deployConfigFilePath);
    if (!configFile.existsSync()) {
      logger.err('No configuration found.');
      logger.err(
        'Run ${lightCyan.wrap('deploy init')} first to set up your configuration.',
      );
      return;
    }

    await _deployConfig.load();
    final profiles = _deployConfig.profileNames;

    if (profiles.isEmpty) {
      logger.err('No profiles configured.');
      logger.err(
        'Run ${lightCyan.wrap('deploy init')} to generate profiles.',
      );
      return;
    }

    final profileName = logger.chooseOne(
      'Select a profile to deploy:',
      choices: profiles,
    );

    logger.info('');
    await DeployCommand().execute(profileName, []);
  }
}
