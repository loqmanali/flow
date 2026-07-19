import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:io/io.dart' show ExitCode;
import 'package:path/path.dart' as p;

import '../../flavor/utils/logger.dart';
import '../constants.dart';
import '../services/flavor_service.dart';
import '../services/process_service.dart';
import '../services/rename_service.dart';
import '../utils/bundle_id.dart';
import '../utils/display_name.dart';
import '../utils/name_validation.dart';

/// `flow create <name>` — scaffolds a new Flutter project from a template.
///
/// Registered directly on the top-level [CommandRunner] in
/// `lib/src/runner.dart`. Unlike `flavor`/`deploy` this command has no
/// subcommands of its own, so there is no separate group wrapper — it lives
/// under `lib/src/create/` the same way flavor/deploy logic lives under
/// their own directories, just without the extra group indirection.
class CreateCommand extends Command<int> {
  CreateCommand({AppLogger? logger}) : _log = logger ?? AppLogger() {
    argParser
      ..addOption(
        'org',
        help: 'Reverse-domain org, e.g. com.acme. Default bundle id is <org>.<name>.',
        defaultsTo: 'com.example',
      )
      ..addOption('bundle-id', help: 'Explicit bundle id, overriding <org>.<name>.')
      ..addOption(
        'display',
        help: 'Human-readable app name for the launcher. Defaults to a title-cased <name>.',
      )
      ..addOption('template', help: 'Git URL of the template.', defaultsTo: kDefaultTemplateUrl)
      ..addOption(
        'ref',
        help: 'Git ref/tag/branch of the template.',
        defaultsTo: kDefaultTemplateRef,
      )
      ..addOption('flavors', help: 'Comma-separated native flavors, e.g. dev,production.')
      ..addOption('output', help: 'Parent directory to create the project in. Default: cwd.')
      ..addFlag('pub-get', help: 'Run `flutter pub get` after scaffolding.', defaultsTo: true);
  }

  final AppLogger _log;

  @override
  String get name => 'create';

  @override
  String get description => 'Scaffold a new Flutter project from a template.';

  @override
  String get invocation => 'flow create <name> [options]';

  @override
  Future<int> run() async {
    try {
      return await _run();
    } on UsageException {
      // Let bin/flow.dart's dedicated UsageException handler print the
      // message + usage and exit with ExitCode.usage.code — don't downgrade
      // it to a generic "Unexpected error" below.
      rethrow;
    } catch (e) {
      _log.error('Unexpected error: $e');
      return ExitCode.software.code;
    }
  }

  Future<int> _run() async {
    final results = argResults!;
    final rest = results.rest;
    if (rest.isEmpty) {
      usageException('Missing project name. Usage: $invocation');
    }
    if (rest.length > 1) {
      usageException('Unexpected extra arguments: ${rest.skip(1).join(' ')}. Usage: $invocation');
    }
    final name = rest.first;

    // 1. Validate everything up front — no filesystem or network access
    // happens until every check below has passed.
    final nameError = validateProjectName(name);
    if (nameError != null) {
      _log.error(nameError);
      return ExitCode.usage.code;
    }

    final org = results['org'] as String;
    final bundleId = (results['bundle-id'] as String?) ?? deriveBundleId(org: org, name: name);
    final bundleIdError = validateBundleId(bundleId);
    if (bundleIdError != null) {
      _log.error(bundleIdError);
      return ExitCode.usage.code;
    }

    final display = (results['display'] as String?) ?? defaultDisplayName(name);
    final template = results['template'] as String;
    final ref = results['ref'] as String;
    final flavorsRaw = results['flavors'] as String?;
    final flavors =
        (flavorsRaw == null || flavorsRaw.trim().isEmpty)
            ? const <String>[]
            : flavorsRaw.split(',').map((f) => f.trim()).where((f) => f.isNotEmpty).toList();
    final outputDir = (results['output'] as String?) ?? Directory.current.path;
    final pubGet = results['pub-get'] as bool;

    final target = p.join(outputDir, name);
    if (Directory(target).existsSync() || File(target).existsSync()) {
      _log.error('Target directory already exists: $target');
      return ExitCode.usage.code;
    }

    // 2. Fetch the template.
    _log.info('Cloning $template ($ref) into $target...');
    final cloneCode = await runStreamed('git', [
      'clone',
      '--depth',
      '1',
      '--branch',
      ref,
      template,
      target,
    ]);
    if (cloneCode != 0) {
      _log.error('git clone failed (exit $cloneCode). See the error above.');
      return cloneCode;
    }

    // 3. Detach history.
    _detachHistory(target);

    // 4. Rewrite identity.
    _rewriteIdentity(target: target, name: name, display: display, bundleId: bundleId);

    // 5. flutter pub get + dart fix.
    if (pubGet) {
      await _runPubGetAndFix(target);
    } else {
      _log.warn('Skipped `flutter pub get` (--no-pub-get). Run it yourself before building.');
    }

    // 6. --flavors: Android only.
    if (flavors.isNotEmpty) {
      _applyFlavors(target: target, flavors: flavors);
    }

    // 7. Final output.
    _printNextSteps(target: target, name: name, pubGetRan: pubGet);
    _log.success('Created $name at $target.');
    return ExitCode.success.code;
  }

  void _detachHistory(String target) {
    final gitDir = Directory(p.join(target, '.git'));
    if (gitDir.existsSync()) {
      gitDir.deleteSync(recursive: true);
    }
    final initResult = Process.runSync('git', ['init', '--quiet'], workingDirectory: target);
    if (initResult.exitCode != 0) {
      _log.warn('git init failed in $target: ${initResult.stderr}. Run `git init` yourself.');
    }
  }

