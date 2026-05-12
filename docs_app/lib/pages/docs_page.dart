import 'package:flutter/material.dart';

import '../data/nav.dart';
import '../theme/app_theme.dart';
import '../widgets/doc_markdown_view.dart';
import '../widgets/page_footer.dart';
import '../widgets/sidebar.dart';
import '../widgets/top_nav.dart';

/// Persistent shell wrapping every documentation route.
///
/// The shell is built once by `go_router`'s `ShellRoute` and only the [child]
/// slot is replaced when navigating. The top nav and sidebar stay mounted —
/// their scroll positions, hover states, and any animations they hold are
/// preserved across navigation.
class DocsShell extends StatelessWidget {
  const DocsShell({
    super.key,
    required this.currentPath,
    required this.darkMode,
    required this.onToggleTheme,
    required this.child,
  });

  final String currentPath;
  final bool darkMode;
  final VoidCallback onToggleTheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 1024;
    return Scaffold(
      body: Column(
        children: [
          TopNav(darkMode: darkMode, onToggleTheme: onToggleTheme),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isWide) DocsSidebar(currentPath: currentPath),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The actual page body: breadcrumbs + markdown view + prev/next footer.
///
/// Stateful so each instance owns a [ScrollController] — when the user
/// navigates to a new doc the content area starts fresh at the top, while
/// the surrounding shell (sidebar) keeps its own scroll position.
class DocsContent extends StatefulWidget {
  const DocsContent({super.key, required this.entry});
  final DocEntry entry;

  @override
  State<DocsContent> createState() => _DocsContentState();
}

class _DocsContentState extends State<DocsContent> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scroll,
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Breadcrumbs(entry: widget.entry),
                  const SizedBox(height: 12),
                  DocMarkdownView(asset: widget.entry.asset),
                  PageFooter(currentPath: widget.entry.path),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.entry});
  final DocEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    String section = '';
    for (final s in kNav) {
      if (s.entries.contains(entry)) {
        section = s.title;
        break;
      }
    }
    return Row(
      children: [
        Text(section, style: TextStyle(color: tokens.textSubtle, fontSize: 13)),
        if (section.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.chevron_right, size: 14, color: tokens.textSubtle),
          ),
        Text(
          entry.title,
          style: TextStyle(color: tokens.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
