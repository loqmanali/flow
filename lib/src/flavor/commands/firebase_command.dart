import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../services/config_service.dart';
import '../services/file_service.dart';
import '../models/flavor_config.dart';
import '../utils/logger.dart';

class FirebaseCommand {
  final AppLogger _log;
  final bool fromHook;

  FirebaseCommand({AppLogger? logger, this.fromHook = false}) : _log = logger ?? AppLogger();

  Future<void> execute({String? targetFlavor}) async {
    if (!ConfigService.isValidProject(_log)) return;

    if (!ConfigService.isInitialized()) {
      _log.error('❌ flow: project not initialized');
      return;
    }

    var config = ConfigService.load();
    if (config.firebase == null) {
      final confirmed = _log.confirm(
        '🔥 No Firebase configuration found in .flow_flavor.json. Would you like to set it up now?',
        defaultValue: true,
      );

      if (!confirmed) {
        _log.error('❌ Firebase setup cancelled.');
        return;
      }

      final firebaseConfig = _promptForFirebaseConfig(config);
      config = config.copyWith(firebase: firebaseConfig);
      ConfigService.save(config);
      _log.success('📝 Firebase configuration saved to .flow_flavor.json');
    }

    // 1. Check firebase CLI (needed for project creation)
    final hasFirebaseCli = await _checkCommand('firebase');

    // 2. Check flutterfire CLI
    final hasFlutterFire = await _checkCommand('flutterfire');
    if (!hasFlutterFire) {
      _log.error('❌ flow: flutterfire CLI not found');
      _log.info('   → install it with: dart pub global activate flutterfire_cli');
      return;
    }

    final flavors = targetFlavor != null ? [targetFlavor] : config.flavors;
    final strategy = config.firebase!.strategy;
    final projects = config.firebase!.projects;
    final useSuffix = config.useSuffix;
    final prodFlavor = config.productionFlavor;
    final baseId = config.android.applicationId;
    final useSeparate = config.useSeparateMains;

    // 3. Verify all Firebase projects exist, offer to fix missing ones
    Map<String, String> resolvedProjects = Map.from(projects);
    if (hasFirebaseCli) {
      final projectIds = _collectProjectIds(strategy, resolvedProjects, flavors);
      final result = await _ensureProjectsExist(projectIds);
      if (!result.success) return;

      if (result.replacements.isNotEmpty) {
        resolvedProjects = _applyProjectReplacements(
          resolvedProjects,
          result.replacements,
          strategy,
        );
        config = config.copyWith(
          firebase: FirebaseConfig(strategy: strategy, projects: resolvedProjects),
        );
        ConfigService.save(config);
        _log.success('📝 Firebase project IDs updated in .flow_flavor.json');
      }
    } else {
      _log.warn('⚠️ Firebase CLI not found. Skipping project existence check.');
      _log.info('   → install it with: npm install -g firebase-tools');
      _log.info('   → if a project does not exist, flutterfire configure will fail.');
    }

    _log.info('🔥 Initializing Firebase (Strategy: $strategy)...');

    if (strategy == 'shared_id_single_project') {
      final projectId = resolvedProjects['all'] ?? resolvedProjects.values.first;
      await _runConfigure(
        projectId: projectId,
        packageId: baseId,
        out: 'lib/firebase_options.dart',
      );
      FileService.injectFirebase(separate: useSeparate);
    } else {
      for (final flavor in flavors) {
        final projectId =
            strategy == 'unique_id_multi_project'
                ? (resolvedProjects[flavor] ?? resolvedProjects.values.first)
                : (resolvedProjects['all'] ?? resolvedProjects.values.first);

        String packageId = baseId;
        if (useSuffix && flavor != prodFlavor) {
          packageId = '$baseId.$flavor';
        }

        await _runConfigure(
          projectId: projectId,
          packageId: packageId,
          out: 'lib/firebase_options_$flavor.dart',
          flavor: flavor,
        );

        if (useSeparate) {
          FileService.injectFirebase(separate: true, flavor: flavor);
        }
      }

      if (!useSeparate) {
        FileService.injectFirebase(separate: false);
      }
    }

    _log.info('📦 Adding firebase_core dependency...');
    final pubAddResult = await Process.run('flutter', ['pub', 'add', 'firebase_core']);
    if (pubAddResult.exitCode != 0) {
      _log.warn(
        '⚠️ Could not automatically add firebase_core to pubspec.yaml. Please add it manually.',
      );
    }

    _log.success('✅ Firebase setup completed for all targets.');
  }

