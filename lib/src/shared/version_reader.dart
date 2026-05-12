import 'dart:io';
import 'dart:isolate';

const String _fallbackVersion = '0.1.0';

/// Resolves the running package's version from its `pubspec.yaml`.
///
/// Falls back to a baked-in constant when reading is not possible (e.g. when
/// the executable has been compiled with `dart compile exe` and the pubspec
/// is no longer reachable).
Future<String> readFlowVersion() async {
  try {
    final uri = await Isolate.resolvePackageUri(
      Uri.parse('package:flow/flow.dart'),
    );
    if (uri != null) {
      final pubspec = File.fromUri(uri.resolve('../pubspec.yaml'));
      if (pubspec.existsSync()) {
        final match = RegExp(
          r'^version:\s*(.*)$',
          multiLine: true,
        ).firstMatch(pubspec.readAsStringSync());
        final value = match?.group(1)?.trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
  } catch (_) {
    // Fall through to fallback below.
  }
  return _fallbackVersion;
}
