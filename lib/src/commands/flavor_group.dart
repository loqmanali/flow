import 'package:args/command_runner.dart';

import '../flavor/commands/add_command.dart' as flavor;
import '../flavor/commands/build_command.dart' as flavor;
import '../flavor/commands/delete_command.dart' as flavor;
import '../flavor/commands/firebase_command.dart' as flavor;
import '../flavor/commands/init_command.dart' as flavor;
import '../flavor/commands/migrate_command.dart' as flavor;
import '../flavor/commands/replace_command.dart' as flavor;
import '../flavor/commands/reset_command.dart' as flavor;
import '../flavor/commands/run_command.dart' as flavor;

/// `flow flavor <sub>` — all flavor-management subcommands.
class FlavorGroupCommand extends Command<int> {
  FlavorGroupCommand() {
    addSubcommand(_FlavorInit());
    addSubcommand(_FlavorAdd());
    addSubcommand(_FlavorDelete());
    addSubcommand(_FlavorReplace());
    addSubcommand(_FlavorReset());
    addSubcommand(_FlavorRun());
    addSubcommand(_FlavorBuild());
    addSubcommand(_FlavorFirebase());
    addSubcommand(_FlavorMigrate());
  }

  @override
  String get name => 'flavor';

  @override
  String get description => 'Configure and manage Flutter build flavors.';
}

class _FlavorInit extends Command<int> {
  _FlavorInit() {
    argParser.addOption(
      'from',
      help: 'Path to an existing .flow_flavor.json (non-interactive setup).',
    );
  }

  @override
  String get name => 'init';

  @override
  String get description => 'Initialize flavor setup in the current project.';

  @override
  Future<int> run() async {
    final from = argResults?['from'] as String?;
    await flavor.InitCommand().execute([if (from != null) '--from=$from']);
    return 0;
  }
}

class _FlavorAdd extends Command<int> {
  @override
  String get name => 'add';

  @override
  String get description => 'Add a new flavor to an existing setup.';

  @override
  String get invocation => 'flow flavor add [<name>]';

  @override
  Future<int> run() async {
    await flavor.AddCommand().execute(argResults?.rest ?? const []);
    return 0;
  }
}

class _FlavorDelete extends Command<int> {
  @override
  String get name => 'delete';

  @override
  String get description => 'Remove an existing flavor and its artifacts.';

  @override
  String get invocation => 'flow flavor delete [<name>]';

  @override
  Future<int> run() async {
    await flavor.DeleteCommand().execute(argResults?.rest ?? const []);
    return 0;
  }
}

class _FlavorReplace extends Command<int> {
  @override
  String get name => 'replace';

  @override
  String get description => 'Atomically rename an existing flavor across the project.';

  @override
  Future<int> run() async {
    await flavor.ReplaceCommand().execute();
    return 0;
  }
}

class _FlavorReset extends Command<int> {
  @override
  String get name => 'reset';

  @override
  String get description => 'Revert the project to its original, non-flavored state.';

  @override
  Future<int> run() async {
    flavor.ResetCommand().execute();
    return 0;
  }
}

class _FlavorRun extends Command<int> {
  @override
  String get name => 'run';

  @override
  String get description => 'Run the project with a specific flavor (wraps flutter run).';

  @override
  String get invocation => 'flow flavor run [<flavor>] [<mode>]';

  @override
  Future<int> run() async {
    await flavor.RunCommand().execute(argResults?.rest ?? const []);
    return 0;
  }
}

class _FlavorBuild extends Command<int> {
  @override
  String get name => 'build';

  @override
  String get description => 'Build the project for a specific flavor (wraps flutter build).';

  @override
  String get invocation => 'flow flavor build [<target>] [<flavor>]';

  @override
  Future<int> run() async {
    await flavor.BuildCommand().execute(argResults?.rest ?? const []);
    return 0;
  }
}

class _FlavorFirebase extends Command<int> {
  _FlavorFirebase() {
    argParser.addOption(
      'flavor',
      abbr: 'f',
      help: 'Configure a single flavor instead of all flavors.',
    );
  }

  @override
  String get name => 'firebase';

  @override
  String get description => 'Configure Firebase for all flavors via flutterfire.';

  @override
  Future<int> run() async {
    final single = argResults?['flavor'] as String?;
    await flavor.FirebaseCommand().execute(targetFlavor: single);
    return 0;
  }
}

class _FlavorMigrate extends Command<int> {
  @override
  String get name => 'migrate';

  @override
  String get description => 'Migrate .flow_flavor.json to the latest schema.';

  @override
  Future<int> run() async {
    await flavor.MigrateCommand().execute();
    return 0;
  }
}
