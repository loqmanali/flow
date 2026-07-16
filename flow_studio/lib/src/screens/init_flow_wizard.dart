import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widget_kit/widget_kit.dart';

import '../state/flow_project_state.dart';
import '../state/init_flow_controller.dart';
import '../widgets/log_console.dart';

/// Opens the Init Flow wizard. Returns after the dialog closes.
Future<void> showInitFlowWizard(
  BuildContext context,
  FlowProjectState project,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder:
        (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 640),
            child: InitFlowWizard(project: project),
          ),
        ),
  );
}

enum _WizardStep { form, confirm, execute }

/// Three-step wizard: form → confirmation summary → execution log.
class InitFlowWizard extends ConsumerStatefulWidget {
  const InitFlowWizard({super.key, required this.project});

  final FlowProjectState project;

  @override
  ConsumerState<InitFlowWizard> createState() => _InitFlowWizardState();
}

class _InitFlowWizardState extends ConsumerState<InitFlowWizard> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _appDisplayNameController;
  late final TextEditingController _packageIdBaseController;
  late final TextEditingController _flavorsController;

  _WizardStep _step = _WizardStep.form;
  String _productionFlavor = '';
  bool _useSuffix = true;
  bool _createDeployConfig = true;
  String _deployTemplateKind = 'both';
  InitFlowPlan? _plan;

  @override
  void initState() {
    super.initState();
    _appDisplayNameController = TextEditingController(
      text: widget.project.projectName,
    );
    _packageIdBaseController = TextEditingController(
      text: 'com.example.${widget.project.projectName}',
    );
    _flavorsController = TextEditingController(text: 'dev, production');
    _productionFlavor = 'production';
  }

  @override
  void dispose() {
    _appDisplayNameController.dispose();
    _packageIdBaseController.dispose();
    _flavorsController.dispose();
    super.dispose();
  }

  List<String> get _parsedFlavors => [
    for (final flavor in _flavorsController.text.split(','))
      if (flavor.trim().isNotEmpty) flavor.trim().toLowerCase(),
  ];

  void _buildPlanAndConfirm() {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _plan = InitFlowPlan(
        appDisplayName: _appDisplayNameController.text.trim(),
        packageIdBase: _packageIdBaseController.text.trim(),
        flavors: _parsedFlavors,
        productionFlavor: _productionFlavor,
        useSuffix: _useSuffix,
        createFlavorConfig: !widget.project.hasFlavorConfig,
        createDeployConfig:
            _createDeployConfig && !widget.project.hasDeployConfig,
        deployTemplateKind: _deployTemplateKind,
      );
      _step = _WizardStep.confirm;
    });
  }

  Future<void> _execute() async {
    setState(() => _step = _WizardStep.execute);
    await ref.read(initFlowProvider.notifier).run(_plan!);
  }

  @override
  Widget build(BuildContext context) {
    final initState = ref.watch(initFlowProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_fix_high, size: 22),
              const SizedBox(width: 8),
              Text(
                'Initialize Flow — ${widget.project.projectName}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Close',
                onPressed:
                    initState.isRunning
                        ? null
                        : () {
                          ref.read(initFlowProvider.notifier).reset();
                          Navigator.of(context).pop();
                        },
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: switch (_step) {
              _WizardStep.form => _FormStep(
                formKey: _formKey,
                appDisplayNameController: _appDisplayNameController,
                packageIdBaseController: _packageIdBaseController,
                flavorsController: _flavorsController,
                parsedFlavors: _parsedFlavors,
                productionFlavor: _productionFlavor,
                useSuffix: _useSuffix,
                hasFlavorConfig: widget.project.hasFlavorConfig,
                hasDeployConfig: widget.project.hasDeployConfig,
                createDeployConfig: _createDeployConfig,
                deployTemplateKind: _deployTemplateKind,
                onProductionFlavorChanged:
                    (value) => setState(() => _productionFlavor = value),
                onUseSuffixChanged:
                    (value) => setState(() => _useSuffix = value),
                onCreateDeployConfigChanged:
                    (value) => setState(() => _createDeployConfig = value),
                onDeployTemplateKindChanged:
                    (value) => setState(() => _deployTemplateKind = value),
                onFlavorsEdited:
                    () => setState(() {
                      if (!_parsedFlavors.contains(_productionFlavor) &&
                          _parsedFlavors.isNotEmpty) {
                        _productionFlavor = _parsedFlavors.last;
                      }
                    }),
              ),
              _WizardStep.confirm => _ConfirmStep(plan: _plan!),
              _WizardStep.execute => LogConsole(lines: initState.logLines),
            },
          ),
          const SizedBox(height: 16),
          _WizardActions(
            step: _step,
            initState: initState,
            onNext: _buildPlanAndConfirm,
            onBack: () => setState(() => _step = _WizardStep.form),
            onExecute: _execute,
            onDone: () {
              ref.read(initFlowProvider.notifier).reset();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _FormStep extends StatelessWidget {
  const _FormStep({
    required this.formKey,
    required this.appDisplayNameController,
    required this.packageIdBaseController,
    required this.flavorsController,
    required this.parsedFlavors,
    required this.productionFlavor,
    required this.useSuffix,
    required this.hasFlavorConfig,
    required this.hasDeployConfig,
    required this.createDeployConfig,
    required this.deployTemplateKind,
    required this.onProductionFlavorChanged,
    required this.onUseSuffixChanged,
    required this.onCreateDeployConfigChanged,
    required this.onDeployTemplateKindChanged,
    required this.onFlavorsEdited,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController appDisplayNameController;
  final TextEditingController packageIdBaseController;
  final TextEditingController flavorsController;
  final List<String> parsedFlavors;
  final String productionFlavor;
  final bool useSuffix;
  final bool hasFlavorConfig;
  final bool hasDeployConfig;
  final bool createDeployConfig;
  final String deployTemplateKind;
  final ValueChanged<String> onProductionFlavorChanged;
  final ValueChanged<bool> onUseSuffixChanged;
  final ValueChanged<bool> onCreateDeployConfigChanged;
  final ValueChanged<String> onDeployTemplateKindChanged;
  final VoidCallback onFlavorsEdited;

  @override
  Widget build(BuildContext context) {
    final packageIdPattern = RegExp(
      r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$',
    );

    return Form(
      key: formKey,
      child: ListView(
        shrinkWrap: true,
        children: [
          if (hasFlavorConfig)
            const Card(
              child: ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('.flow_flavor.json already exists'),
                subtitle: Text(
                  'Flavor setup will be skipped — nothing is overwritten.',
                ),
              ),
            )
          else ...[
            TextFormField(
              controller: appDisplayNameController,
              decoration: const InputDecoration(
                labelText: 'App display name',
                helperText: 'Shown under the launcher icon.',
              ),
              validator:
                  (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Required'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: packageIdBaseController,
              decoration: const InputDecoration(
                labelText: 'Package name / bundle id base',
                helperText:
                    'e.g. com.company.app — flavors get a suffix when enabled.',
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) return 'Required';
                if (!packageIdPattern.hasMatch(trimmed)) {
                  return 'Must look like com.company.app';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: flavorsController,
              decoration: const InputDecoration(
                labelText: 'Flavors (comma-separated)',
                helperText: 'e.g. dev, staging, production',
              ),
              onChanged: (_) => onFlavorsEdited(),
              validator: (_) {
                if (parsedFlavors.isEmpty) return 'At least one flavor.';
                if (parsedFlavors.toSet().length != parsedFlavors.length) {
                  return 'Duplicate flavor names.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(parsedFlavors.join(',')),
              initialValue:
                  parsedFlavors.contains(productionFlavor)
                      ? productionFlavor
                      : null,
              decoration: const InputDecoration(labelText: 'Production flavor'),
              items: [
                for (final flavor in parsedFlavors)
                  DropdownMenuItem(value: flavor, child: Text(flavor)),
              ],
              onChanged: (value) {
                if (value != null) onProductionFlavorChanged(value);
              },
              validator: (value) => value == null ? 'Pick one.' : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Unique id per flavor (suffix)'),
              subtitle: const Text(
                'com.company.app.dev, com.company.app.staging, … — production stays clean.',
              ),
              value: useSuffix,
              onChanged: onUseSuffixChanged,
            ),
          ],
          const Divider(height: 24),
          if (hasDeployConfig)
            const Card(
              child: ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('.flow_deploy.json already exists'),
                subtitle: Text(
                  'Deploy setup will be skipped — nothing is overwritten.',
                ),
              ),
            )
          else ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Create deploy config (.flow_deploy.json)'),
              subtitle: const Text(
                'Template with deploy profiles, ready to fill in.',
              ),
              value: createDeployConfig,
              onChanged: onCreateDeployConfigChanged,
            ),
            if (createDeployConfig)
              DropdownButtonFormField<String>(
                initialValue: deployTemplateKind,
                decoration: const InputDecoration(labelText: 'Deploy template'),
                items: const [
                  DropdownMenuItem(
                    value: 'both',
                    child: Text('Fastlane + Firebase'),
                  ),
                  DropdownMenuItem(
                    value: 'fastlane',
                    child: Text('Fastlane only'),
                  ),
                  DropdownMenuItem(
                    value: 'firebase',
                    child: Text('Firebase App Distribution only'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) onDeployTemplateKindChanged(value);
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({required this.plan});

  final InitFlowPlan plan;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        Text(
          'Review before writing any files:',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (plan.createFlavorConfig) ...[
          const _SummaryHeader(
            label: 'Flavor setup (.flow_flavor.json + project files)',
          ),
          _SummaryRow(label: 'App name', value: plan.appDisplayName),
          _SummaryRow(label: 'Package id base', value: plan.packageIdBase),
          _SummaryRow(label: 'Flavors', value: plan.flavors.join(', ')),
          _SummaryRow(label: 'Production flavor', value: plan.productionFlavor),
          _SummaryRow(
            label: 'Id per flavor',
            value: plan.useSuffix ? 'suffixed (recommended)' : 'shared id',
          ),
          _SummaryRow(
            label: 'Firebase',
            value: 'skipped — run "flow flavor firebase" later',
          ),
        ] else
          const _SummaryHeader(
            label: 'Flavor setup: skipped (config already exists)',
          ),
        const SizedBox(height: 8),
        if (plan.createDeployConfig) ...[
          const _SummaryHeader(label: 'Deploy setup (.flow_deploy.json)'),
          _SummaryRow(label: 'Template', value: plan.deployTemplateKind),
          const _SummaryRow(label: 'Profiles', value: 'generated (dev, …)'),
        ] else
          const _SummaryHeader(label: 'Deploy setup: skipped'),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'The flavor setup rewrites Android/iOS project files and main '
              'entrypoints using the same engine as "flow flavor init". '
              'Make sure the project is committed to git first.',
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _WizardActions extends StatelessWidget {
  const _WizardActions({
    required this.step,
    required this.initState,
    required this.onNext,
    required this.onBack,
    required this.onExecute,
    required this.onDone,
  });

  final _WizardStep step;
  final InitFlowState initState;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onExecute;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: switch (step) {
        _WizardStep.form => [
          AppButton(
            label: 'Review…',
            icon: Icon(Icons.arrow_forward, size: 16),
            widthMode: AppButtonWidthMode.hug,
            onPressed: onNext,
          ),
        ],
        _WizardStep.confirm => [
          AppButton(
            label: 'Back',
            style: AppButtonStyleType.text,
            widthMode: AppButtonWidthMode.hug,
            onPressed: onBack,
          ),
          const SizedBox(width: 8),
          AppButton(
            label: 'Initialize now',
            icon: Icon(Icons.auto_fix_high, size: 16),
            widthMode: AppButtonWidthMode.hug,
            onPressed: onExecute,
          ),
        ],
        _WizardStep.execute => [
          if (initState.status == InitFlowStatus.failed)
            AppButton(
              label: 'Back to form',
              style: AppButtonStyleType.text,
              widthMode: AppButtonWidthMode.hug,
              onPressed: onBack,
            ),
          const SizedBox(width: 8),
          AppButton(
            label: initState.isRunning ? 'Working…' : 'Done',
            widthMode: AppButtonWidthMode.hug,
            isLoading: initState.isRunning,
            isDisabled: initState.isRunning,
            onPressed: onDone,
          ),
        ],
      },
    );
  }
}
