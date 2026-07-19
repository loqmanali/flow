import 'dart:io';

/// Runs [executable] with [arguments], streaming stdout/stderr live to the
/// terminal, and returns the exit code once the process finishes.
///
/// Used for `git clone`, `flutter pub get`, and `dart fix` — all long-running
/// enough that buffering their full output until completion would leave the
/// user staring at a blank terminal.
Future<int> runStreamed(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: true,
  );
  process.stdout.listen(stdout.add);
  process.stderr.listen(stderr.add);
  return process.exitCode;
}
