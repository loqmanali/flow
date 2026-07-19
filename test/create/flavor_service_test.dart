import 'package:flow/src/create/services/flavor_service.dart';
import 'package:test/test.dart';

void main() {
  group('buildNativeFlavorConfig', () {
    test('feeds the same bundle id to both Android and iOS', () {
      final config = buildNativeFlavorConfig(
        flavors: ['dev', 'production'],
        appName: 'My App',
        bundleId: 'com.acme.myapp',
      );

      expect(config.android.applicationId, 'com.acme.myapp');
      expect(config.ios.bundleId, 'com.acme.myapp');
    });

    test('treats the flavor named "production" as the unsuffixed one', () {
      final config = buildNativeFlavorConfig(
        flavors: ['dev', 'production'],
        appName: 'My App',
        bundleId: 'com.acme.myapp',
      );

      expect(config.productionFlavor, 'production');
      expect(config.flavors, ['dev', 'production']);
    });

    test('suffixes every flavor when none is named "production"', () {
      final config = buildNativeFlavorConfig(
        flavors: ['staging', 'demo'],
        appName: 'My App',
        bundleId: 'com.acme.myapp',
      );

      expect(config.productionFlavor, isEmpty);
    });

    test('carries the app name through for iOS scheme/xcconfig branding', () {
      final config = buildNativeFlavorConfig(
        flavors: ['dev'],
        appName: 'My App',
        bundleId: 'com.acme.myapp',
      );

      expect(config.appName, 'My App');
      expect(config.useSeparateMains, isTrue);
    });
  });
}
