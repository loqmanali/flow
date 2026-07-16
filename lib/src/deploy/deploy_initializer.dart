import 'dart:io';

import 'constants.dart';
import 'templates.dart';

/// Non-interactive core of `flow deploy init`.
///
/// The CLI's InitCommand collects the answers with terminal prompts and
/// delegates here; GUI embedders (flow_studio) pass the answers from a form.
/// Template composition and file handling live in exactly one place.
class DeployConfigInitializer {
  DeployConfigInitializer._();

  static const List<String> templateKinds = ['fastlane', 'firebase', 'both'];

  /// Composes the .flow_deploy.json content for [templateKind]
  /// ('fastlane' | 'firebase' | 'both').
  static String composeTemplate({
    required String templateKind,
    required bool includeFlavorConfig,
    required bool generateProfiles,
  }) {
    var content = switch (templateKind) {
      'fastlane' => Templates.deployConfigFastlaneContent,
      'firebase' => Templates.deployConfigFirebaseContent,
      'both' => Templates.deployConfigContent,
      _ => throw ArgumentError.value(
          templateKind,
          'templateKind',
          'must be one of ${templateKinds.join(', ')}',
        ),
    };

    if (includeFlavorConfig) {
      content = Templates.withFlavorConfig(content);
    }
    if (generateProfiles) {
      content = Templates.withProfilesConfig(
        content,
        templateKind: templateKind,
        includeFlavorConfig: includeFlavorConfig,
      );
    }
    return content;
  }

  /// Makes sure .flow_deploy.json is git-ignored (it can hold credentials).
  /// No-op when the project has no .gitignore.
  static void ensureGitignored() {
    final gitignore = File(Constants.gitignorePath);
    if (!gitignore.existsSync()) return;

    const ignoredPath = '/.flow_deploy.json';
    final content = gitignore.readAsStringSync();
    if (!content.contains(ignoredPath)) {
      gitignore.writeAsStringSync('$content\n$ignoredPath');
    }
  }

  /// Writes the config file. Returns `true` when created; `false` when a
  /// config already exists (never overwrites).
  static bool writeConfig(String content) {
    final file = File(Constants.deployConfigFilePath);
    if (file.existsSync()) return false;
    file
      ..createSync()
      ..writeAsStringSync(content);
    return true;
  }
}
