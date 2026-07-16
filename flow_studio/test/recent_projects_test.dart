import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flow_studio/src/state/recent_projects.dart';

RecentProjectEntry entry(String path, {DateTime? openedAt, String? name}) {
  return RecentProjectEntry(
    name: name ?? path.split('/').last,
    path: path,
    lastOpenedAt: openedAt ?? DateTime(2026, 1, 1),
    detectedPlatforms: const ['ios', 'android'],
    hasFlavorConfig: false,
    hasDeployConfig: false,
  );
}

void main() {
  group('RecentProjectsService.upsert', () {
    test('new entry goes on top', () {
      final result = RecentProjectsService.upsert([
        entry('/projects/a'),
        entry('/projects/b'),
      ], entry('/projects/c'));
      expect(result.map((e) => e.path).toList(), [
        '/projects/c',
        '/projects/a',
        '/projects/b',
      ]);
    });

    test('re-opening an existing path moves it to top without duplicating', () {
      final result = RecentProjectsService.upsert([
        entry('/projects/a'),
        entry('/projects/b'),
        entry('/projects/c'),
      ], entry('/projects/b', openedAt: DateTime(2026, 7, 7)));
      expect(result.map((e) => e.path).toList(), [
        '/projects/b',
        '/projects/a',
        '/projects/c',
      ]);
      expect(result.where((e) => e.path == '/projects/b'), hasLength(1));
      expect(result.first.lastOpenedAt, DateTime(2026, 7, 7));
    });

    test('history is capped at maxEntries, dropping the oldest', () {
      var history = <RecentProjectEntry>[];
      for (var i = 0; i < RecentProjectsService.maxEntries + 5; i++) {
        history = RecentProjectsService.upsert(history, entry('/projects/$i'));
      }
      expect(history, hasLength(RecentProjectsService.maxEntries));
      expect(
        history.first.path,
        '/projects/${RecentProjectsService.maxEntries + 4}',
      );
      expect(history.any((e) => e.path == '/projects/0'), isFalse);
      expect(history.any((e) => e.path == '/projects/4'), isFalse);
      expect(history.any((e) => e.path == '/projects/5'), isTrue);
    });
  });

  group('RecentProjectsService persistence', () {
    test('save/load round-trips entries in order', () async {
      SharedPreferences.setMockInitialValues({});
      final service = RecentProjectsService(
        await SharedPreferences.getInstance(),
      );

      await service.save([entry('/projects/x'), entry('/projects/y')]);
      final loaded = service.load();

      expect(loaded.map((e) => e.path).toList(), [
        '/projects/x',
        '/projects/y',
      ]);
      expect(loaded.first.detectedPlatforms, ['ios', 'android']);
    });

    test(
      'corrupt storage loads as empty history instead of crashing',
      () async {
        SharedPreferences.setMockInitialValues({
          RecentProjectsService.storageKey: 'not json {',
        });
        final service = RecentProjectsService(
          await SharedPreferences.getInstance(),
        );
        expect(service.load(), isEmpty);
      },
    );
  });

  group('RecentProjectEntry.isAvailable', () {
    test('false for a path that does not exist', () {
      expect(entry('/definitely/not/a/real/path').isAvailable, isFalse);
    });

    test('true for an existing directory', () {
      final tempDir = Directory.systemTemp.createTempSync('flow_studio_test');
      addTearDown(() => tempDir.deleteSync());
      expect(entry(tempDir.path).isAvailable, isTrue);
    });
  });
}
