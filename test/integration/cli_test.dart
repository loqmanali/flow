@Tags(['integration'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

/// Absolute path to `bin/flow.dart` so subprocesses can find it regardless of
/// the working directory used during a test.
final String _binFlow = File('bin/flow.dart').absolute.path;

Future<TestProcess> runFlow(List<String> args, {String? workingDirectory}) {
  return TestProcess.start(
    'dart',
    ['run', _binFlow, ...args],
    workingDirectory: workingDirectory ?? d.sandbox,
  );
}

void main() {
  group('flow CLI surface', () {
    test('--version prints the package version', () async {
      final p = await runFlow(['--version']);
      await expectLater(
        p.stdout,
        emitsThrough(matches(RegExp(r'^flow v\d+\.\d+\.\d+$'))),
      );
      await p.shouldExit(0);
    });

    test('--help lists the top-level command groups', () async {
      final p = await runFlow(['--help']);
      final output = await p.stdout.rest.join('\n');
      expect(output, contains('flavor'));
      expect(output, contains('deploy'));
      await p.shouldExit(0);
    });

    test('flow flavor --help lists every flavor subcommand', () async {
      final p = await runFlow(['flavor', '--help']);
      final output = await p.stdout.rest.join('\n');
      for (final sub in const [
        'init',
        'add',
        'delete',
        'replace',
        'reset',
        'run',
        'build',
        'firebase',
        'migrate',
      ]) {
        expect(output, contains(sub), reason: 'flavor help should mention $sub');
      }
      await p.shouldExit(0);
    });

    test('flow deploy --help lists every deploy subcommand', () async {
      final p = await runFlow(['deploy', '--help']);
      final output = await p.stdout.rest.join('\n');
      for (final sub in const ['init', 'beta', 'update', 'version', 'run']) {
        expect(output, contains(sub), reason: 'deploy help should mention $sub');
      }
      await p.shouldExit(0);
    });

    test('unknown subcommand returns exit 64 (UsageException)', () async {
      final p = await runFlow(['flavor', 'definitely-not-a-real-command']);
      await p.shouldExit(64);
    });
  });
}
