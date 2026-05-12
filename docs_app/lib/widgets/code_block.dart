import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A polished code block: language pill, copy button, JetBrains Mono content.
///
/// Used directly for hand-authored snippets in dart pages, and from
/// [DocMarkdownView] when rendering fenced markdown code blocks.
class CodeBlock extends StatefulWidget {
  const CodeBlock({super.key, required this.code, this.language});

  final String code;
  final String? language;

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(milliseconds: 1400)).then((_) {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isTerminal = widget.language == 'terminal' || widget.language == 'shell-output';
    final showHeader = widget.language != null;

    final headerBg = isTerminal ? tokens.background : tokens.surfaceMuted;
    final bodyBg = isTerminal ? tokens.background : tokens.surfaceMuted;
    final textColor = isTerminal ? tokens.text : tokens.text;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: bodyBg,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            Container(
              decoration: BoxDecoration(
                color: headerBg,
                border: Border(bottom: BorderSide(color: tokens.border)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              child: Row(
                children: [
                  if (isTerminal)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        _TrafficDot(color: Color(0xFFFF5F57)),
                        SizedBox(width: 6),
                        _TrafficDot(color: Color(0xFFFEBC2E)),
                        SizedBox(width: 6),
                        _TrafficDot(color: Color(0xFF28C840)),
                      ],
                    )
                  else
                    Text(
                      widget.language!,
                      style: AppTheme.mono(
                        color: tokens.textSubtle,
                        size: 11,
                        weight: FontWeight.w500,
                      ),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _copy,
                    style: TextButton.styleFrom(
                      foregroundColor: _copied ? tokens.accent : tokens.textMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(_copied ? Icons.check : Icons.copy, size: 14),
                    label: Text(
                      _copied ? 'Copied' : 'Copy',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText.rich(
                _highlight(widget.code, widget.language, tokens, defaultColor: textColor),
                style: AppTheme.mono(color: textColor, size: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrafficDot extends StatelessWidget {
  const _TrafficDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

/// Tiny purpose-built highlighter. Not a full lexer — just enough to make
/// shell, JSON, Dart and YAML feel polished without a heavy dependency.
TextSpan _highlight(String code, String? language, DocsTokens tokens, {required Color defaultColor}) {
  final muted = tokens.textMuted;
  final accent = tokens.accent;
  final keyword = const Color(0xFFEAB308); // amber
  final string = const Color(0xFF22C55E); // green
  final comment = tokens.textSubtle;
  final number = const Color(0xFFF97316); // orange

  RegExp r(String pattern) => RegExp(pattern, multiLine: true);
  final patterns = <_Pat>[];

  switch (language) {
    case 'terminal':
    case 'shell-output':
      patterns.addAll([
        _Pat(r(r'^\$ .*$'), TextStyle(color: defaultColor, fontWeight: FontWeight.w600)),
        _Pat(r(r'\[(WARN|ERROR|FAIL|FATAL)\]'), TextStyle(color: const Color(0xFFEF4444), fontWeight: FontWeight.w600)),
        _Pat(r(r'\[(INFO|OK|DONE)\]'), TextStyle(color: string, fontWeight: FontWeight.w600)),
        _Pat(r(r'✔|✓'), TextStyle(color: string, fontWeight: FontWeight.w700)),
        _Pat(r(r'✖|❌'), TextStyle(color: const Color(0xFFEF4444), fontWeight: FontWeight.w700)),
        _Pat(r(r'#.*$'), TextStyle(color: comment, fontStyle: FontStyle.italic)),
      ]);
      break;
    case 'bash':
    case 'sh':
    case 'shell':
      patterns.addAll([
        _Pat(r(r'#.*$'), TextStyle(color: comment, fontStyle: FontStyle.italic)),
        _Pat(r(r'\b(flow|dart|flutter|fastlane|firebase|flutterfire)\b'), TextStyle(color: accent, fontWeight: FontWeight.w600)),
        _Pat(r(r'--[a-zA-Z0-9-]+'), TextStyle(color: keyword)),
        _Pat(r('"[^"\\n]*"|' "'[^'\\n]*'"), TextStyle(color: string)),
      ]);
      break;
    case 'json':
      patterns.addAll([
        _Pat(r(r'"[a-zA-Z_][a-zA-Z0-9_]*"(?=\s*:)'), TextStyle(color: accent, fontWeight: FontWeight.w500)),
        _Pat(r(r':\s*"[^"]*"'), TextStyle(color: string)),
        _Pat(r(r'\b(true|false|null)\b'), TextStyle(color: keyword)),
        _Pat(r(r'\b\d+(\.\d+)?\b'), TextStyle(color: number)),
      ]);
      break;
    case 'yaml':
    case 'yml':
      patterns.addAll([
        _Pat(r(r'#.*$'), TextStyle(color: comment, fontStyle: FontStyle.italic)),
        _Pat(r(r'^[ \t]*[a-zA-Z_][a-zA-Z0-9_-]*(?=:)'), TextStyle(color: accent, fontWeight: FontWeight.w500)),
        _Pat(r(r'\b(true|false|null)\b'), TextStyle(color: keyword)),
        _Pat(r(r'\b\d+(\.\d+)?\b'), TextStyle(color: number)),
      ]);
      break;
    case 'dart':
      patterns.addAll([
        _Pat(r(r'//.*$'), TextStyle(color: comment, fontStyle: FontStyle.italic)),
        _Pat(
          r(r'\b(import|class|extends|implements|with|sealed|abstract|final|const|var|void|return|if|else|switch|case|for|while|async|await|Future|String|int|bool|double|List|Map|Set)\b'),
          TextStyle(color: accent, fontWeight: FontWeight.w500),
        ),
        _Pat(r('"[^"\\n]*"|' "'[^'\\n]*'"), TextStyle(color: string)),
        _Pat(r(r'\b\d+(\.\d+)?\b'), TextStyle(color: number)),
      ]);
      break;
    default:
      break;
  }

  if (patterns.isEmpty) {
    return TextSpan(text: code, style: TextStyle(color: defaultColor));
  }

  // Build a non-overlapping list of (start, end, style).
  final ranges = <_Range>[];
  for (final p in patterns) {
    for (final m in p.regex.allMatches(code)) {
      if (m.start == m.end) continue;
      ranges.add(_Range(m.start, m.end, p.style));
    }
  }
  ranges.sort((a, b) => a.start.compareTo(b.start));
  // Drop overlaps — earliest wins.
  final filtered = <_Range>[];
  var cursor = 0;
  for (final r in ranges) {
    if (r.start < cursor) continue;
    filtered.add(r);
    cursor = r.end;
  }

  final spans = <TextSpan>[];
  var i = 0;
  for (final r in filtered) {
    if (r.start > i) {
      spans.add(TextSpan(text: code.substring(i, r.start), style: TextStyle(color: defaultColor)));
    }
    spans.add(TextSpan(text: code.substring(r.start, r.end), style: r.style));
    i = r.end;
  }
  if (i < code.length) {
    spans.add(TextSpan(text: code.substring(i), style: TextStyle(color: defaultColor)));
  }
  // Silence muted lint for unused variable — `muted` is reserved for future
  // accent-line styling, keep the reference so the analyzer is happy.
  return TextSpan(children: spans, style: TextStyle(color: muted));
}

class _Pat {
  const _Pat(this.regex, this.style);
  final RegExp regex;
  final TextStyle style;
}

class _Range {
  _Range(this.start, this.end, this.style);
  final int start;
  final int end;
  final TextStyle style;
}
