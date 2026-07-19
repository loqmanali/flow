import 'package:args/args.dart';

/// Whether `flow create` (invoked with no positional `<name>`) should walk
/// the user through the interactive wizard instead of failing fast with a
/// usage error.
///
/// Pure and side-effect free so the CI safety guard — never prompt when
/// there's no real terminal to answer from — is testable without a real
/// tty: a CI job piping in a closed/empty stdin must fail fast, not hang
/// forever waiting on input that will never come.
bool shouldRunCreateWizard({required bool noInput, required bool hasTerminal}) {
  return !noInput && hasTerminal;
}

/// Which interactive prompts the `create` wizard still needs to ask, given
/// the flags already parsed for `flow create`. Any option the user passed
/// explicitly on the command line is honored as-is and never re-prompted.
class CreateWizardPlan {
  const CreateWizardPlan({
    required this.needsOrg,
    required this.needsBundleId,
    required this.needsDisplay,
    required this.needsFlavors,
    required this.needsTemplate,
  });

  /// Prompt for the org. An explicit `--org` skips this.
  final bool needsOrg;

  /// Prompt for the bundle id. An explicit `--bundle-id` skips this.
  final bool needsBundleId;

  /// Prompt for the display name. An explicit `--display` skips this.
  final bool needsDisplay;

  /// Prompt whether to set up native flavors. An explicit `--flavors` skips
  /// this.
  final bool needsFlavors;

  /// Prompt whether to customize the template/ref. An explicit `--template`
  /// or `--ref` skips this — both the "use the default?" question and its
  /// two follow-ups.
  final bool needsTemplate;
}

/// Builds the [CreateWizardPlan] from `flow create`'s already-parsed
/// [ArgResults]. Pure — no prompting happens here, only the decision of
/// what still needs asking.
CreateWizardPlan resolveCreateWizardPlan(ArgResults results) {
  return CreateWizardPlan(
    needsOrg: !results.wasParsed('org'),
    needsBundleId: !results.wasParsed('bundle-id'),
    needsDisplay: !results.wasParsed('display'),
    needsFlavors: !results.wasParsed('flavors'),
    needsTemplate: !results.wasParsed('template') && !results.wasParsed('ref'),
  );
}