  void _rewriteIdentity({
    required String target,
    required String name,
    required String display,
    required String bundleId,
  }) {
    final pubspecFile = File(p.join(target, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      _log.warn('pubspec.yaml not found at $target. Rename the package by hand.');
    } else {
      final oldName = readPubspecName(pubspecFile.readAsStringSync());
      if (oldName == null) {
        _log.warn('Could not read "name:" from pubspec.yaml. Rename package: imports by hand.');
      } else {
        final touched = _sweepPackageReferences(target: target, from: oldName, to: name);
        _log.info('Rewrote package references ($oldName -> $name) in $touched file(s).');
      }
    }

    _rewriteFile(
      file: File(p.join(target, 'android/app/src/main/AndroidManifest.xml')),
      rewrite: (content) => rewriteAndroidLabel(content, display),
      manualFixKey: 'android:label',
      manualFixValue: display,
    );

    _rewriteFile(
      file: File(p.join(target, 'ios/Runner/Info.plist')),
      rewrite: (content) => rewriteIosDisplayName(content, display),
      manualFixKey: 'CFBundleDisplayName/CFBundleName',
      manualFixValue: display,
    );

    _rewriteFile(
      file: File(p.join(target, 'android/app/build.gradle.kts')),
      rewrite: (content) => rewriteAndroidApplicationId(content, bundleId),
      manualFixKey: 'applicationId',
      manualFixValue: bundleId,
    );

    _rewriteFile(
      file: File(p.join(target, 'ios/Runner.xcodeproj/project.pbxproj')),
      rewrite: (content) => rewriteIosBundleId(content, bundleId),
      manualFixKey: 'PRODUCT_BUNDLE_IDENTIFIER',
      manualFixValue: bundleId,
    );
  }

  /// Applies [rewrite] to [file] if it exists, warning with the manual fix
  /// ([manualFixKey] -> [manualFixValue]) whenever the file is missing or
  /// the expected key inside it isn't found.
  void _rewriteFile({
    required File file,
    required String? Function(String content) rewrite,
    required String manualFixKey,
    required String manualFixValue,
  }) {
    if (!file.existsSync()) {
      _log.warn('${file.path} not found. Set $manualFixKey to "$manualFixValue" by hand.');
      return;
    }
    final updated = rewrite(file.readAsStringSync());
    if (updated == null) {
      _log.warn(
        'Could not find $manualFixKey in ${file.path}. Set it to "$manualFixValue" by hand.',
      );
      return;
    }
    file.writeAsStringSync(updated);
  }

  int _sweepPackageReferences({required String target, required String from, required String to}) {
    var touched = 0;
    for (final entity in Directory(target).listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!isRewritableFile(entity.path)) continue;
      final original = entity.readAsStringSync();
      final updated = rewritePackageReferences(original, from: from, to: to);
      if (updated != original) {
        entity.writeAsStringSync(updated);
        touched++;
      }
    }
    return touched;
  }

  Future<void> _runPubGetAndFix(String target) async {
    _log.info('Running flutter pub get...');
    final pubGetCode = await runStreamed('flutter', ['pub', 'get'], workingDirectory: target);
    if (pubGetCode != 0) {
      _log.error(
        'flutter pub get failed (exit $pubGetCode). Run it yourself: cd $target && flutter pub get',
      );
      return;
    }
    final fixCode = await runStreamed('dart', [
      'fix',
      '--apply',
      '--code=directives_ordering',
    ], workingDirectory: target);
    if (fixCode != 0) {
      _log.error(
        'dart fix --apply --code=directives_ordering failed (exit $fixCode). '
        'Run it yourself once pub get succeeds.',
      );
    }
  }

  void _applyFlavors({required String target, required List<String> flavors}) {
    final gradleFile = File(p.join(target, 'android/app/build.gradle.kts'));
    if (!gradleFile.existsSync()) {
      _log.warn(
        '${gradleFile.path} not found. Add productFlavors for ${flavors.join(', ')} by hand.',
      );
      return;
    }
    final updated = applyProductFlavors(gradleFile.readAsStringSync(), flavors);
    gradleFile.writeAsStringSync(updated);
    _log.success(
      'Added Android productFlavors for: ${flavors.join(', ')} '
      '(applicationIdSuffix on every flavor except "production").',
    );
    _log.warn(
      'iOS schemes were NOT generated for these flavors — run `flow flavor init` '
      'or configure Xcode schemes/xcconfigs by hand.',
    );
  }

  void _printNextSteps({required String target, required String name, required bool pubGetRan}) {
    final libDir = Directory(p.join(target, 'lib'));
    final flavorEntrypoints = <String>[];
    if (libDir.existsSync()) {
      for (final entity in libDir.listSync()) {
        if (entity is! File) continue;
        final match = RegExp(r'^main_(\w+)\.dart$').firstMatch(p.basename(entity.path));
        if (match != null) flavorEntrypoints.add(match.group(1)!);
      }
      flavorEntrypoints.sort();
    }

    _log.info('');
    _log.info('Created at: $target');
    _log.info('Next:');
    _log.info('  cd $name');
    if (!pubGetRan) {
      _log.info('  flutter pub get');
    }
    if (flavorEntrypoints.isEmpty) {
      _log.info('  flutter run');
    } else {
      for (final flavor in flavorEntrypoints) {
        _log.info('  flutter run -t lib/main_$flavor.dart --dart-define-from-file=.env.$flavor');
      }
    }
  }
}
