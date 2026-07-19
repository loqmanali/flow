import 'package:flow/flow.dart';
import 'package:test/test.dart';

/// Regression guard for the specific trap in `bin/flow.dart`: any first
/// argument not in [kTopLevelCommands] gets silently rewritten into
/// `deploy run <arg>` (so profile shortcuts like `flow dev` work). If
/// `create` is ever dropped from this set, `flow create my_app` would
/// silently become `flow deploy run create my_app` instead of scaffolding a
/// project.
void main() {
  test('kTopLevelCommands contains create', () {
    expect(kTopLevelCommands, contains('create'));
  });

  test('the deploy-run rewrite predicate leaves `flow create` alone', () {
    // Mirrors the exact condition in bin/flow.dart's main().
    bool wouldRewrite(List<String> args) =>
        args.isNotEmpty && !args.first.startsWith('-') && !kTopLevelCommands.contains(args.first);

    expect(
      wouldRewrite(['create', 'my_app']),
      isFalse,
      reason: '`flow create my_app` must not be rewritten to `flow deploy run create my_app`',
    );
    expect(
      wouldRewrite(['create']),
      isFalse,
      reason: '`flow create` (no args) must not be rewritten either',
    );
    // Sanity check: an actual profile shortcut is still rewritten.
    expect(wouldRewrite(['dev']), isTrue);
  });
}
