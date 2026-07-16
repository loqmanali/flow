import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widget_kit/widget_kit.dart';

import '../state/deploy_console_controller.dart';
import '../state/flow_project_state.dart';
import '../widgets/log_console.dart';

/// Deploy profiles from .flow_deploy.json as runnable cards + live console.
class DeployScreen extends ConsumerWidget {
  const DeployScreen({super.key, required this.project});

  final FlowProjectState? project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProject = project;
    if (selectedProject == null) {
      return const _CenteredHint(
        message: 'Select a project first (Project tab).',
      );
    }
    if (!selectedProject.hasDeployConfig) {
      return const _CenteredHint(
        message:
            'This project has no .flow_deploy.json yet.\n'
            'Run "flow deploy init" in the project to create one.',
      );
    }

    final console = ref.watch(deployConsoleProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deploy — ${selectedProject.projectName}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          if (selectedProject.deployProfileNames.isEmpty)
            const Text('No profiles defined in .flow_deploy.json.')
          else
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final profileName in selectedProject.deployProfileNames)
                    _ProfileCard(
                      profileName: profileName,
                      profile:
                          selectedProject.deployProfiles[profileName] ??
                          const {},
                      isRunning: console.isRunning,
                      isThisRunning:
                          console.isRunning &&
                          console.runningProfile == profileName,
                      onRun:
                          (platformOverride) => ref
                              .read(deployConsoleProvider.notifier)
                              .runProfile(
                                profileName,
                                platformOverride: platformOverride,
                              ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Console', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 12),
              _ConsoleStatusChip(status: console.status),
              const Spacer(),
              AppButton(
                label: 'Clear',
                icon: Icon(Icons.clear_all, size: 16),
                style: AppButtonStyleType.text,
                widthMode: AppButtonWidthMode.hug,
                isDisabled: console.isRunning || console.lines.isEmpty,
                onPressed:
                    () => ref.read(deployConsoleProvider.notifier).clear(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: LogConsole(lines: console.lines)),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profileName,
    required this.profile,
    required this.isRunning,
    required this.isThisRunning,
    required this.onRun,
  });

  final String profileName;
  final Map<String, dynamic> profile;
  final bool isRunning;
  final bool isThisRunning;

  /// Called with `null` to run the profile as configured, or with
  /// 'ios' / 'android' to deploy that platform only.
  final ValueChanged<String?> onRun;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      for (final key in const ['platform', 'provider', 'flavor', 'action'])
        if (profile[key] != null) '$key: ${profile[key]}',
    ];

    return Card(
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rocket_launch_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    profileName,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                details.isEmpty ? 'No details' : details.join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    label:
                        isThisRunning
                            ? 'Running…'
                            : 'Run (${profile['platform'] ?? 'default'})',
                    icon: Icon(Icons.play_arrow, size: 16),
                    size: AdaptiveButtonSize.small,
                    widthMode: AppButtonWidthMode.hug,
                    isLoading: isThisRunning,
                    isDisabled: isRunning,
                    onPressed: () => onRun(null),
                  ),
                  PopupMenuButton<String>(
                    enabled: !isRunning,
                    padding: EdgeInsets.zero,
                    tooltip: 'Deploy a single platform',
                    icon: const Icon(Icons.expand_more, size: 20),
                    onSelected: onRun,
                    itemBuilder:
                        (context) => const [
                          PopupMenuItem(
                            value: 'ios',
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.phone_iphone, size: 18),
                              title: Text('iOS only'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'android',
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.android, size: 18),
                              title: Text('Android only'),
                            ),
                          ),
                        ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsoleStatusChip extends StatelessWidget {
  const _ConsoleStatusChip({required this.status});

  final DeployRunStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      DeployRunStatus.idle => ('idle', Theme.of(context).colorScheme.outline),
      DeployRunStatus.running => ('running', Colors.blue.shade700),
      DeployRunStatus.succeeded => ('succeeded', Colors.green.shade700),
      DeployRunStatus.failed => ('failed', Theme.of(context).colorScheme.error),
    };
    return Chip(
      label: Text(label),
      labelStyle: TextStyle(color: color),
      side: BorderSide(color: color),
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message, textAlign: TextAlign.center));
  }
}
