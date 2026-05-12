import 'package:args/args.dart';
import '../logger.dart';
import '../pubspec_utils.dart';
import 'package:mason_logger/mason_logger.dart' show lightCyan;

class VersionCommand {
  Future<void> execute(List<String> args) async {
    final parser =
        ArgParser()
          ..addOption('set', abbr: 's', help: 'Set version (e.g. 2.1.0+1)')
          ..addFlag('major', abbr: 'M', help: 'Bump major version (x.0.0+build)')
          ..addFlag('minor', abbr: 'm', help: 'Bump minor version (0.x.0+build)')
          ..addFlag('patch', abbr: 'p', help: 'Bump patch version (0.0.x+build)')
          ..addFlag('build', abbr: 'b', help: 'Bump build number only')
          ..addFlag('show', help: 'Show current version');

    final ArgResults parsed;
    try {
      parsed = parser.parse(args);
    } catch (e) {
      logger.err('Error parsing arguments: $e');
      logger.info(parser.usage);
      return;
    }

    final hasSet = parsed['set'] != null;
    final bumpMajor = parsed['major'] as bool;
    final bumpMinor = parsed['minor'] as bool;
    final bumpPatch = parsed['patch'] as bool;
    final bumpBuild = parsed['build'] as bool;
    final show = parsed['show'] as bool;

    final actionCount = [hasSet, bumpMajor, bumpMinor, bumpPatch, bumpBuild].where((v) => v).length;

    if (show || actionCount == 0) {
      final version = await PubspecUtils.appVersion;
      logger.info('Current version: ${lightCyan.wrap(version)}');
      if (actionCount == 0 && !show) {
        logger.info('');
        logger.detail('Usage: deploy version [options]');
        logger.detail('  -s, --set <version>   Set version (e.g. 2.1.0+1)');
        logger.detail('  -M, --major           Bump major (x.0.0)');
        logger.detail('  -m, --minor           Bump minor (0.x.0)');
        logger.detail('  -p, --patch           Bump patch (0.0.x)');
        logger.detail('  -b, --build           Bump build number only');
        logger.detail('      --show            Show current version');
      }
      return;
    }

    if (actionCount > 1) {
      logger.err('Specify only one version action at a time.');
      return;
    }

    if (hasSet) {
      final version = parsed['set'] as String;
      await PubspecUtils.setVersion(version);
      return;
    }

    if (bumpMajor) {
      await PubspecUtils.incrementMajor();
      return;
    }

    if (bumpMinor) {
      await PubspecUtils.incrementMinor();
      return;
    }

    if (bumpPatch) {
      await PubspecUtils.incrementPatch();
      return;
    }

    if (bumpBuild) {
      await PubspecUtils.incrementBuildNumber();
      return;
    }
  }
}
