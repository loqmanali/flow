import 'dart:io';
import 'logger.dart';

class ProcessRunner {
  static final String _projectDir = Directory.current.path;

  static Future<void> runCommand(
    String executable, {
    List<String> arguments = const [],
    String? description,
    String? workingDir,
  }) async {
    final progress = logger.progress(description ?? 'Running $executable');
    try {
      final process = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDir != null ? '$_projectDir/$workingDir' : _projectDir,
        runInShell: true,
      );
      process.stdout.transform(const SystemEncoding().decoder).listen((data) {
        stdout.write(data);
      });
      process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        stderr.write(data);
      });
      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        progress.fail();
        throw Exception('Command failed with exit code $exitCode');
      }
      progress.complete();
    } catch (e) {
      progress.fail();
      throw Exception('Error running command: $e');
    }
  }
}