  List<String> _collectProjectIds(
    String strategy,
    Map<String, String> projects,
    List<String> flavors,
  ) {
    if (strategy == 'unique_id_multi_project') {
      return flavors.map((f) => projects[f] ?? '').where((id) => id.isNotEmpty).toSet().toList();
    }
    final id = projects['all'] ?? projects.values.firstOrNull ?? '';
    return id.isNotEmpty ? [id] : [];
  }

  Future<_ProjectVerifyResult> _ensureProjectsExist(List<String> projectIds) async {
    final existingProjects = await _listFirebaseProjects();
    if (existingProjects == null) {
      _log.warn('⚠️ Could not verify Firebase projects (not logged in or firebase CLI issue).');
      _log.info('   → Run: firebase login');
      return _ProjectVerifyResult(success: true);
    }

    final existingIds = existingProjects.map((p) => p.projectId).toSet();
    final replacements = <String, String>{};

    for (final projectId in projectIds) {
      if (existingIds.contains(projectId)) {
        _log.info('✔ Firebase project "$projectId" found.');
        continue;
      }

      _log.warn('⚠️ Firebase project "$projectId" not found on this account.');

      final options = ['Pick from existing projects', 'Create new project', 'Enter different ID'];
      final choice = _log.chooseOne(
        '👉 What would you like to do?',
        choices: options,
      );

      if (choice == options[0]) {
        if (existingProjects.isEmpty) {
          _log.error('❌ No Firebase projects found on this account.');
          return _ProjectVerifyResult(success: false);
        }

        final displayNames =
            existingProjects.map((p) => '${p.projectId} (${p.displayName})').toList();
        final selected = _log.chooseOne(
          '👉 Select a Firebase project:',
          choices: displayNames,
        );
        final selectedId = existingProjects[displayNames.indexOf(selected)].projectId;

        replacements[projectId] = selectedId;
        _log.info('✔ Using project "$selectedId" instead.');
      } else if (choice == options[1]) {
        final created = await _createFirebaseProject(projectId);
        if (!created) {
          _log.error('❌ Failed to create Firebase project "$projectId". Aborting.');
          return _ProjectVerifyResult(success: false);
        }
      } else if (choice == options[2]) {
        final newId = _log.prompt('👉 Enter the correct Firebase Project ID:');
        if (newId.trim().isEmpty) {
          _log.error('❌ Aborting.');
          return _ProjectVerifyResult(success: false);
        }
        replacements[projectId] = newId.trim();
      }
    }

    return _ProjectVerifyResult(success: true, replacements: replacements);
  }

