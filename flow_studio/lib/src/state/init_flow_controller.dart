import 'package:flow/engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'flow_project_state.dart';

/// Everything the Init Flow wizard collects before touching any file.
class InitFlowPlan {
  const InitFlowPlan({
    required this.appDisplayName,
    required this.packageIdBase,
    required this.flavors,
    required this.productionFlavor,
    required this.useSuffix,
    required this.createFlavorConfig,
    required this.createDeployConfig,
    required this.deployTemplateKind,
  });

  final String appDisplayName;

  /// Base application id / bundle id, e.g. `com.company.app`.
  final String packageIdBase;
  final List<String> flavors;
  final String productionFlavor;
  final bool useSuffix;
  final bool createFlavorConfig;
  final bool createDeployConfig;

  /// 'fastlane' | 'firebase' | 'both'
  final String deployTemplateKind;

  /// The exact JSON the flow engine validates and runs — same schema as a
  /// hand-written `.flow_flavor.json` passed to `flow flavor init --from`.
  Map<String, dynamic> toFlavorConfigJson() => {
    'flavors': flavors,
    'app_name': appDisplayName,
    'production_flavor': productionFlavor,
    'app_config_path': 'lib/core/config/app_config.dart',
    'use_separate_mains': true,
    'use_suffix': useSuffix,
    'fields': const <String, String>{},
    'values': {for (final flavor in flavors) flavor: <String, dynamic>{}},
    'android': {'application_id': packageIdBase},
    'ios': {'bundle_id': packageIdBase},
  };
}

enum InitFlowStatus { idle, running, succeeded, failed }

class InitFlowState {
  const InitFlowState({required this.status, required this.logLines});

  const InitFlowState.idle()
    : status = InitFlowStatus.idle,
      logLines = const [];

  final InitFlowStatus status;
  final List<String> logLines;

  bool get isRunning => status == InitFlowStatus.running;
}

/// Answers engine questions during a GUI-run init without a terminal:
/// every confirm/choice takes its default, so nothing ever blocks on stdin.
class _DefaultAnswersInteraction implements AppLoggerInteraction {
  const _DefaultAnswersInteraction();

  @override
  String prompt(String message, {String? defaultValue}) => defaultValue ?? '';

  @override
  bool confirm(String message, {bool defaultValue = false}) => defaultValue;

  @override
  String chooseOne(
    String message, {
    required List<String> choices,
    String? defaultValue,
  }) => defaultValue ?? choices.first;

  @override
  List<String> chooseAny(
    String message, {
    required List<String> choices,
    List<String>? defaultValues,
  }) => defaultValues ?? const [];
}

/// Runs the confirmed [InitFlowPlan] through the flow engine:
/// - flavor setup via ConfigValidator + SetupRunner (the CLI's non-interactive
///   `init --from` path, minus the file indirection),
/// - deploy config via DeployConfigInitializer (never overwrites).
class InitFlowController extends Notifier<InitFlowState> {
  @override
  InitFlowState build() => const InitFlowState.idle();

  Future<void> run(InitFlowPlan plan) async {
    if (state.isRunning) return;
    state = const InitFlowState(
      status: InitFlowStatus.running,
      logLines: ['▶ Initializing flow…', ''],
    );

    ProcessRunner.outputSink = _appendLog;
    try {
      if (plan.createFlavorConfig) {
        final config = ConfigValidator.validate(plan.toFlavorConfigJson());
        final logger = AppLogger(
          interaction: const _DefaultAnswersInteraction(),
          messageSink: _appendLog,
        );
        // Firebase wiring needs flutterfire prompts — explicitly out of the
        // MVP wizard; run it later from the CLI (`flow flavor firebase`).
        await SetupRunner(logger: logger).run(config, skipFirebase: true);
      }

      if (plan.createDeployConfig) {
        final content = DeployConfigInitializer.composeTemplate(
          templateKind: plan.deployTemplateKind,
          includeFlavorConfig: plan.createFlavorConfig,
          generateProfiles: true,
        );
        DeployConfigInitializer.ensureGitignored();
        final created = DeployConfigInitializer.writeConfig(content);
        _appendLog(
          created
              ? '✓ Created .flow_deploy.json\n'
              : '⚠ .flow_deploy.json already exists — left untouched.\n',
        );
      }

      _appendLog('\n✓ Initialization finished.\n');
      state = InitFlowState(
        status: InitFlowStatus.succeeded,
        logLines: state.logLines,
      );
    } on FormatException catch (e) {
      // ConfigValidator reports every invalid/missing field in one message.
      _appendLog('\n${e.message}\n');
      state = InitFlowState(
        status: InitFlowStatus.failed,
        logLines: state.logLines,
      );
    } catch (e) {
      _appendLog('\n✗ ${e.toString().replaceFirst('Exception: ', '')}\n');
      state = InitFlowState(
        status: InitFlowStatus.failed,
        logLines: state.logLines,
      );
    } finally {
      ProcessRunner.outputSink = null;
      // Whatever happened, re-read the project so the status panel is honest.
      await ref.read(flowProjectProvider.notifier).refresh();
    }
  }

  void reset() {
    if (!state.isRunning) state = const InitFlowState.idle();
  }

  void _appendLog(String text) {
    state = InitFlowState(
      status: state.status,
      logLines: [...state.logLines, ...text.split('\n')],
    );
  }
}

final initFlowProvider = NotifierProvider<InitFlowController, InitFlowState>(
  InitFlowController.new,
);
