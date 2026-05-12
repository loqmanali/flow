/// Single source of truth for the sidebar navigation.
///
/// Every entry maps to a markdown asset under `assets/docs/...` and a route
/// segment used by `go_router`.
class DocSection {
  const DocSection({required this.title, required this.entries});
  final String title;
  final List<DocEntry> entries;
}

class DocEntry {
  const DocEntry({required this.title, required this.path, required this.asset});

  /// Display label in the sidebar.
  final String title;

  /// Route path used by go_router (e.g. `/flavor/init`).
  final String path;

  /// Asset path under `assets/docs/` that holds the page's markdown.
  final String asset;
}

const List<DocSection> kNav = [
  DocSection(
    title: 'Getting started',
    entries: [
      DocEntry(title: 'Introduction', path: '/', asset: 'assets/docs/introduction.md'),
      DocEntry(title: 'Installation', path: '/installation', asset: 'assets/docs/installation.md'),
      DocEntry(title: 'Quick start', path: '/quick-start', asset: 'assets/docs/quick-start.md'),
    ],
  ),
  DocSection(
    title: 'Configuration',
    entries: [
      DocEntry(
        title: '.flow_flavor.json',
        path: '/config/flavor',
        asset: 'assets/docs/config/flavor.md',
      ),
      DocEntry(
        title: '.flow_deploy.json',
        path: '/config/deploy',
        asset: 'assets/docs/config/deploy.md',
      ),
      DocEntry(
        title: 'Where to get values',
        path: '/config/where-to-get-values',
        asset: 'assets/docs/config/where-to-get-values.md',
      ),
    ],
  ),
  DocSection(
    title: 'flow flavor',
    entries: [
      DocEntry(title: 'Overview', path: '/flavor', asset: 'assets/docs/flavor/overview.md'),
      DocEntry(title: 'init', path: '/flavor/init', asset: 'assets/docs/flavor/init.md'),
      DocEntry(title: 'add', path: '/flavor/add', asset: 'assets/docs/flavor/add.md'),
      DocEntry(title: 'delete', path: '/flavor/delete', asset: 'assets/docs/flavor/delete.md'),
      DocEntry(title: 'replace', path: '/flavor/replace', asset: 'assets/docs/flavor/replace.md'),
      DocEntry(title: 'reset', path: '/flavor/reset', asset: 'assets/docs/flavor/reset.md'),
      DocEntry(title: 'run', path: '/flavor/run', asset: 'assets/docs/flavor/run.md'),
      DocEntry(title: 'build', path: '/flavor/build', asset: 'assets/docs/flavor/build.md'),
      DocEntry(
        title: 'firebase',
        path: '/flavor/firebase',
        asset: 'assets/docs/flavor/firebase.md',
      ),
      DocEntry(title: 'migrate', path: '/flavor/migrate', asset: 'assets/docs/flavor/migrate.md'),
    ],
  ),
  DocSection(
    title: 'flow deploy',
    entries: [
      DocEntry(title: 'Overview', path: '/deploy', asset: 'assets/docs/deploy/overview.md'),
      DocEntry(title: 'init', path: '/deploy/init', asset: 'assets/docs/deploy/init.md'),
      DocEntry(title: 'beta', path: '/deploy/beta', asset: 'assets/docs/deploy/beta.md'),
      DocEntry(title: 'update', path: '/deploy/update', asset: 'assets/docs/deploy/update.md'),
      DocEntry(title: 'version', path: '/deploy/version', asset: 'assets/docs/deploy/version.md'),
      DocEntry(title: 'run', path: '/deploy/run', asset: 'assets/docs/deploy/run.md'),
    ],
  ),
  DocSection(
    title: 'Workflows',
    entries: [
      DocEntry(
        title: 'First-time setup',
        path: '/workflows/first-time-setup',
        asset: 'assets/docs/workflows/first-time-setup.md',
      ),
      DocEntry(
        title: 'TestFlight beta',
        path: '/workflows/testflight-beta',
        asset: 'assets/docs/workflows/testflight-beta.md',
      ),
      DocEntry(
        title: 'Mixed provider',
        path: '/workflows/mixed-provider',
        asset: 'assets/docs/workflows/mixed-provider.md',
      ),
      DocEntry(
        title: 'Version bumping',
        path: '/workflows/version-bumping',
        asset: 'assets/docs/workflows/version-bumping.md',
      ),
    ],
  ),
  DocSection(
    title: 'Reference',
    entries: [
      DocEntry(
        title: 'Troubleshooting',
        path: '/troubleshooting',
        asset: 'assets/docs/troubleshooting.md',
      ),
    ],
  ),
];

/// Flat list of all entries — handy for routing and prev/next navigation.
List<DocEntry> get kAllEntries =>
    [for (final section in kNav) ...section.entries];

DocEntry? entryForPath(String path) {
  for (final e in kAllEntries) {
    if (e.path == path) return e;
  }
  return null;
}
