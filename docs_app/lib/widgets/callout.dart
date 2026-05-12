import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum CalloutKind { tip, info, warn, danger, note }

CalloutKind? parseCalloutKind(String value) {
  return switch (value.toLowerCase().trim()) {
    'tip' => CalloutKind.tip,
    'info' || 'note' => CalloutKind.info,
    'warn' || 'warning' => CalloutKind.warn,
    'danger' || 'error' => CalloutKind.danger,
    'important' => CalloutKind.note,
    _ => null,
  };
}

class Callout extends StatelessWidget {
  const Callout({super.key, required this.kind, required this.child, this.title});

  final CalloutKind kind;
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final (border, dot, label) = switch (kind) {
      CalloutKind.tip => (const Color(0xFF22C55E), const Color(0xFF22C55E), 'Tip'),
      CalloutKind.info => (tokens.accent, tokens.accent, 'Note'),
      CalloutKind.warn => (const Color(0xFFEAB308), const Color(0xFFEAB308), 'Warning'),
      CalloutKind.danger => (const Color(0xFFEF4444), const Color(0xFFEF4444), 'Danger'),
      CalloutKind.note => (tokens.accent, tokens.accent, 'Important'),
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        border: Border(left: BorderSide(color: border, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title ?? label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
            child: child,
          ),
        ],
      ),
    );
  }
}
