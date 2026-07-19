import 'package:flow/src/create/utils/display_name.dart';
import 'package:test/test.dart';

void main() {
  group('defaultDisplayName', () {
    test('title-cases each underscore-separated word', () {
      expect(defaultDisplayName('my_app'), 'My App');
    });

    test('handles a single-word name', () {
      expect(defaultDisplayName('flow'), 'Flow');
    });

    test('handles three or more words', () {
      expect(defaultDisplayName('my_cool_app'), 'My Cool App');
    });
  });
}
