/// Title-cases a lower_snake_case project name into a display name, e.g.
/// `my_app` -> `My App`. Used as the default `--display` value.
String defaultDisplayName(String name) {
  return name
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}
