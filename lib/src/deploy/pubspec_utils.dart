import 'dart:io';
import 'logger.dart';

class PubspecUtils {
  static String get _projectDir => Directory.current.path;

  static Future<String> get appVersion async {
    final file = File('$_projectDir/pubspec.yaml');
    if (!file.existsSync()) {
      throw Exception('pubspec.yaml not found');
    }
    final content = await file.readAsString();
    final versionMatch = RegExp(r'version:\s*(.+)').firstMatch(content);
    if (versionMatch == null) {
      throw Exception('version not found in pubspec.yaml');
    }
    return versionMatch.group(1)!.trim();
  }

  static Future<AppVersion> get currentVersion async {
    final version = await appVersion;
    return AppVersion.parse(version);
  }

  static Future<void> setVersion(String version) async {
    final parsed = AppVersion.parse(version);
    await _writePubspec('$parsed');
    logger.success('Version set to $parsed');
  }

  static Future<void> incrementMajor() async {
    final current = await currentVersion;
    final next = current.copyWith(
      major: current.major + 1,
      minor: 0,
      patch: 0,
      buildNumber: current.buildNumber + 1,
    );
    await _writePubspec('$next');
    logger.success('Version bumped to $next');
  }

  static Future<void> incrementMinor() async {
    final current = await currentVersion;
    final next = current.copyWith(
      minor: current.minor + 1,
      patch: 0,
      buildNumber: current.buildNumber + 1,
    );
    await _writePubspec('$next');
    logger.success('Version bumped to $next');
  }

  static Future<void> incrementPatch() async {
    final current = await currentVersion;
    final next = current.copyWith(
      patch: current.patch + 1,
      buildNumber: current.buildNumber + 1,
    );
    await _writePubspec('$next');
    logger.success('Version bumped to $next');
  }

  static Future<void> incrementBuildNumber() async {
    final current = await currentVersion;
    final next = current.copyWith(
      buildNumber: current.buildNumber + 1,
    );
    await _writePubspec('$next');
    logger.success('Build number bumped to $next');
  }

  static Future<void> _writePubspec(String newVersion) async {
    final file = File('$_projectDir/pubspec.yaml');
    final content = await file.readAsString();
    final updatedContent = content.replaceFirst(
      RegExp(r'version: .+'),
      'version: $newVersion',
    );
    await file.writeAsString(updatedContent);
  }
}

class AppVersion {
  final int major;
  final int minor;
  final int patch;
  final int buildNumber;

  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.buildNumber,
  });

  factory AppVersion.parse(String version) {
    final parts = version.split('+');
    final semver = parts[0].split('.');
    if (semver.length != 3) {
      throw Exception(
        'Invalid version format "$version". Expected: major.minor.patch+buildNumber',
      );
    }
    return AppVersion(
      major: int.parse(semver[0]),
      minor: int.parse(semver[1]),
      patch: int.parse(semver[2]),
      buildNumber: parts.length > 1 ? int.parse(parts[1]) : 0,
    );
  }

  AppVersion copyWith({
    int? major,
    int? minor,
    int? patch,
    int? buildNumber,
  }) {
    return AppVersion(
      major: major ?? this.major,
      minor: minor ?? this.minor,
      patch: patch ?? this.patch,
      buildNumber: buildNumber ?? this.buildNumber,
    );
  }

  String get semver => '$major.$minor.$patch';

  @override
  String toString() => '$semver+$buildNumber';
}
