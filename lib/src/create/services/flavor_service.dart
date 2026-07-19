import '../../flavor/models/flavor_config.dart';

/// Builds the minimal in-memory [FlavorConfig] needed to drive
/// `AndroidService.setupFlavors` / `IOSService.setupSchemes` — the exact
/// same services `flow flavor init` uses on an existing project — for
/// native artefact generation only: Gradle `productFlavors`, iOS
/// `.xcconfig` files, Xcode schemes, and per-flavor `project.pbxproj`
/// build configurations.
///
/// This config is deliberately never passed to `ConfigService.save` and
/// never written to `.flow_flavor.json` — `flow create` doesn't own a
/// flavor config file. `appConfigPath` and `flavorValues` here are never
/// read by either service (only `SetupRunner`/`FileService` act on those,
/// and `flow create` never calls them), so no Dart config file or
/// entrypoint is generated — the starter template's own `Env` +
/// `--dart-define-from-file` design and its `lib/main_<flavor>.dart`
/// entrypoints are left untouched. `useSeparateMains: true` only tells
/// `IOSService` to point each xcconfig's `FLUTTER_TARGET` at
/// `lib/main_<flavor>.dart`, matching what the template already ships.
///
/// The same [bundleId] and production-flavor rule feed both `android` and
/// `ios`, so Android's `applicationIdSuffix` and iOS's per-flavor bundle id
/// can never disagree.
FlavorConfig buildNativeFlavorConfig({
  required List<String> flavors,
  required String appName,
  required String bundleId,
}) {
  return FlavorConfig(
    flavors: flavors,
    appName: appName,
    fields: const {},
    flavorValues: const {},
    appConfigPath: 'lib/core/config/app_config.dart',
    useSeparateMains: true,
    useSuffix: true,
    android: AndroidConfig(applicationId: bundleId),
    ios: IosConfig(bundleId: bundleId),
    // A flavor named exactly "production" is the unsuffixed one, on both
    // platforms — mirrors the convention the old hand-rolled Gradle-block
    // writer used. If none is named "production", every flavor is suffixed.
    productionFlavor: flavors.contains('production') ? 'production' : '',
  );
}
