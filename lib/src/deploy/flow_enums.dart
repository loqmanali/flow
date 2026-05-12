enum DeployPlatform { all, android, ios }

enum DeployMode { none, beta, update }

enum DeployProvider { fastlane, firebase, mixed }

extension DeployModeExtension on String {
  DeployMode toDeployMode() {
    switch (this) {
      case 'beta':
        return DeployMode.beta;
      case 'update':
        return DeployMode.update;
      default:
        return DeployMode.none;
    }
  }
}

extension DeployPlatformExtension on String {
  DeployPlatform toDeployPlatform() {
    switch (this) {
      case 'android':
        return DeployPlatform.android;
      case 'ios':
        return DeployPlatform.ios;
      case 'all':
        return DeployPlatform.all;
      default:
        throw Exception(
          'Invalid platform "$this". Must be one of: all, ios, android.',
        );
    }
  }
}

extension DeployProviderExtension on String {
  DeployProvider toDeployProvider() {
    switch (this) {
      case 'firebase':
        return DeployProvider.firebase;
      case 'mixed':
        return DeployProvider.mixed;
      case 'fastlane':
      default:
        return DeployProvider.fastlane;
    }
  }
}
