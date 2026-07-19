import 'dart:io';

/// The exit code and combined stdout+stderr of a subprocess run via
/// [runCaptured].
class CapturedProcess {
  const CapturedProcess(this.exitCode, this.output);

  final int exitCode;
  final String output;
}

/// Runs [executable] with [arguments] to completion, capturing its combined
/// stdout/stderr instead of streaming it live.
///
/// Used for `git clone`, `flutter pub get`, and `dart fix` — all long-running
/// enough to hide behind a spinner (see `AppLogger.progress`). The caller
/// only needs [CapturedProcess.output] to report the real error when
/// [CapturedProcess.exitCode] is non-zero; on success the captured output is
/// simply discarded in favor of a short spinner completion line.
Future<CapturedProcess> runCaptured(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: true,
  );
  return CapturedProcess(result.exitCode, '${result.stdout}${result.stderr}'.trim());
}
