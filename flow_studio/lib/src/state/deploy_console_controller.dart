import 'package:flow/engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DeployRunStatus { idle, running, succeeded, failed }

/// State of the live log console on the Deploy screen.
class DeployConsoleState {
  const DeployConsoleState({
    required this.status,
    required this.runningProfile,
    required this.lines,
  });

  const DeployConsoleState.idle()
    : status = DeployRunStatus.idle,
      runningProfile = null,
      lines = const [];

  final DeployRunStatus status;
  final String? runningProfile;
  final List<String> lines;

  bool get isRunning => status == DeployRunStatus.running;

  DeployConsoleState copyWith({
    DeployRunStatus? status,
    String? runningProfile,
    List<String>? lines,
  }) {
    return DeployConsoleState(
      status: status ?? this.status,
      runningProfile: runningProfile ?? this.runningProfile,
      lines: lines ?? this.lines,
    );
  }
}

/// Runs a deploy profile through the flow engine — the exact same
/// `DeployCommand` the CLI's `flow deploy run <profile>` uses — and streams
/// subprocess output into [DeployConsoleState.lines].
///
/// Nothing here blocks the UI: the heavy work happens in the subprocesses
/// the engine spawns (flutter, fastlane, firebase), and their output arrives
/// through the injected [ProcessRunner.outputSink].
class DeployConsoleController extends Notifier<DeployConsoleState> {
  @override
  DeployConsoleState build() => const DeployConsoleState.idle();

  /// Runs [profileName], optionally overriding its configured platform with
  /// [platformOverride] ('ios' | 'android') — same as passing `--platform`
  /// to `flow deploy run`.
  Future<void> runProfile(
    String profileName, {
    String? platformOverride,
  }) async {
    if (state.isRunning) return;

    final arguments =
        platformOverride == null
            ? const <String>[]
            : ['--platform', platformOverride];

    state = DeployConsoleState(
      status: DeployRunStatus.running,
      runningProfile: profileName,
      lines: [
        '▶ flow deploy run $profileName ${arguments.join(' ')}'.trim(),
        '',
      ],
    );

    ProcessRunner.outputSink = _appendOutput;
    try {
      await DeployCommand().execute(profileName, arguments);
      _appendOutput('\n✓ Profile "$profileName" finished successfully.\n');
      state = state.copyWith(status: DeployRunStatus.succeeded);
    } catch (e) {
      _appendOutput('\n✗ ${e.toString().replaceFirst('Exception: ', '')}\n');
      state = state.copyWith(status: DeployRunStatus.failed);
    } finally {
      ProcessRunner.outputSink = null;
    }
  }

  void clear() {
    if (state.isRunning) return;
    state = const DeployConsoleState.idle();
  }

  void _appendOutput(String text) {
    state = state.copyWith(lines: [...state.lines, ...text.split('\n')]);
  }
}

final deployConsoleProvider =
    NotifierProvider<DeployConsoleController, DeployConsoleState>(
      DeployConsoleController.new,
    );
