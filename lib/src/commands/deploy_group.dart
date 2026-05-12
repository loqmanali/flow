import 'package:args/command_runner.dart';

import '../deploy/commands/deploy_command.dart' as deploy;
import '../deploy/commands/deploy_wizard.dart' as deploy;
import '../deploy/commands/init_command.dart' as deploy;
import '../deploy/commands/version_command.dart' as deploy;

/// `flow deploy <sub>` — build, version, and ship subcommands.
class DeployGroupCommand extends Command<int> {
  DeployGroupCommand() {
    addSubcommand(_DeployInit());
    addSubcommand(_DeployBeta());
    addSubcommand(_DeployUpdate());
    addSubcommand(_DeployVersion());
    addSubcommand(_DeployRun());
  }

  @override
  String get name => 'deploy';

  @override
  String get description =>
      'Build and ship to TestFlight, the stores, or Firebase App Distribution.';

  @override
  Future<int> run() async {
    // No subcommand given — launch the interactive wizard.
    await deploy.DeployWizard().run();
    return 0;
  }
}

class _DeployInit extends Command<int> {
  @override
  String get name => 'init';

  @override
  String get description => 'Initialize deployment configuration (.flow_deploy.json).';

  @override
  Future<int> run() async {
    await deploy.InitCommand().execute();
    return 0;
  }
}

abstract class _DeployActionBase extends Command<int> {
  // Concrete subclasses must supply the underlying deploy action name.
  _DeployActionBase() {
    argParser
      ..addOption('platform', abbr: 'p', allowed: ['ios', 'android'], help: 'Target platform.')
      ..addOption(
        'provider',
        abbr: 'r',
        allowed: ['fastlane', 'firebase', 'mixed'],
        help: 'Deployment provider.',
      )
      ..addOption(
        'flavor',
        abbr: 'f',
        help: 'Flutter flavor / Xcode scheme / Android product flavor.',
      )
      ..addOption('target', abbr: 't', help: 'Flutter target file (e.g. lib/main_staging.dart).')
      ..addFlag('skip-build', abbr: 's', help: 'Skip the build phase.', negatable: false)
      ..addFlag('increment-version', help: 'Bump patch + build number.', negatable: false)
      ..addFlag('skip-version-increment', help: 'Do not change pubspec version.', negatable: false);
  }

  String get _action;

  @override
  Future<int> run() async {
    final results = argResults!;
    final passthrough = <String>[];
    void carryOpt(String name) {
      final v = results[name];
      if (v is String && v.isNotEmpty) passthrough.addAll(['--$name', v]);
    }

    void carryFlag(String name) {
      if (results[name] == true) passthrough.add('--$name');
    }

    carryOpt('platform');
    carryOpt('provider');
    carryOpt('flavor');
    carryOpt('target');
    carryFlag('skip-build');
    carryFlag('increment-version');
    carryFlag('skip-version-increment');
    passthrough.addAll(results.rest);

    await deploy.DeployCommand().execute(_action, passthrough);
    return 0;
  }
}

class _DeployBeta extends _DeployActionBase {
  @override
  String get name => 'beta';

  @override
  String get description => 'Build and upload to TestFlight / Firebase App Distribution.';

  @override
  String get _action => 'beta';
}

class _DeployUpdate extends _DeployActionBase {
  @override
  String get name => 'update';

  @override
  String get description => 'Build and submit app updates to the stores.';

  @override
  String get _action => 'update';
}

class _DeployRun extends _DeployActionBase {
  @override
  String get name => 'run';

  @override
  String get description => 'Run a named deploy profile from .flow_deploy.json.';

  @override
  String get _action => 'run';

  @override
  String get invocation => 'flow deploy run <profile>';

  @override
  Future<int> run() async {
    final results = argResults!;
    if (results.rest.isEmpty) {
      usageException('Missing profile name. Usage: $invocation');
    }
    final profile = results.rest.first;
    final passthrough = <String>[];
    void carryOpt(String n) {
      final v = results[n];
      if (v is String && v.isNotEmpty) passthrough.addAll(['--$n', v]);
    }

    void carryFlag(String n) {
      if (results[n] == true) passthrough.add('--$n');
    }

    carryOpt('platform');
    carryOpt('provider');
    carryOpt('flavor');
    carryOpt('target');
    carryFlag('skip-build');
    carryFlag('increment-version');
    carryFlag('skip-version-increment');
    passthrough.addAll(results.rest.skip(1));

    await deploy.DeployCommand().execute(profile, passthrough);
    return 0;
  }
}

class _DeployVersion extends Command<int> {
  _DeployVersion() {
    argParser
      ..addFlag('major', negatable: false, help: 'Bump the major version.')
      ..addFlag('minor', negatable: false, help: 'Bump the minor version.')
      ..addFlag('patch', negatable: false, help: 'Bump the patch version.')
      ..addFlag('build', negatable: false, help: 'Bump the build number only.')
      ..addOption('set', help: 'Set an exact version (e.g. 2.0.0+1).');
  }

  @override
  String get name => 'version';

  @override
  String get description => 'Show or modify the pubspec version + build number.';

  @override
  Future<int> run() async {
    final results = argResults!;
    final args = <String>[];
    for (final flag in ['major', 'minor', 'patch', 'build']) {
      if (results[flag] == true) args.add('--$flag');
    }
    final set = results['set'] as String?;
    if (set != null && set.isNotEmpty) args.addAll(['--set', set]);
    await deploy.VersionCommand().execute(args);
    return 0;
  }
}
