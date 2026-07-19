/// Parses a comma-separated flavors string — from `--flavors` or the
/// wizard's prompt — into a trimmed, non-empty list. Returns an empty list
/// for `null` or blank input.
List<String> parseFlavors(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  return raw.split(',').map((f) => f.trim()).where((f) => f.isNotEmpty).toList();
}
