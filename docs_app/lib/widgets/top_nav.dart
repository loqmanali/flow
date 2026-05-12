import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class TopNav extends StatelessWidget {
  const TopNav({
    super.key,
    required this.darkMode,
    required this.onToggleTheme,
  });

  final bool darkMode;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: tokens.background.withValues(alpha: 0.85),
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _Brand(),
          const SizedBox(width: 32),
          Text(
            'docs',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.textSubtle,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          _IconLink(
            tooltip: 'GitHub',
            icon: Icons.code,
            onTap: () => launchUrl(Uri.parse('https://github.com/loqmanali/flow')),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: darkMode ? 'Switch to light' : 'Switch to dark',
            iconSize: 18,
            color: tokens.textMuted,
            onPressed: onToggleTheme,
            icon: Icon(darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [tokens.accent, tokens.accent.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(5),
          ),
          alignment: Alignment.center,
          child: const Text(
            '~',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'flow',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

class _IconLink extends StatelessWidget {
  const _IconLink({required this.tooltip, required this.icon, required this.onTap});
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      iconSize: 18,
      color: tokens.textMuted,
      icon: Icon(icon),
    );
  }
}
