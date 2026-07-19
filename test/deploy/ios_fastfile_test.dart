import 'package:flow/src/deploy/templates.dart';
import 'package:test/test.dart';

String _render({bool enableExternalTesting = false}) {
  return Templates.renderIosFastfile(
    keyId: 'ABC123',
    issuerId: 'issuer-uuid',
    keyFilepath: '/tmp/AuthKey.p8',
    appIdentifier: 'com.example.app',
    enableExternalTesting: enableExternalTesting,
    externalTestingConfig: enableExternalTesting ? 'groups: "QA",' : '',
  );
}

void main() {
  group('iOS Fastfile', () {
    test('renders with no placeholder left behind', () {
      for (final external in [false, true]) {
        final rendered = _render(enableExternalTesting: external);
        expect(
          RegExp(r'%\w+%').firstMatch(rendered)?.group(0),
          isNull,
          reason: 'unsubstituted placeholder would reach fastlane verbatim',
        );
      }
    });

    test('resolves the ipa at lane runtime, not at generation time', () {
      final rendered = _render();
      // The .ipa does not exist while flow writes this file, so the path must
      // stay a Ruby call the lane evaluates later — never a baked-in filename.
      expect(rendered, contains('def flutter_ipa_path'));
      expect('ipa:'.allMatches(rendered).length, 2);
      expect('ipa: flutter_ipa_path'.allMatches(rendered).length, 2);
    });
  });
}
