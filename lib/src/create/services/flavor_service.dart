/// Generates a Kotlin DSL `productFlavors { ... }` block for [flavors].
///
/// Every flavor except one named exactly `production` gets an
/// `applicationIdSuffix`, so a dev build installs side by side with the
/// production build instead of overwriting it.
String buildProductFlavorsBlock(List<String> flavors) {
  final buffer = StringBuffer()..writeln('    productFlavors {');
  for (final flavor in flavors) {
    buffer.writeln('        create("$flavor") {');
    buffer.writeln('            dimension = "flavor"');
    if (flavor != 'production') {
      buffer.writeln('            applicationIdSuffix = ".$flavor"');
    }
    buffer.writeln('        }');
  }
  buffer.writeln('    }');
  return buffer.toString();
}

/// Inserts a `flavorDimensions` declaration and a `productFlavors` block for
/// [flavors] right after the `android { ` opening brace of [gradleContent].
///
/// Only used at project-creation time on a freshly cloned template, so —
/// unlike `flow flavor add` on an existing project — there is never a
/// pre-existing block to detect or replace.
String applyProductFlavors(String gradleContent, List<String> flavors) {
  final block = buildProductFlavorsBlock(flavors);
  return gradleContent.replaceFirst(
    RegExp(r'android\s*\{'),
    'android {\n    flavorDimensions += "flavor"\n$block',
  );
}
