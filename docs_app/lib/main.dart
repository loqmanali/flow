import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/nav.dart';
import 'pages/docs_page.dart';
import 'theme/app_theme.dart';

/// Key under which the user's dark-mode preference is persisted.
const String _themePrefKey = 'flow_docs_dark';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final prefs = await SharedPreferences.getInstance();
  // Default to dark on first load; honor the saved choice on every subsequent
  // visit. Resolving before runApp avoids a flash of the wrong theme.
  final initialDark = prefs.getBool(_themePrefKey) ?? true;
  runApp(DocsApp(prefs: prefs, initialDark: initialDark));
}

class DocsApp extends StatefulWidget {
  const DocsApp({super.key, required this.prefs, required this.initialDark});

  final SharedPreferences prefs;
  final bool initialDark;

  @override
  State<DocsApp> createState() => _DocsAppState();
}

class _DocsAppState extends State<DocsApp> {
  late bool _dark = widget.initialDark;

  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return DocsShell(
            currentPath: state.uri.path,
            darkMode: _dark,
            onToggleTheme: _toggleTheme,
            child: child,
          );
        },
        routes: [
          for (final entry in kAllEntries)
            GoRoute(
              path: entry.path,
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: ValueKey(entry.path),
                transitionDuration: const Duration(milliseconds: 180),
                reverseTransitionDuration: const Duration(milliseconds: 180),
                child: DocsContent(entry: entry),
                transitionsBuilder: (context, animation, _, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.02),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                      ),
                      child: child,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ],
    errorBuilder: (context, state) => DocsShell(
      currentPath: '/',
      darkMode: _dark,
      onToggleTheme: _toggleTheme,
      child: DocsContent(entry: kAllEntries.first),
    ),
  );

  void _toggleTheme() {
    setState(() => _dark = !_dark);
    // Fire and forget — the write is local and tiny.
    widget.prefs.setBool(_themePrefKey, _dark);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      _dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
    return MaterialApp.router(
      title: 'flow • docs',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
    );
  }
}
