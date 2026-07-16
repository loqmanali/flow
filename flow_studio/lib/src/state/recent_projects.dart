import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One remembered project in the local history.
class RecentProjectEntry {
  const RecentProjectEntry({
    required this.name,
    required this.path,
    required this.lastOpenedAt,
    required this.detectedPlatforms,
    required this.hasFlavorConfig,
    required this.hasDeployConfig,
  });

  final String name;
  final String path;
  final DateTime lastOpenedAt;
  final List<String> detectedPlatforms;
  final bool hasFlavorConfig;
  final bool hasDeployConfig;

  /// Whether the folder still exists on disk (checked at render time).
  bool get isAvailable => Directory(path).existsSync();

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'last_opened_at': lastOpenedAt.toIso8601String(),
    'detected_platforms': detectedPlatforms,
    'has_flavor_config': hasFlavorConfig,
    'has_deploy_config': hasDeployConfig,
  };

  factory RecentProjectEntry.fromJson(Map<String, dynamic> json) {
    return RecentProjectEntry(
      name: json['name'] as String? ?? 'unknown',
      path: json['path'] as String? ?? '',
      lastOpenedAt:
          DateTime.tryParse(json['last_opened_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      detectedPlatforms:
          (json['detected_platforms'] as List?)?.cast<String>() ?? const [],
      hasFlavorConfig: json['has_flavor_config'] as bool? ?? false,
      hasDeployConfig: json['has_deploy_config'] as bool? ?? false,
    );
  }
}

/// Persistence + list rules for the recent-projects history.
///
/// Pure list logic lives in [upsert] so it is unit-testable without storage.
class RecentProjectsService {
  RecentProjectsService(this._preferences);

  static const String storageKey = 'recent_projects';
  static const int maxEntries = 20;

  final SharedPreferences _preferences;

  List<RecentProjectEntry> load() {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List;
      return [
        for (final item in decoded)
          RecentProjectEntry.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } catch (_) {
      // Corrupt history is not worth crashing over — start fresh.
      return const [];
    }
  }

  Future<void> save(List<RecentProjectEntry> entries) async {
    await _preferences.setString(
      storageKey,
      jsonEncode([for (final entry in entries) entry.toJson()]),
    );
  }

  /// Returns [entries] with [entry] on top, its old duplicate (same path)
  /// removed, and the whole list capped at [maxEntries].
  static List<RecentProjectEntry> upsert(
    List<RecentProjectEntry> entries,
    RecentProjectEntry entry,
  ) {
    final withoutDuplicate = [
      for (final existing in entries)
        if (existing.path != entry.path) existing,
    ];
    return [entry, ...withoutDuplicate].take(maxEntries).toList();
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError(
        'Overridden in main() with the real SharedPreferences instance.',
      ),
);

final recentProjectsServiceProvider = Provider<RecentProjectsService>(
  (ref) => RecentProjectsService(ref.watch(sharedPreferencesProvider)),
);

/// The history list shown on the Project screen, newest first.
class RecentProjectsNotifier extends Notifier<List<RecentProjectEntry>> {
  @override
  List<RecentProjectEntry> build() =>
      ref.watch(recentProjectsServiceProvider).load();

  Future<void> record(RecentProjectEntry entry) async {
    state = RecentProjectsService.upsert(state, entry);
    await ref.read(recentProjectsServiceProvider).save(state);
  }

  Future<void> remove(String path) async {
    state = [
      for (final entry in state)
        if (entry.path != path) entry,
    ];
    await ref.read(recentProjectsServiceProvider).save(state);
  }

  Future<void> clear() async {
    state = const [];
    await ref.read(recentProjectsServiceProvider).save(state);
  }
}

final recentProjectsProvider =
    NotifierProvider<RecentProjectsNotifier, List<RecentProjectEntry>>(
      RecentProjectsNotifier.new,
    );
