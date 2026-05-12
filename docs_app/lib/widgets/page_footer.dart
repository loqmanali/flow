import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/nav.dart';
import '../theme/app_theme.dart';

class PageFooter extends StatelessWidget {
  const PageFooter({super.key, required this.currentPath});
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final entries = kAllEntries;
    final idx = entries.indexWhere((e) => e.path == currentPath);
    final prev = idx > 0 ? entries[idx - 1] : null;
    final next = idx >= 0 && idx < entries.length - 1 ? entries[idx + 1] : null;

    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(color: tokens.border, height: 1),
          const SizedBox(height: 28),
          Row(
            children: [
              if (prev != null) _NavCard(label: 'Previous', entry: prev, alignEnd: false),
              const Spacer(),
              if (next != null) _NavCard(label: 'Next', entry: next, alignEnd: true),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Built with Flutter • flow v0.1.0',
            style: TextStyle(color: tokens.textSubtle, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _NavCard extends StatefulWidget {
  const _NavCard({required this.label, required this.entry, required this.alignEnd});
  final String label;
  final DocEntry entry;
  final bool alignEnd;

  @override
  State<_NavCard> createState() => _NavCardState();
}

class _NavCardState extends State<_NavCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(widget.entry.path),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: _hover ? tokens.accent : tokens.border),
            borderRadius: BorderRadius.circular(8),
            color: _hover ? tokens.surfaceMuted : tokens.surface,
          ),
          constraints: const BoxConstraints(minWidth: 200),
          child: Column(
            crossAxisAlignment:
                widget.alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                widget.label,
                style: TextStyle(color: tokens.textSubtle, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.alignEnd) ...[
                    Icon(Icons.arrow_back, size: 14, color: tokens.text),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    widget.entry.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.alignEnd) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward, size: 14, color: tokens.text),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
