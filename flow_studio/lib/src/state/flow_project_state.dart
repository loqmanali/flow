import 'dart:io';

import 'package:flow/engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaml/yaml.dart';

import 'recent_projects.dart';

/// One inspection finding about the selected project.
class ProjectIssue {
  const ProjectIssue({required this.message, required this.isError});

  final String message;
  final bool isError;
}

/// Everything flow_studio knows about the currently selected project.
///
/// Immutable snapshot — produced by [FlowProjectNotifier.selectProject] and
/// re-produced on refresh. Screens only read; all mutation goes through the
/// flow engine and ends in a fresh snapshot.
class FlowProjectState {
  const FlowProjectState({
    required this.projectPath,
    required this.projectName,
    required this.pubspecVersion,
    required this.detectedPlatforms,
    required this.hasFlavorConfig,
    required this.hasDeployConfig,
    required this.flavorConfig,
    required this.flavorNames,
    required this.deployProfileNames,
    required this.deployProfiles,
    required this.issues,
  });

  final String projectPath;
  final String projectName;
  final String? pubspecVersion;
  final List<String> detectedPlatforms;
  final bool hasFlavorConfig;
  final bool hasDeployConfig;

  /// Parsed + validated flavor config, null when absent or invalid.
  final FlavorConfig? flavorConfig;
  final List<String> flavorNames;
  final List<String> deployProfileNames;

  /// Raw profile maps from .flow_deploy.json, keyed by profile name —
  /// used by the Deploy screen cards (platform/provider/flavor chips).
  final Map<String, Map<String, dynamic>> deployProfiles;
  final List<ProjectIssue> issues;

  bool get hasErrors => issues.any((issue) => issue.isError);
}

/// Loads and holds the selected project. `null` means nothing selected yet.
class FlowProjectNotifier extends Notifier<FlowProjectState?> {
  @override
  FlowProjectState? build() => null;

  /// Points the flow engine at [projectPath] and reads everything the UI
  /// shows: pubspec, flavor config, deploy config, validation findings.
  Future<void> selectProject(String projectPath) async {
    // The flow engine resolves every path from the process working directory
    // (and ConfigService.root). One project at a time, same as the CLI.
    Directory.current = projectPath;
    ConfigService.root = projectPath;

    final issues = <ProjectIssue>[];

    // --- pubspec ---
    String projectName = 'unknown';
    String? pubspecVersion;
    final pubspecFile = File('$projectPath/pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      issues.add(
        const ProjectIssue(
          message: 'No pubspec.yaml found — not a Flutter/Dart project root.',
          isError: true,
        ),
      );
    } else {
      try {
        final pubspec = loadYaml(pubspecFile.readAsStringSync()) as YamlMap;
        projectName = pubspec['name']?.toString() ?? 'unknown';
        pubspecVersion = pubspec['version']?.toString();
      } catch (e) {
        issues.add(
          ProjectIssue(
            message: 'pubspec.yaml could not be parsed: $e',
            isError: true,
          ),
        );
      }
    }

    // --- platforms ---
    final detectedPlatforms = <String>[
      for (final platform in const [
        'android',
        'ios',
        'macos',
        'web',
        'windows',
        'linux',
      ])
        if (Directory('$projectPath/$platform').existsSync()) platform,
    ];

    // --- flavor config (validated by the same code the CLI uses) ---
    var hasFlavorConfig = false;
    FlavorConfig? flavorConfig;
    var flavorNames = const <String>[];
    if (ConfigService.isInitialized()) {
      hasFlavorConfig = true;
      try {
        flavorConfig = ConfigService.load();
        flavorNames = List<String>.from(flavorConfig.flavors);
      } catch (e) {
        issues.add(
          ProjectIssue(
            message: 'Flavor config invalid: ${_cleanEngineMessage(e)}',
            isError: true,
          ),
        );
      }
    }

    // --- deploy config ---
    var hasDeployConfig = false;
    var deployProfileNames = const <String>[];
    var deployProfiles = <String, Map<String, dynamic>>{};
    if (File(Constants.deployConfigFilePath).existsSync()) {
      hasDeployConfig = true;
      try {
        await DeployConfig.instance.load();
        deployProfileNames = DeployConfig.instance.profileNames;
        deployProfiles = {
          for (final name in deployProfileNames)
            name: Map<String, dynamic>.from(
              DeployConfig.instance.profile(name) ?? const {},
            ),
        };
        if (deployProfileNames.isEmpty) {
          issues.add(
            const ProjectIssue(
              message:
                  '.flow_deploy.json has no profiles — '
                  'the Deploy screen will be empty until one is added.',
              isError: false,
            ),
          );
        }
      } catch (e) {
        issues.add(
          ProjectIssue(
            message: 'Deploy config invalid: ${_cleanEngineMessage(e)}',
            isError: true,
          ),
        );
      }
    }

    if (!hasFlavorConfig) {
      issues.add(
        const ProjectIssue(
          message:
              'No .flow_flavor.json — flavors are not set up '
              '(run "flow flavor init" or use the Flavors screen later).',
          isError: false,
        ),
      );
    }
    if (!hasDeployConfig) {
      issues.add(
        const ProjectIssue(
          message:
              'No .flow_deploy.json — deployment is not set up '
              '(run "flow deploy init").',
          isError: false,
        ),
      );
    }

    state = FlowProjectState(
      projectPath: projectPath,
      projectName: projectName,
      pubspecVersion: pubspecVersion,
      detectedPlatforms: detectedPlatforms,
      hasFlavorConfig: hasFlavorConfig,
      hasDeployConfig: hasDeployConfig,
      flavorConfig: flavorConfig,
      flavorNames: flavorNames,
      deployProfileNames: deployProfileNames,
      deployProfiles: deployProfiles,
      issues: issues,
    );

    await ref
        .read(recentProjectsProvider.notifier)
        .record(
          RecentProjectEntry(
            name: projectName,
            path: projectPath,
            lastOpenedAt: DateTime.now(),
            detectedPlatforms: detectedPlatforms,
            hasFlavorConfig: hasFlavorConfig,
            hasDeployConfig: hasDeployConfig,
          ),
        );
  }

  Future<void> refresh() async {
    final current = state;
    if (current != null) {
      await selectProject(current.projectPath);
    }
  }

  static String _cleanEngineMessage(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
}

final flowProjectProvider =
    NotifierProvider<FlowProjectNotifier, FlowProjectState?>(
      FlowProjectNotifier.new,
    );
