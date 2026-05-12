import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/nav.dart';
import '../theme/app_theme.dart';

class DocsSidebar extends StatelessWidget {
  const DocsSidebar({super.key, required this.currentPath});
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: 264,
      decoration: BoxDecoration(
        color: tokens.background,
        border: Border(right: BorderSide(color: tokens.border)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final section in kNav) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
                child: Text(
                  section.title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: tokens.textSubtle,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              for (final entry in section.entries)
                _NavItem(entry: entry, active: entry.path == currentPath),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({required this.entry, required this.active});
  final DocEntry entry;
  final bool active;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final activeColor = tokens.text;
    final idleColor = tokens.textMuted;
    final hoverColor = tokens.text;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(widget.entry.path),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: widget.active
                ? tokens.surfaceMuted
                : (_hover ? tokens.surfaceMuted.withValues(alpha: 0.6) : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              if (widget.active)
                Container(
                  width: 3,
                  height: 14,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: tokens.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )
              else
                const SizedBox(width: 11),
              Expanded(
                child: Text(
                  widget.entry.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: widget.active ? activeColor : (_hover ? hoverColor : idleColor),
                    fontWeight: widget.active ? FontWeight.w500 : FontWeight.w400,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
