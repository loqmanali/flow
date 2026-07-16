import 'package:flow/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widget_kit/widget_kit.dart';

import '../state/flow_project_state.dart';

/// Read-only view of the project's flavors, with placeholders for actions.
///
/// Destructive actions (replace, reset) stay disabled until proper
/// confirmation dialogs + validation exist — see TODOs below.
class FlavorsScreen extends ConsumerWidget {
  const FlavorsScreen({super.key, required this.project});

  final FlowProjectState? project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProject = project;
    if (selectedProject == null) {
      return const Center(child: Text('Select a project first (Project tab).'));
    }

    final flavorConfig = selectedProject.flavorConfig;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Flavors — ${selectedProject.projectName}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              // TODO(flow_studio): wire to a GUI form over the init wizard —
              // needs prompts as forms, not terminal prompts.
              const _PlaceholderAction(label: 'Init'),
              const SizedBox(width: 8),
              const _PlaceholderAction(label: 'Add flavor'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child:
                flavorConfig == null
                    ? const Center(
                      child: Text(
                        'No valid .flow_flavor.json in this project.\n'
                        'Run "flow flavor init" in a terminal for now.',
                        textAlign: TextAlign.center,
                      ),
                    )
                    : _FlavorList(config: flavorConfig),
          ),
        ],
      ),
    );
  }
}

class _FlavorList extends StatelessWidget {
  const _FlavorList({required this.config});

  final FlavorConfig config;

  @override
  Widget build(BuildContext context) {
    final flavors = config.flavors;
    final production = config.productionFlavor;

    return ListView(
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text('App name: ${config.appName}'),
            subtitle: Text('Config file: ${config.appConfigPath}'),
          ),
        ),
        const SizedBox(height: 8),
        for (final flavor in flavors)
          Card(
            child: ListTile(
              leading: Icon(
                flavor == production ? Icons.star : Icons.style_outlined,
                color: flavor == production ? Colors.amber.shade700 : null,
              ),
              title: Text(flavor),
              subtitle:
                  flavor == production ? const Text('production flavor') : null,
              trailing: const Wrap(
                spacing: 4,
                children: [
                  // TODO(flow_studio): enable once confirmation dialogs +
                  // dry-run validation exist. replace/reset touch project
                  // files and must never run from a single click.
                  _PlaceholderAction(label: 'Replace'),
                  _PlaceholderAction(label: 'Delete'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PlaceholderAction extends StatelessWidget {
  const _PlaceholderAction({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Coming soon — not wired yet',
      child: AppButton(
        label: label,
        style: AppButtonStyleType.outlined,
        size: AdaptiveButtonSize.small,
        widthMode: AppButtonWidthMode.hug,
        isDisabled: true,
      ),
    );
  }
}
