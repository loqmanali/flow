import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flow_studio/main.dart';
import 'package:flow_studio/src/state/recent_projects.dart';

void main() {
  testWidgets('shell renders with the three destinations and empty state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const FlowStudioApp(),
      ),
    );

    expect(find.text('Project'), findsWidgets);
    expect(find.text('Deploy'), findsOneWidget);
    expect(find.text('Flavors'), findsOneWidget);
    expect(find.text('No project selected'), findsOneWidget);
  });
}
