import 'package:flow/src/create/services/flavor_service.dart';
import 'package:test/test.dart';

void main() {
  group('buildProductFlavorsBlock', () {
    test('adds applicationIdSuffix to every non-production flavor', () {
      final block = buildProductFlavorsBlock(['dev', 'production']);

      expect(block, contains('create("dev")'));
      expect(block, contains('applicationIdSuffix = ".dev"'));
      expect(block, contains('create("production")'));
      expect(block, isNot(contains('applicationIdSuffix = ".production"')));
    });

    test('suffixes every flavor when none is named production', () {
      final block = buildProductFlavorsBlock(['staging', 'demo']);

      expect(block, contains('applicationIdSuffix = ".staging"'));
      expect(block, contains('applicationIdSuffix = ".demo"'));
    });
  });

  group('applyProductFlavors', () {
    test('inserts flavorDimensions and productFlavors right after android {', () {
      const gradle =
          'plugins {\n    id("com.android.application")\n}\n\nandroid {\n    namespace = "x"\n}\n';

      final updated = applyProductFlavors(gradle, ['dev', 'production']);

      expect(updated, contains('flavorDimensions += "flavor"'));
      expect(updated, contains('productFlavors {'));
      expect(updated, contains('create("dev")'));
      expect(updated, contains('create("production")'));
      // The rest of the original file is preserved.
      expect(updated, contains('namespace = "x"'));
    });
  });
}
