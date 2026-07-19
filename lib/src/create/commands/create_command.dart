import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:io/io.dart' show ExitCode;
import 'package:mason_logger/mason_logger.dart' show lightCyan, styleBold;
import 'package:path/path.dart' as p;

import '../../flavor/utils/logger.dart';
import '../constants.dart';
import '../services/flavor_service.dart';
import '../services/process_service.dart';
import '../services/rename_service.dart';
import '../utils/bundle_id.dart';
import '../utils/display_name.dart';
import '../utils/flavors.dart';
import '../utils/name_validation.dart';
import '../utils/wizard_plan.dart';
import 'create_wizard.dart';

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
      ..addFlag('pub-get', help: 'Run `flutter pub get` after scaffolding.', defaultsTo: true)
      ..addFlag(
        'no-input',
        help:
            'Never prompt interactively, even on a terminal; fail fast if the '
            'project name is missing. Always on for scripts/CI.',
        negatable: false,
      );
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
    if (rest.length > 1) {
      usageException('Unexpected extra arguments: ${rest.skip(1).join(' ')}. Usage: $invocation');
    }

    final String name;
    final String org;
    final String bundleId;
    final String display;
    final String template;
    final String ref;
    final List<String> flavors;

    if (rest.isEmpty) {
      // No positional name: either walk the interactive wizard, or fail
      // fast. `--no-input`, and any non-tty stdin (CI, a pipe), must never
      // block on a prompt that can never be answered.
      final noInput = results['no-input'] as bool;
      if (!shouldRunCreateWizard(noInput: noInput, hasTerminal: stdin.hasTerminal)) {
        usageException('Missing project name. Usage: $invocation');
      }

      final answers = CreateWizard(logger: _log).run(results);
      if (answers == null) {
        return ExitCode.success.code;
      }
      name = answers.name;
      org = answers.org;
      bundleId = answers.bundleId;
      display = answers.display;
      template = answers.template;
      ref = answers.ref;
      flavors = answers.flavors;
    } else {
      name = rest.first;

      // Validate everything up front — no filesystem or network access
      // happens until every check below has passed.
      final nameError = validateProjectName(name);
      if (nameError != null) {
        _log.error(nameError);
        return ExitCode.usage.code;
      }

      org = results['org'] as String;
      bundleId = (results['bundle-id'] as String?) ?? deriveBundleId(org: org, name: name);
      final bundleIdError = validateBundleId(bundleId);
      if (bundleIdError != null) {
        _log.error(bundleIdError);
        return ExitCode.usage.code;
      }

      display = (results['display'] as String?) ?? defaultDisplayName(name);
      template = results['template'] as String;
      ref = results['ref'] as String;
      flavors = parseFlavors(results['flavors'] as String?);
    }

    final outputDir = (results['output'] as String?) ?? Directory.current.path;
    final pubGet = results['pub-get'] as bool;

    final target = p.join(outputDir, name);
    if (Directory(target).existsSync() || File(target).existsSync()) {
      _log.error('Target directory already exists: $target');
      return ExitCode.usage.code;
    }

    // 2. Fetch the template.
    final cloneProgress = _log.progress('Cloning $template ($ref)');
    final cloneResult = await runCaptured('git', [
      'clone',
      '--depth',
      '1',
      '--branch',
      ref,
      template,
      target,
    ]);
    if (cloneResult.exitCode != 0) {
      cloneProgress.fail('git clone failed (exit ${cloneResult.exitCode})');
      _log.error(cloneResult.output.isEmpty ? 'No output captured.' : cloneResult.output);
      return cloneResult.exitCode;
    }
    cloneProgress.complete('Cloned $template ($ref)');

    // 3. Detach history.
    _detachHistory(target);

    // 4. Rewrite identity.
    final rewriteProgress = _log.progress('Rewriting project identity');
    final rewriteReport = _rewriteIdentity(
      target: target,
      name: name,
      display: display,
      bundleId: bundleId,
    );
    rewriteProgress.complete(
      'Rewrote project identity (${rewriteReport.filesTouched} file(s) touched)',
    );
    for (final warning in rewriteReport.warnings) {
      _log.warn(warning);
    }

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
    _log.success('Created ${styleBold.wrap(name)} at $target.');
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

  /// What [_rewriteIdentity] did, so the caller can log one summary line
  /// after the progress spinner completes instead of interleaving log
  /// lines mid-spinner.
  _RewriteReport _rewriteIdentity({
    required String target,
    required String name,
    required String display,
    required String bundleId,
  }) {
    final warnings = <String>[];
    var filesTouched = 0;

    final pubspecFile = File(p.join(target, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      warnings.add('pubspec.yaml not found at $target. Rename the package by hand.');
    } else {
      final oldName = readPubspecName(pubspecFile.readAsStringSync());
      if (oldName == null) {
        warnings.add('Could not read "name:" from pubspec.yaml. Rename package: imports by hand.');
      } else {
        filesTouched += _sweepPackageReferences(target: target, from: oldName, to: name);
      }
    }

    if (_rewriteFile(
      file: File(p.join(target, 'android/app/src/main/AndroidManifest.xml')),
      rewrite: (content) => rewriteAndroidLabel(content, display),
      manualFixKey: 'android:label',
      manualFixValue: display,
      warnings: warnings,
    )) {
      filesTouched++;
    }

    if (_rewriteFile(
      file: File(p.join(target, 'ios/Runner/Info.plist')),
      rewrite: (content) => rewriteIosDisplayName(content, display),
      manualFixKey: 'CFBundleDisplayName/CFBundleName',
      manualFixValue: display,
      warnings: warnings,
    )) {
      filesTouched++;
    }

    if (_rewriteFile(
      file: File(p.join(target, 'android/app/build.gradle.kts')),
      rewrite: (content) => rewriteAndroidApplicationId(content, bundleId),
      manualFixKey: 'applicationId',
      manualFixValue: bundleId,
      warnings: warnings,
    )) {
      filesTouched++;
    }

    if (_rewriteFile(
      file: File(p.join(target, 'ios/Runner.xcodeproj/project.pbxproj')),
      rewrite: (content) => rewriteIosBundleId(content, bundleId),
      manualFixKey: 'PRODUCT_BUNDLE_IDENTIFIER',
      manualFixValue: bundleId,
      warnings: warnings,
    )) {
      filesTouched++;
    }

    return _RewriteReport(filesTouched: filesTouched, warnings: warnings);
  }

  /// Applies [rewrite] to [file] if it exists, appending a manual-fix
  /// warning ([manualFixKey] -> [manualFixValue]) to [warnings] whenever the
  /// file is missing or the expected key inside it isn't found. Returns
  /// whether the file was actually rewritten, so the caller can report an
  /// accurate touched-file count.
  bool _rewriteFile({
    required File file,
    required String? Function(String content) rewrite,
    required String manualFixKey,
    required String manualFixValue,
    required List<String> warnings,
  }) {
    if (!file.existsSync()) {
      warnings.add('${file.path} not found. Set $manualFixKey to "$manualFixValue" by hand.');
      return false;
    }
    final updated = rewrite(file.readAsStringSync());
    if (updated == null) {
      warnings.add(
        'Could not find $manualFixKey in ${file.path}. Set it to "$manualFixValue" by hand.',
      );
      return false;
    }
    file.writeAsStringSync(updated);
    return true;
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
    final pubGetProgress = _log.progress('Running flutter pub get');
    final pubGetResult = await runCaptured('flutter', ['pub', 'get'], workingDirectory: target);
    if (pubGetResult.exitCode != 0) {
      pubGetProgress.fail('flutter pub get failed (exit ${pubGetResult.exitCode})');
      _log.error(pubGetResult.output.isEmpty ? 'No output captured.' : pubGetResult.output);
      _log.error('Run it yourself: cd $target && flutter pub get');
      return;
    }
    pubGetProgress.complete('flutter pub get done');

    final fixProgress = _log.progress('Running dart fix --apply');
    final fixResult = await runCaptured('dart', [
      'fix',
      '--apply',
      '--code=directives_ordering',
    ], workingDirectory: target);
    if (fixResult.exitCode != 0) {
      fixProgress.fail('dart fix failed (exit ${fixResult.exitCode})');
      _log.error(fixResult.output.isEmpty ? 'No output captured.' : fixResult.output);
      _log.error(
        'Run it yourself once pub get succeeds: dart fix --apply --code=directives_ordering',
      );
      return;
    }
    fixProgress.complete('dart fix applied');
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
    _log.info('${styleBold.wrap('Next steps')}');
    _log.info('  ${lightCyan.wrap('cd $name')}');
    if (!pubGetRan) {
      _log.info('  ${lightCyan.wrap('flutter pub get')}');
    }
    if (flavorEntrypoints.isEmpty) {
      _log.info('  ${lightCyan.wrap('flutter run')}');
    } else {
      for (final flavor in flavorEntrypoints) {
        final example = File(p.join(target, '.env.$flavor.example'));
        final envFile = File(p.join(target, '.env.$flavor'));
        if (example.existsSync() && !envFile.existsSync()) {
          _log.info('  ${lightCyan.wrap('cp .env.$flavor.example .env.$flavor')}');
        }
        _log.info(
          '  ${lightCyan.wrap('flutter run -t lib/main_$flavor.dart --dart-define-from-file=.env.$flavor')}',
        );
      }
      _log.info('');
      _log.info(
        '💡 Plain `flutter run` exits 64 by design — always pick a flavored entrypoint above.',
      );
    }
  }
}

/// What [CreateCommand._rewriteIdentity] did to the freshly cloned template.
class _RewriteReport {
  const _RewriteReport({required this.filesTouched, required this.warnings});

  final int filesTouched;
  final List<String> warnings;
}