  Future<List<_FirebaseProject>?> _listFirebaseProjects() async {
    try {
      final result = await Process.run('firebase', [
        'projects:list',
        '--json',
      ]);
      if (result.exitCode != 0) return null;

      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final status = json['status'] as String?;

      if (status == 'error') return null;

      final results = json['result'] as List<dynamic>? ?? [];
      return results
          .map((p) {
            final map = p as Map<String, dynamic>;
            return _FirebaseProject(
              projectId: map['projectId'] as String? ?? '',
              displayName: map['displayName'] as String? ?? '',
            );
          })
          .where((p) => p.projectId.isNotEmpty)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _applyProjectReplacements(
    Map<String, String> projects,
    Map<String, String> replacements,
    String strategy,
  ) {
    final updated = Map<String, String>.from(projects);
    if (strategy == 'unique_id_multi_project') {
      for (final entry in updated.entries) {
        if (replacements.containsKey(entry.value)) {
          updated[entry.key] = replacements[entry.value]!;
        }
      }
    } else {
      final oldValue = updated['all'] ?? updated.values.firstOrNull ?? '';
      if (replacements.containsKey(oldValue)) {
        if (updated.containsKey('all')) {
          updated['all'] = replacements[oldValue]!;
        } else {
          final firstKey = updated.keys.first;
          updated[firstKey] = replacements[oldValue]!;
        }
      }
    }
    return updated;
  }

  Future<bool> _createFirebaseProject(String projectId) async {
    _log.info('🚀 Creating Firebase project "$projectId"...');
    _log.info('   This may take a minute. You may be prompted to link analytics.');

    final result = await Process.start(
      'firebase',
      ['projects:create', projectId],
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await result.exitCode;
    if (exitCode == 0) {
      _log.success('✔ Firebase project "$projectId" created successfully.');
      return true;
    }

    _log.error('❌ Failed to create project "$projectId".');
    return false;
  }

  Future<void> _runConfigure({
    required String projectId,
    required String packageId,
    required String out,
    String? flavor,
  }) async {
    final label = flavor != null ? 'flavor "$flavor"' : 'project';
    _log.info('🚀 Configuring $label ($packageId) against project $projectId...');

    final args = [
      'configure',
      '--project=$projectId',
      '--out=$out',
      '--ios-bundle-id=$packageId',
      '--android-package-name=$packageId',
      '--platforms=android,ios',
      '--yes',
    ];

    final result = await Process.start('flutterfire', args, mode: ProcessStartMode.inheritStdio);
    final exitCode = await result.exitCode;

    if (exitCode != 0) {
      throw Exception('flutterfire configure failed for $label');
    }
  }

  FirebaseConfig _promptForFirebaseConfig(FlavorConfig config) {
    final useSuffix = config.useSuffix;
    final List<String> strategyChoices;

    if (useSuffix) {
      strategyChoices = [
        'unique_id_multi_project',
        'unique_id_single_project',
      ];
    } else {
      strategyChoices = [
        'shared_id_single_project',
      ];
    }

    final selectedStrategy =
        strategyChoices.length > 1
            ? _log.chooseOne('👉 Which Firebase strategy do you prefer?', choices: strategyChoices)
            : strategyChoices.first;

    if (strategyChoices.length == 1) {
      _log.info(
        'ℹ️ Using Firebase strategy: $selectedStrategy (matches your "Shared ID" strategy)',
      );
    }

    final projects = <String, String>{};
    if (selectedStrategy == 'unique_id_multi_project') {
      for (final flavor in config.flavors) {
        final projectId = _log.prompt('👉 Enter Firebase Project ID for flavor "$flavor":');
        projects[flavor] = projectId;
      }
    } else {
      final projectId = _log.prompt('👉 Enter your Firebase Project ID:');
      projects['all'] = projectId;
    }

    return FirebaseConfig(
      strategy: selectedStrategy,
      projects: projects,
    );
  }

  Future<bool> _checkCommand(String command) async {
    try {
      final checkCmd = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(checkCmd, [command]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<void> checkAndReinit(AppLogger log, {String? targetFlavor}) async {
    if (!ConfigService.isInitialized()) return;
    final config = ConfigService.load();
    if (config.firebase == null) return;

    final hasFiles = ConfigService.hasFirebaseFiles();

    // 1. If configured but NO files exist, this is a fresh setup from init or a reset.
    if (!hasFiles) {
      final prompt =
          targetFlavor != null
              ? '\n🔥 Firebase configured but not integrated. Run Firebase setup for flavor "$targetFlavor" now?'
              : '\n🔥 Firebase configured but not integrated. Run Firebase setup for all flavors now?';

      if (log.confirm(prompt, defaultValue: true)) {
        await FirebaseCommand(logger: log, fromHook: true).execute(targetFlavor: targetFlavor);
      }
      return;
    }

    // 2. If files DO exist, we follow the existing prompt/link logic.
    final strategy = config.firebase!.strategy;
    final isSharedId = strategy.contains('shared_id');

    // OPTIMIZATION: If using Shared ID and config already exists, just link it without prompting.
    if (isSharedId) {
      final optionsFile = File(p.join(ConfigService.root, 'lib/firebase_options.dart'));
      if (optionsFile.existsSync()) {
        log.info('ℹ️ Firebase Shared ID strategy detected. Automatically linking configuration...');
        FileService.injectFirebase(separate: config.useSeparateMains, flavor: targetFlavor);
        return;
      }
    }

    final prompt =
        targetFlavor != null
            ? '\n🔥 Firebase detected. Re-run Firebase setup for flavor "$targetFlavor"?'
            : '\n🔥 Firebase detected. Re-run Firebase setup for all flavors?';

    if (log.confirm(prompt, defaultValue: true)) {
      await FirebaseCommand(logger: log, fromHook: true).execute(targetFlavor: targetFlavor);
    }
  }
}

class _FirebaseProject {
  final String projectId;
  final String displayName;

  const _FirebaseProject({
    required this.projectId,
    required this.displayName,
  });
}

class _ProjectVerifyResult {
  final bool success;
  final Map<String, String> replacements;

  const _ProjectVerifyResult({
    required this.success,
    this.replacements = const {},
  });
}
