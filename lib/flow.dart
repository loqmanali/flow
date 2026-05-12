/// Public entry point for the `flow` CLI.
///
/// Most callers only need `bin/flow.dart`. Tests and embedders can call
/// [buildFlowRunner] to obtain a configured `CommandRunner<int>`.
library;

export 'src/runner.dart' show buildFlowRunner, kTopLevelCommands;
