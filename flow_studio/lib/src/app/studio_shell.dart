import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/deploy_screen.dart';
import '../screens/flavors_screen.dart';
import '../screens/project_picker_screen.dart';
import '../state/flow_project_state.dart';

/// App frame: sidebar navigation + the active screen.
class StudioShell extends ConsumerStatefulWidget {
  const StudioShell({super.key});

  @override
  ConsumerState<StudioShell> createState() => _StudioShellState();
}

class _StudioShellState extends ConsumerState<StudioShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(flowProjectProvider);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected:
                (index) => setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.waves, size: 32),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.folder_open_outlined),
                selectedIcon: Icon(Icons.folder_open),
                label: Text('Project'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.rocket_launch_outlined),
                selectedIcon: Icon(Icons.rocket_launch),
                label: Text('Deploy'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.style_outlined),
                selectedIcon: Icon(Icons.style),
                label: Text('Flavors'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                const ProjectPickerScreen(),
                DeployScreen(project: project),
                FlavorsScreen(project: project),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
