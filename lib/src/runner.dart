import 'package:args/command_runner.dart';

import 'commands/deploy_group.dart';
import 'commands/flavor_group.dart';
import 'create/commands/create_command.dart';
import 'shared/version_reader.dart';

/// Constructs the top-level [CommandRunner] for the `flow` CLI.
///
/// Exposed as a factory so tests can build it without spawning subprocesses.
Future<CommandRunner<int>> buildFlowRunner() async {
  final version = await readFlowVersion();
  final runner = CommandRunner<int>(
    'flow',
    'Flutter flavor + deployment CLI (v$version).',
  );
  runner.argParser.addFlag(
    'version',
    abbr: 'v',
    negatable: false,
    help: 'Print the current flow version and exit.',
  );
  runner
    ..addCommand(FlavorGroupCommand())
    ..addCommand(DeployGroupCommand())
    ..addCommand(CreateCommand());
  return runner;
}

/// The set of top-level command names recognised by [buildFlowRunner].
///
/// Used by `bin/flow.dart` to detect profile shortcuts like `flow dev`, which
/// are forwarded to `flow deploy run dev`. `create` MUST stay in this set —
/// otherwise `flow create my_app` is silently rewritten into
/// `flow deploy run create my_app` instead of scaffolding a project.
const Set<String> kTopLevelCommands = {'flavor', 'deploy', 'create', 'help'};
