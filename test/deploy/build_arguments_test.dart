import 'dart:io';

import 'package:flow/src/deploy/services/build_service.dart';
import 'package:test/test.dart';

/// Guards the build arguments a deploy passes to `flutter build`.
///
/// These are worth pinning because getting them wrong fails silently: the
/// artifact builds and uploads fine, then is dead on launch because its
/// compile-time config never made it in.
void main() {
  late Directory projectDir;
  late Directory previousCwd;

  setUp(() {
    previousCwd = Directory.current;
    projectDir = Directory.systemTemp.createTempSync('flow_build_args_');
    Directory.current = projectDir;
  });

  tearDown(() {
    Directory.current = previousCwd;
    projectDir.deleteSync(recursive: true);
  });

  void writeEnv(String name) => File('${projectDir.path}/$name').writeAsStringSync('API=x');

  group('dartDefineArguments', () {
    test('uses an explicitly configured env file whose name is not .env.<flavor>', () {
      writeEnv('.env');

      expect(
        BuildService.dartDefineArguments('dev', '.env'),
        ['--dart-define-from-file=.env'],
      );
    });

    test('throws when the configured env file is missing instead of building without it', () {
      expect(
        () => BuildService.dartDefineArguments('dev', '.env.missing'),
        throwsA(
          isA<Exception>().having((e) => e.toString(), 'message', contains('.env.missing')),
        ),
      );
    });

    test('an explicit file wins over a present .env.<flavor>', () {
      writeEnv('.env');
      writeEnv('.env.dev');

      expect(
        BuildService.dartDefineArguments('dev', '.env'),
        ['--dart-define-from-file=.env'],
      );
    });

    test('falls back to the .env.<flavor> convention when no file is configured', () {
      writeEnv('.env.dev');

      expect(
        BuildService.dartDefineArguments('dev', ''),
        ['--dart-define-from-file=.env.dev'],
      );
    });

    test('returns no args when the flavor has no env file at all', () {
      expect(BuildService.dartDefineArguments('dev', ''), isEmpty);
    });

    test('returns no args for an unflavored build', () {
      expect(BuildService.dartDefineArguments('', ''), isEmpty);
    });
  });

  group('flavorBuildArguments', () {
    test('honors an explicit target rather than the main_<flavor>.dart convention', () {
      writeEnv('.env');

      expect(
        BuildService.flavorBuildArguments('dev', 'lib/entry/dev_main.dart', '.env'),
        [
          '--flavor',
          'dev',
          '--target',
          'lib/entry/dev_main.dart',
          '--dart-define-from-file=.env',
        ],
      );
    });

    test('falls back to the main_<flavor>.dart convention when no target is set', () {
      expect(
        BuildService.flavorBuildArguments('production', '', ''),
        ['--flavor', 'production', '--target', 'lib/main_production.dart'],
      );
    });

    test('passes a target with no flavor', () {
      expect(
        BuildService.flavorBuildArguments('', 'lib/main.dart', ''),
        ['--target', 'lib/main.dart'],
      );
    });
  });
}
