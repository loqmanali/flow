/// Rewrites [from] to [to] wherever it appears as a whole identifier —
/// bounded by a non-word character (or the string's edges) on both sides.
///
/// Mirrors the word-boundary approach in flutter_starter's own
/// `tool/rename.dart`: without it, renaming `flutter_starter` to `my_app`
/// would also corrupt an unrelated identifier like `flutter_starter_legacy`.
String rewritePackageReferences(String source, {required String from, required String to}) {
  final pattern = RegExp('(?<!\\w)${RegExp.escape(from)}(?!\\w)');
  return source.replaceAll(pattern, to);
}

/// Reads the package name from a `pubspec.yaml`'s `name:` field.
String? readPubspecName(String pubspecContent) {
  final match = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(pubspecContent);
  return match?.group(1);
}

/// Whether [path] should be scanned by [rewritePackageReferences] when
/// sweeping a freshly cloned template.
bool isRewritableFile(String path) {
  if (path.contains('/.git/') || path.contains('/build/')) return false;
  if (path.contains('/.dart_tool/')) return false;
  // The default template (flutter_starter) ships its own rename tool plus a
  // test fixture that intentionally hardcodes "flutter_starter" as a fixed,
  // generic old name to rewrite from — not a reference to the current
  // project. Rewriting it here would silently break that test the first
  // time the new project's owner runs `dart test`.
  if (path.endsWith('/test/tool/rename_test.dart')) return false;
  return path.endsWith('.dart') || path.endsWith('.yaml') || path.endsWith('.md');
}

/// Rewrites `android:label="..."` in an Android manifest to [display].
/// Returns `null` (instead of the rewritten content) when the attribute
/// isn't found, so the caller can report a manual fix.
String? rewriteAndroidLabel(String manifestContent, String display) {
  final updated = manifestContent.replaceFirst(
    RegExp('android:label="[^"]*"'),
    'android:label="${_escapeXml(display)}"',
  );
  return updated == manifestContent ? null : updated;
}

/// Rewrites `CFBundleDisplayName` and `CFBundleName` in an iOS `Info.plist`
/// to [display]. Returns `null` when neither key is found.
String? rewriteIosDisplayName(String plistContent, String display) {
  var updated = plistContent;
  var touched = 0;
  for (final key in ['CFBundleDisplayName', 'CFBundleName']) {
    final pattern = RegExp('(<key>$key</key>\\s*<string>)[^<]*(</string>)');
    final next = updated.replaceFirstMapped(
      pattern,
      (match) => '${match.group(1)}${_escapeXml(display)}${match.group(2)}',
    );
    if (next != updated) touched++;
    updated = next;
  }
  return touched == 0 ? null : updated;
}

/// Rewrites `applicationId = "..."` in an Android `build.gradle.kts` to
/// [bundleId]. Returns `null` when the key isn't found.
String? rewriteAndroidApplicationId(String gradleContent, String bundleId) {
  final pattern = RegExp('applicationId\\s*=\\s*"[^"]*"');
  final updated = gradleContent.replaceFirst(pattern, 'applicationId = "$bundleId"');
  return updated == gradleContent ? null : updated;
}

/// Rewrites every `PRODUCT_BUNDLE_IDENTIFIER` in an iOS `project.pbxproj` to
/// [bundleId] — including the `.RunnerTests` variant used by the test
/// target, which conventionally suffixes the app's own bundle id. Returns
/// `null` when no concrete (non-`$(...)`-macro) value is found.
String? rewriteIosBundleId(String pbxprojContent, String bundleId) {
  final pattern = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);');
  final values =
      pattern
          .allMatches(pbxprojContent)
          .map((m) => m.group(1)!.trim())
          .where((v) => !v.contains(r'$'))
          .toSet();
  if (values.isEmpty) return null;

  // RunnerTests configs suffix the app's own id with ".RunnerTests", so the
  // shortest concrete value found is the app's own bundle id.
  final oldBase = values.reduce((a, b) => a.length <= b.length ? a : b);

  final updated = pbxprojContent.replaceAllMapped(pattern, (match) {
    final value = match.group(1)!.trim();
    if (value == oldBase) return 'PRODUCT_BUNDLE_IDENTIFIER = $bundleId;';
    if (value == '$oldBase.RunnerTests') {
      return 'PRODUCT_BUNDLE_IDENTIFIER = $bundleId.RunnerTests;';
    }
    return match.group(0)!;
  });
  return updated == pbxprojContent ? null : updated;
}

String _escapeXml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
