import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_kit/widget_kit.dart';

import 'src/app/studio_shell.dart';
import 'src/state/recent_projects.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const FlowStudioApp(),
    ),
  );
}

class FlowStudioApp extends StatelessWidget {
  const FlowStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: MaterialApp(
        title: 'flow studio',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
          visualDensity: VisualDensity.comfortable,
        ),
        home: const StudioShell(),
      ),
    );
  }
}
