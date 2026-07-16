import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widget_kit/widget_kit.dart';

import '../state/flow_project_state.dart';
import '../state/recent_projects.dart';
import 'init_flow_wizard.dart';

/// Pick a Flutter project folder and show what flow knows about it.
class ProjectPickerScreen extends ConsumerWidget {
  const ProjectPickerScreen({super.key});

  Future<void> _pickProject(WidgetRef ref) async {
    final directoryPath = await getDirectoryPath(
      confirmButtonText: 'Open project',
    );
    if (directoryPath == null) return;
    await ref.read(flowProjectProvider.notifier).selectProject(directoryPath);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(flowProjectProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Project', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              if (project != null)
                AppButton(
                  label: 'Refresh',
                  icon: Icon(Icons.refresh, size: 16),
                  style: AppButtonStyleType.outlined,
                  widthMode: AppButtonWidthMode.hug,
                  onPressed:
                      () => ref.read(flowProjectProvider.notifier).refresh(),
                ),
              const SizedBox(width: 8),
              AppButton(
                label: project == null ? 'Open Flutter project…' : 'Change…',
                icon: Icon(Icons.folder_open, size: 16),
                widthMode: AppButtonWidthMode.hug,
                onPressed: () => _pickProject(ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child:
                project == null
                    ? const _RecentProjectsList()
                    : _ProjectStatusView(project: project),
          ),
        ],
      ),
    );
  }
}

/// Recent projects history — shown while nothing is selected.
class _RecentProjectsList extends ConsumerWidget {
  const _RecentProjectsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentProjects = ref.watch(recentProjectsProvider);

    if (recentProjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_off_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text('No project selected'),
            const SizedBox(height: 4),
            Text(
              'Open a Flutter project folder to inspect its flavor and deploy setup.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recent projects',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            AppButton(
              label: 'Clear history',
              style: AppButtonStyleType.text,
              size: AdaptiveButtonSize.small,
              widthMode: AppButtonWidthMode.hug,
              onPressed:
                  () => ref.read(recentProjectsProvider.notifier).clear(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              for (final entry in recentProjects)
                _RecentProjectTile(entry: entry),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentProjectTile extends ConsumerWidget {
  const _RecentProjectTile({required this.entry});

  final RecentProjectEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = entry.isAvailable;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        enabled: available,
        leading: Icon(
          available ? Icons.flutter_dash : Icons.folder_off_outlined,
          color: available ? null : scheme.outline,
        ),
        title: Text(entry.name),
        subtitle: Text(
          available ? entry.path : '${entry.path} — folder no longer exists',
        ),
        onTap:
            available
                ? () => ref
                    .read(flowProjectProvider.notifier)
                    .selectProject(entry.path)
                : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.hasFlavorConfig)
              const Tooltip(
                message: 'Has flavor config',
                child: Icon(Icons.style_outlined, size: 18),
              ),
            if (entry.hasDeployConfig)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Tooltip(
                  message: 'Has deploy config',
                  child: Icon(Icons.rocket_launch_outlined, size: 18),
                ),
              ),
            IconButton(
              tooltip: 'Remove from history',
              icon: const Icon(Icons.close, size: 18),
              onPressed:
                  () => ref
                      .read(recentProjectsProvider.notifier)
                      .remove(entry.path),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown on the status panel when flow is not (fully) set up yet.
class _InitializeFlowBanner extends StatelessWidget {
  const _InitializeFlowBanner({required this.project});

  final FlowProjectState project;

  @override
  Widget build(BuildContext context) {
    final missing = [
      if (!project.hasFlavorConfig) 'flavors',
      if (!project.hasDeployConfig) 'deployment',
    ].join(' and ');

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.auto_fix_high),
        title: Text('Flow is not set up for $missing yet'),
        subtitle: const Text('Initialize it from here — no terminal needed.'),
        trailing: AppButton(
          label: 'Initialize Flow',
          icon: Icon(Icons.auto_fix_high, size: 16),
          widthMode: AppButtonWidthMode.hug,
          onPressed: () => showInitFlowWizard(context, project),
        ),
      ),
    );
  }
}

class _ProjectStatusView extends StatelessWidget {
  const _ProjectStatusView({required this.project});

  final FlowProjectState project;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _StatusCard(
          title: project.projectName,
          subtitle: project.projectPath,
          trailing:
              project.pubspecVersion == null
                  ? null
                  : Chip(label: Text('v${project.pubspecVersion}')),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final platform in project.detectedPlatforms)
              Chip(
                avatar: const Icon(Icons.devices, size: 16),
                label: Text(platform),
              ),
            _ConfigChip(
              label: '.flow_flavor.json',
              present: project.hasFlavorConfig,
            ),
            _ConfigChip(
              label: '.flow_deploy.json',
              present: project.hasDeployConfig,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!project.hasFlavorConfig || !project.hasDeployConfig) ...[
          _InitializeFlowBanner(project: project),
          const SizedBox(height: 16),
        ],
        if (project.issues.isNotEmpty) ...[
          Text('Checks', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final issue in project.issues) _IssueTile(issue: issue),
        ] else
          const _IssueTile(
            issue: ProjectIssue(
              message: 'Everything looks good.',
              isError: false,
            ),
          ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.flutter_dash),
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }
}

class _ConfigChip extends StatelessWidget {
  const _ConfigChip({required this.label, required this.present});

  final String label;
  final bool present;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        present ? Icons.check_circle : Icons.remove_circle_outline,
        size: 16,
        color: present ? Colors.green.shade700 : scheme.outline,
      ),
      label: Text(label),
    );
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({required this.issue});

  final ProjectIssue issue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: Icon(
        issue.isError ? Icons.error_outline : Icons.info_outline,
        color: issue.isError ? scheme.error : scheme.outline,
      ),
      title: Text(issue.message),
    );
  }
}
