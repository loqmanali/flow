import 'package:flow/src/create/utils/name_validation.dart';
import 'package:test/test.dart';

void main() {
  group('validateProjectName', () {
    test('accepts a valid lower_snake_case name', () {
      expect(validateProjectName('my_app'), isNull);
    });

    test('accepts a single-word name', () {
      expect(validateProjectName('flow'), isNull);
    });

    test('rejects an empty name', () {
      expect(validateProjectName(''), isNotNull);
    });

    test('rejects UpperCamelCase', () {
      expect(validateProjectName('MyApp'), isNotNull);
    });

    test('rejects hyphens', () {
      expect(validateProjectName('my-app'), isNotNull);
    });

    test('rejects a leading digit', () {
      expect(validateProjectName('1app'), isNotNull);
    });

    test('rejects a Dart reserved word', () {
      expect(validateProjectName('class'), isNotNull);
      expect(validateProjectName('void'), isNotNull);
    });

    test('rejects "flutter"', () {
      expect(validateProjectName('flutter'), isNotNull);
    });

    test('rejects "test"', () {
      expect(validateProjectName('test'), isNotNull);
    });
  });
}
