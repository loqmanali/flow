import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../theme/app_theme.dart';
import 'callout.dart';
import 'code_block.dart';

/// Renders a markdown asset with the docs-app's custom styling.
///
/// Pre-processes the markdown so that lines like `:::tip Custom title` /
/// `:::warn` / `:::info` open a [Callout] block (closed by a `:::` line).
/// All standard markdown features pass straight through to `markdown_widget`.
class DocMarkdownView extends StatefulWidget {
  const DocMarkdownView({super.key, required this.asset});

  final String asset;

  @override
  State<DocMarkdownView> createState() => _DocMarkdownViewState();
}

class _DocMarkdownViewState extends State<DocMarkdownView> {
  late Future<String> _content;

  @override
  void initState() {
    super.initState();
    _content = rootBundle.loadString(widget.asset);
  }

  @override
  void didUpdateWidget(covariant DocMarkdownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _content = rootBundle.loadString(widget.asset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _content,
      builder: (context, snap) {
        if (!snap.hasData) {
          if (snap.hasError) {
            return _missingAssetView(context);
          }
          return const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        return _RenderedMarkdown(raw: snap.data!);
      },
    );
  }

  Widget _missingAssetView(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Callout(
        kind: CalloutKind.warn,
        title: 'Page coming soon',
        child: Text(
          'This page has not been authored yet. Expected asset: ${widget.asset}',
          style: TextStyle(color: tokens.textMuted),
        ),
      ),
    );
  }
}

class _RenderedMarkdown extends StatelessWidget {
  const _RenderedMarkdown({required this.raw});

  final String raw;

  @override
  Widget build(BuildContext context) {
    final parts = _splitCallouts(raw);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final part in parts)
          if (part is _CalloutPart)
            Callout(
              kind: part.kind,
              title: part.title,
              child: MarkdownBlock(
                data: part.body,
                config: _markdownConfig(context, isInCallout: true),
              ),
            )
          else if (part is _MarkdownPart)
            MarkdownBlock(data: part.body, config: _markdownConfig(context)),
      ],
    );
  }

  MarkdownConfig _markdownConfig(BuildContext context, {bool isInCallout = false}) {
    final tokens = context.tokens;
    final tt = Theme.of(context).textTheme;

    return MarkdownConfig(
      configs: [
        // Headings
        H1Config(style: tt.headlineLarge!.copyWith(fontSize: 34)),
        H2Config(style: tt.headlineMedium!.copyWith(fontSize: 22, height: 1.3)),
        H3Config(style: tt.headlineSmall!.copyWith(fontSize: 17)),
        H4Config(style: tt.headlineSmall!.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
        // Body
        PConfig(textStyle: tt.bodyLarge!.copyWith(color: tokens.text)),
        // Inline code
        CodeConfig(
          style: GoogleFonts.jetBrainsMono(
            color: tokens.text,
            fontSize: 13,
            backgroundColor: tokens.surfaceMuted,
            letterSpacing: 0,
          ),
        ),
        // Fenced code blocks
        PreConfig(
          padding: EdgeInsets.zero,
          decoration: const BoxDecoration(),
          margin: EdgeInsets.zero,
          textStyle: AppTheme.mono(color: tokens.text),
          builder: (code, language) =>
              CodeBlock(code: code, language: language.isEmpty ? null : language),
        ),
        // Quotes
        BlockquoteConfig(
          sideColor: tokens.border,
          textColor: tokens.textMuted,
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        ),
        // Lists
        ListConfig(
          marker: (isOrdered, depth, index) {
            if (isOrdered) {
              return Padding(
                padding: const EdgeInsets.only(right: 8, top: 2),
                child: Text(
                  '${index + 1}.',
                  style: AppTheme.mono(color: tokens.textMuted, size: 13),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(right: 10, top: 8),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: tokens.textMuted, shape: BoxShape.circle),
              ),
            );
          },
        ),
        TableConfig(
          headerStyle: tt.labelLarge!.copyWith(fontWeight: FontWeight.w600),
          bodyStyle: tt.bodyMedium!,
          border: TableBorder.all(color: tokens.border, width: 1),
          headPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          bodyPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          headerRowDecoration: BoxDecoration(color: tokens.surfaceMuted),
        ),
        HrConfig(color: tokens.border, height: 1),
        LinkConfig(
          style: TextStyle(
            color: tokens.accent,
            decoration: TextDecoration.underline,
            fontSize: 15.5,
          ),
          onTap: (url) {},
        ),
      ],
    );
  }
}

// --- Custom callout pre-processor -----------------------------------------
abstract class _Part {}

class _MarkdownPart extends _Part {
  _MarkdownPart(this.body);
  final String body;
}

class _CalloutPart extends _Part {
  _CalloutPart({required this.kind, required this.title, required this.body});
  final CalloutKind kind;
  final String? title;
  final String body;
}

final _calloutOpen = RegExp(r'^:::(tip|info|warn|warning|danger|important|note)(?:\s+(.*))?$', multiLine: true);

List<_Part> _splitCallouts(String raw) {
  final out = <_Part>[];
  final lines = raw.split('\n');
  final mdBuf = StringBuffer();
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    final m = _calloutOpen.firstMatch(line);
    if (m != null) {
      if (mdBuf.isNotEmpty) {
        out.add(_MarkdownPart(mdBuf.toString()));
        mdBuf.clear();
      }
      final kind = parseCalloutKind(m.group(1)!) ?? CalloutKind.info;
      final title = (m.group(2) ?? '').trim().isEmpty ? null : m.group(2)!.trim();
      i++;
      final body = StringBuffer();
      while (i < lines.length && lines[i].trim() != ':::') {
        body.writeln(lines[i]);
        i++;
      }
      if (i < lines.length) i++; // skip closing :::
      out.add(_CalloutPart(kind: kind, title: title, body: body.toString().trimRight()));
      continue;
    }
    mdBuf.writeln(line);
    i++;
  }
  if (mdBuf.isNotEmpty) {
    out.add(_MarkdownPart(mdBuf.toString()));
  }
  return out;
}
