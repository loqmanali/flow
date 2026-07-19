import 'package:flow/src/create/utils/bundle_id.dart';
import 'package:test/test.dart';

void main() {
  group('validateBundleId', () {
    test('accepts a plain reverse-domain id', () {
      expect(validateBundleId('com.acme.myapp'), isNull);
    });

    test('accepts underscores (the default <org>.<name> shape)', () {
      expect(validateBundleId('com.acme.my_app'), isNull);
    });

    test('rejects an empty id', () {
      expect(validateBundleId(''), isNotNull);
    });

    test('rejects a single segment', () {
      expect(validateBundleId('com'), isNotNull);
    });

    test('rejects a segment starting with a digit', () {
      expect(validateBundleId('com.acme.9app'), isNotNull);
    });

    test('rejects a segment with a hyphen', () {
      expect(validateBundleId('com.ac-me.app'), isNotNull);
    });

    test('rejects an empty segment (double dot)', () {
      expect(validateBundleId('com..app'), isNotNull);
    });
  });

  group('deriveBundleId', () {
    test('joins org and name with a dot', () {
      expect(deriveBundleId(org: 'com.acme', name: 'my_app'), 'com.acme.my_app');
    });
  });
}
