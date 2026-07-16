import 'package:flutter/material.dart';

/// Read-only terminal-style console that follows the tail of [lines].
class LogConsole extends StatefulWidget {
  const LogConsole({super.key, required this.lines});

  final List<String> lines;

  @override
  State<LogConsole> createState() => _LogConsoleState();
}

class _LogConsoleState extends State<LogConsole> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant LogConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lines.length != oldWidget.lines.length) {
      // Follow the tail after this frame's layout.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111318),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child:
          widget.lines.isEmpty
              ? const Text(
                'Run a profile to see its output here.',
                style: TextStyle(color: Colors.white38, fontFamily: 'Menlo'),
              )
              : ListView.builder(
                controller: _scrollController,
                itemCount: widget.lines.length,
                itemBuilder:
                    (context, index) => SelectableText(
                      widget.lines[index],
                      style: const TextStyle(
                        color: Color(0xFFD6D8DE),
                        fontFamily: 'Menlo',
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
              ),
    );
  }
}
