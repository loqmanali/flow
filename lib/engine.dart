/// Embedding surface for GUI frontends (e.g. flow_studio).
///
/// Exposes the deploy/flavor engine directly so embedders reuse the same
/// business logic as the CLI instead of spawning `flow` as a subprocess.
///
/// Contract for embedders:
/// - Point the engine at a project by setting `Directory.current` to the
///   project root AND `ConfigService.root` to the same path.
/// - Redirect subprocess output by setting [ProcessRunner.outputSink].
/// - Terminal prompts live only in the CLI command layer, never here.
library;

export 'src/deploy/commands/deploy_command.dart' show DeployCommand;
export 'src/deploy/constants.dart' show Constants;
export 'src/deploy/deploy_initializer.dart' show DeployConfigInitializer;
export 'src/deploy/flow_config.dart' show DeployConfig;
export 'src/deploy/flow_enums.dart';
export 'src/deploy/process_runner.dart' show ProcessRunner;
export 'src/deploy/pubspec_utils.dart' show PubspecUtils;
export 'src/flavor/models/config_validator.dart' show ConfigValidator;
export 'src/flavor/models/flavor_config.dart';
export 'src/flavor/runner/setup_runner.dart' show SetupRunner;
export 'src/flavor/services/config_service.dart' show ConfigService;
export 'src/flavor/utils/logger.dart' show AppLogger, AppLoggerInteraction;
