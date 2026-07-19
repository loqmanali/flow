/// Matches a single reverse-domain segment: starts with a letter, then
/// letters/digits/underscores. Underscores are allowed because the default
/// bundle id is `<org>.<name>` and Dart package names require them; pass an
/// explicit `--bundle-id` to drop them for a more conventional identifier.
final _bundleIdSegment = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$');

/// Validates a bundle id (Android `applicationId` / iOS
/// `PRODUCT_BUNDLE_IDENTIFIER`). Returns `null` when valid, or a
/// human-readable reason otherwise.
String? validateBundleId(String bundleId) {
  if (bundleId.isEmpty) {
    return 'Bundle id must not be empty.';
  }
  final segments = bundleId.split('.');
  if (segments.length < 2) {
    return 'Bundle id "$bundleId" must be a reverse-domain identifier with '
        'at least two segments, e.g. com.acme.myapp.';
  }
  for (final segment in segments) {
    if (!_bundleIdSegment.hasMatch(segment)) {
      return 'Bundle id "$bundleId" has an invalid segment "$segment": each '
          'segment must start with a letter and contain only letters, '
          'digits, or underscores.';
    }
  }
  return null;
}

/// Derives the default bundle id from `--org` and the project name, used
/// when `--bundle-id` is not given explicitly.
String deriveBundleId({required String org, required String name}) => '$org.$name';
