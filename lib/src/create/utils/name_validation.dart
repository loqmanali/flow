import '../../flavor/utils/validation.dart';

/// Project names that would collide with core Flutter tooling if used as a
/// package name, even though they're otherwise valid Dart identifiers.
const _reservedProjectNames = {'flutter', 'test'};

/// Validates a prospective Flutter project name (`flow create <name>`).
///
/// Returns `null` when [name] is valid, or a human-readable reason
/// otherwise. Every check here must run before any file or process touches
/// the filesystem, so a bad name fails fast instead of leaving a
/// half-created project behind.
String? validateProjectName(String name) {
  if (name.isEmpty) {
    return 'Project name must not be empty.';
  }
  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
    return 'Project name "$name" must be lower_snake_case: start with a '
        'lowercase letter, then only lowercase letters, digits, or '
        'underscores.';
  }
  if (!ValidationUtils.isValidIdentifier(name)) {
    return 'Project name "$name" is a Dart reserved word and cannot be used '
        'as a package name.';
  }
  if (_reservedProjectNames.contains(name)) {
    return 'Project name "$name" is reserved and cannot be used as a '
        'package name.';
  }
  return null;
}
