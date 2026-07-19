import 'package:flow/src/create/commands/create_command.dart';
import 'package:flow/src/create/utils/wizard_plan.dart';
import 'package:test/test.dart';

void main() {
  group('shouldRunCreateWizard', () {
    test('never prompts without a real terminal, even if --no-input is absent', () {
      // The single most important guard in this feature: a CI job with no
      // tty must fail fast instead of hanging on a prompt nobody can answer.
      expect(shouldRunCreateWizard(noInput: false, hasTerminal: false), isFalse);
    });

    test('never prompts when --no-input is passed, even on a real terminal', () {
      expect(shouldRunCreateWizard(noInput: true, hasTerminal: true), isFalse);
    });

    test('prompts only on a real terminal without --no-input', () {
      expect(shouldRunCreateWizard(noInput: false, hasTerminal: true), isTrue);
    });

    test('never prompts with neither a terminal nor --no-input relevant (both false)', () {
      expect(shouldRunCreateWizard(noInput: true, hasTerminal: false), isFalse);
    });
  });

  // Builds the same ArgParser `flow create` registers, without touching a
  // real terminal or the filesystem — proves flags-already-passed are never
  // re-prompted.
  group('resolveCreateWizardPlan', () {
    test('needs everything when no flags are passed', () {
      final results = CreateCommand().argParser.parse(const []);
      final plan = resolveCreateWizardPlan(results);

      expect(plan.needsOrg, isTrue);
      expect(plan.needsBundleId, isTrue);
      expect(plan.needsDisplay, isTrue);
      expect(plan.needsFlavors, isTrue);
      expect(plan.needsTemplate, isTrue);
    });

    test('skips --org when passed explicitly', () {
      final results = CreateCommand().argParser.parse(['--org', 'com.acme']);
      expect(resolveCreateWizardPlan(results).needsOrg, isFalse);
    });

    test('skips --bundle-id when passed explicitly', () {
      final results = CreateCommand().argParser.parse(['--bundle-id', 'com.acme.myapp']);
      expect(resolveCreateWizardPlan(results).needsBundleId, isFalse);
    });

    test('skips --display when passed explicitly', () {
      final results = CreateCommand().argParser.parse(['--display', 'My App']);
      expect(resolveCreateWizardPlan(results).needsDisplay, isFalse);
    });

    test('skips --flavors when passed explicitly', () {
      final results = CreateCommand().argParser.parse(['--flavors', 'dev,production']);
      expect(resolveCreateWizardPlan(results).needsFlavors, isFalse);
    });

    test('skips the template confirm when --template is passed explicitly', () {
      final results = CreateCommand().argParser.parse(['--template', 'https://example.com/x.git']);
      expect(resolveCreateWizardPlan(results).needsTemplate, isFalse);
    });

    test('skips the template confirm when only --ref is passed explicitly', () {
      final results = CreateCommand().argParser.parse(['--ref', 'v1.0.0']);
      expect(resolveCreateWizardPlan(results).needsTemplate, isFalse);
    });

    test('a flag left at its default is still treated as needing a prompt', () {
      // --org defaults to com.example in the ArgParser itself; not passing
      // it explicitly must still trigger the prompt, not silently accept
      // the default.
      final results = CreateCommand().argParser.parse(const []);
      expect(results['org'], 'com.example');
      expect(resolveCreateWizardPlan(results).needsOrg, isTrue);
    });
  });
}
