import 'dart:io';

import 'package:args/args.dart';
import 'package:mason_logger/mason_logger.dart' show lightCyan, styleBold;
import 'package:path/path.dart' as p;

import '../../flavor/utils/logger.dart';
import '../constants.dart';
import '../utils/bundle_id.dart';
import '../utils/display_name.dart';
import '../utils/flavors.dart';
import '../utils/name_validation.dart';
import '../utils/wizard_plan.dart';

/// Everything the wizard collected, already validated and ready to
/// scaffold.
class CreateWizardAnswers {
  const CreateWizardAnswers({
    required this.name,
    required this.org,
    required this.bundleId,
    required this.display,
    required this.flavors,
    required this.template,
    required this.ref,
  });

  final String name;
  final String org;
  final String bundleId;
  final String display;
  final List<String> flavors;
  final String template;
  final String ref;
}

/// Interactive `flow create` — walks the user through project name, org,
/// bundle id, display name, native flavors, and template selection when the
/// positional `<name>` is missing.
///
/// A thin shell: every default/validation rule it calls into
/// (`resolveCreateWizardPlan`, `deriveBundleId`, `defaultDisplayName`,
/// `validateProjectName`, `validateBundleId`, `parseFlavors`) is a pure,
/// independently tested function. This class only owns the prompt sequence
/// and the final summary.
class CreateWizard {
  CreateWizard({required AppLogger logger}) : _log = logger;

  final AppLogger _log;

  /// Returns the collected answers, or `null` if the user declined the
  /// final confirmation — the caller should exit cleanly (code 0) without
  /// touching the filesystem.
  CreateWizardAnswers? run(ArgResults results) {
    final plan = resolveCreateWizardPlan(results);

    _log.info('');
    _log.info('🚀 ${styleBold.wrap("Let's scaffold a new Flutter project.")}');
    _log.info('');

    final name = _promptName();

    final org =
        plan.needsOrg
            ? _log.prompt('👉 Org (reverse-domain)', defaultValue: 'com.example')
            : results['org'] as String;

    final bundleId =
        plan.needsBundleId
            ? _promptBundleId(org: org, name: name)
            : ((results['bundle-id'] as String?) ?? deriveBundleId(org: org, name: name));

    final display =
        plan.needsDisplay
            ? _log.prompt(
              '👉 Display name (shown under the launcher icon)',
              defaultValue: defaultDisplayName(name),
            )
            : ((results['display'] as String?) ?? defaultDisplayName(name));

    final flavors =
        plan.needsFlavors ? _promptFlavors() : parseFlavors(results['flavors'] as String?);

    final (template, ref) =
        plan.needsTemplate
            ? _promptTemplate()
            : (results['template'] as String, results['ref'] as String);

    final outputDir = (results['output'] as String?) ?? Directory.current.path;
    final target = p.join(outputDir, name);

    _printSummary(
      name: name,
      org: org,
      bundleId: bundleId,
      display: display,
      flavors: flavors,
      template: template,
      ref: ref,
      target: target,
    );

    final confirmed = _log.confirm('👉 Create this project?', defaultValue: true);
    if (!confirmed) {
      _log.info('Cancelled — no files were touched.');
      return null;
    }

    return CreateWizardAnswers(
      name: name,
      org: org,
      bundleId: bundleId,
      display: display,
      flavors: flavors,
      template: template,
      ref: ref,
    );
  }

  String _promptName() {
    while (true) {
      final name = _log.prompt('👉 Project name (lower_snake_case)').trim();
      final error = validateProjectName(name);
      if (error == null) return name;
      _log.error(error);
    }
  }

  String _promptBundleId({required String org, required String name}) {
    _log.info(
      'ℹ️  Bundle ids conventionally avoid underscores, while Dart package names '
      'require them — so "$name" under "$org" may read better as '
      '${deriveBundleId(org: org, name: name.replaceAll('_', ''))}.',
    );
    while (true) {
      final bundleId =
          _log.prompt('👉 Bundle id', defaultValue: deriveBundleId(org: org, name: name)).trim();
      final error = validateBundleId(bundleId);
      if (error == null) return bundleId;
      _log.error(error);
    }
  }

  List<String> _promptFlavors() {
    final wantsFlavors = _log.confirm(
      "👉 Set up native Android flavors? (Android-only — iOS schemes aren't generated)",
      defaultValue: false,
    );
    if (!wantsFlavors) return const [];
    final raw = _log.prompt('👉 Flavors (comma separated)', defaultValue: 'dev,production');
    return parseFlavors(raw);
  }

  (String, String) _promptTemplate() {
    final useDefault = _log.confirm('👉 Use the default template?', defaultValue: true);
    if (useDefault) return (kDefaultTemplateUrl, kDefaultTemplateRef);
    final template = _log.prompt('👉 Template git URL', defaultValue: kDefaultTemplateUrl);
    final ref = _log.prompt('👉 Template ref (branch/tag)', defaultValue: kDefaultTemplateRef);
    return (template, ref);
  }

  void _printSummary({
    required String name,
    required String org,
    required String bundleId,
    required String display,
    required List<String> flavors,
    required String template,
    required String ref,
    required String target,
  }) {
    _log.info('');
    _log.info('${styleBold.wrap('Summary')}');
    _log.info('  Name          ${lightCyan.wrap(name)}');
    _log.info('  Org           ${lightCyan.wrap(org)}');
    _log.info('  Bundle id     ${lightCyan.wrap(bundleId)}');
    _log.info('  Display name  ${lightCyan.wrap(display)}');
    _log.info('  Flavors       ${lightCyan.wrap(flavors.isEmpty ? 'none' : flavors.join(', '))}');
    _log.info('  Template      ${lightCyan.wrap('$template@$ref')}');
    _log.info('  Location      ${lightCyan.wrap(target)}');
    _log.info('');
  }
}
