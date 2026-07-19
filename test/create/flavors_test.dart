import 'package:flow/src/create/utils/flavors.dart';
import 'package:test/test.dart';

void main() {
  group('parseFlavors', () {
    test('returns an empty list for null', () {
      expect(parseFlavors(null), isEmpty);
    });

    test('returns an empty list for a blank string', () {
      expect(parseFlavors('   '), isEmpty);
    });

    test('splits, trims and drops empty segments', () {
      expect(parseFlavors('dev, production ,, staging'), ['dev', 'production', 'staging']);
    });
  });
}
