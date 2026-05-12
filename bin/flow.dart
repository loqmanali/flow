import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:io/io.dart' show ExitCode;
import 'package:stack_trace/stack_trace.dart';

import 'package:flow/flow.dart';
import 'package:flow/src/shared/version_reader.dart';

Future<void> main(List<String> rawArgs) async {
  await Chain.capture<Future<void>>(
    () async {
      // Handle --version / -v before running the CommandRunner so the
      // top-level flag is honoured even when no subcommand is supplied.
      if (rawArgs.length == 1 && (rawArgs.first == '--version' || rawArgs.first == '-v')) {
        final version = await readFlowVersion();
        stdout.writeln('flow v$version');
        exit(ExitCode.success.code);
      }

      // Map profile shortcuts: `flow dev` -> `flow deploy run dev`.
      var args = rawArgs;
      if (args.isNotEmpty &&
          !args.first.startsWith('-') &&
          !kTopLevelCommands.contains(args.first)) {
        args = ['deploy', 'run', ...args];
      }

      final runner = await buildFlowRunner();
      try {
        final code = await runner.run(args) ?? ExitCode.success.code;
        exit(code);
      } on UsageException catch (e) {
        stderr.writeln(e.message);
        stderr.writeln(e.usage);
        exit(ExitCode.usage.code);
      }
    },
    onError: (Object error, Chain chain) {
      stderr.writeln('Fatal: $error');
      stderr.writeln(chain.terse);
      exit(ExitCode.software.code);
    },
  );
}
