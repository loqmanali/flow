import 'dart:convert';
import 'dart:io';

import 'constants.dart';

class DeployConfig {
  //Singleton
  static DeployConfig? _instance;
  static DeployConfig get instance => _instance ??= DeployConfig._();
  DeployConfig._();

  late Map<String, dynamic> _config;

  Map<String, dynamic>? get build => _config['build'] as Map<String, dynamic>?;

  bool get skipVersionIncrement => _config['skip_version_increment'] as bool? ?? true;

  String get buildFlavor => _optionalString(build?['flavor']) ?? '';

  String get buildTarget => _optionalString(build?['target']) ?? '';

  /// Explicit path to the `--dart-define-from-file` config passed to every
  /// build (for example `.env` or `.env.production`).
  ///
  /// Takes precedence over the `.env.<flavor>` convention, which only fits
  /// projects that happen to name env files after their flavors. Empty means
  /// "fall back to the convention".
  String get dartDefineFromFile => _optionalString(build?['dart_define_from_file']) ?? '';

  Map<String, dynamic> get profiles {
    return _config['profiles'] as Map<String, dynamic>? ?? {};
  }

  Map<String, dynamic>? profile(String name) {
    return profiles[name] as Map<String, dynamic>?;
  }

  List<String> get profileNames {
    final names = profiles.keys.toList();
    names.sort();
    return names;
  }

  Map<String, dynamic> get ios {
    final ios = _config['ios'] as Map<String, dynamic>?;
    if (ios == null) {
      throw Exception('Missing ios in .flow_deploy.json');
    }
    return ios;
  }

  Map<String, dynamic> get appStoreConfig {
    final appStoreConfig = ios['app_store_connect'] as Map<String, dynamic>?;
    if (appStoreConfig == null) {
      throw Exception('Missing ios.app_store_connect in .flow_deploy.json');
    }
    return appStoreConfig;
  }

  Map<String, dynamic>? get testflightConfig {
    return ios['testflight'] as Map<String, dynamic>?;
  }

  Map<String, dynamic>? get iosFirebaseConfig {
    return ios['firebase_app_distribution'] as Map<String, dynamic>?;
  }

  String? get iosAppIdentifier {
    return _optionalString(ios['app_identifier']);
  }

  Map<String, dynamic> get android {
    final android = _config['android'] as Map<String, dynamic>?;
    if (android == null) {
      throw Exception('Missing android in .flow_deploy.json');
    }
    return android;
  }

  Map<String, dynamic>? get androidFirebaseConfig {
    return android['firebase_app_distribution'] as Map<String, dynamic>?;
  }

  String? get androidPackageName {
    return _optionalString(android['package_name']);
  }

  Future<void> load() async {
    try {
      final configFile = File(Constants.deployConfigFilePath);
      if (!configFile.existsSync()) {
        throw Exception('.flow_deploy.json not found in the project root');
      }
      final configContent = await configFile.readAsString();
      _config = jsonDecode(configContent) as Map<String, dynamic>;
    } on Exception {
      rethrow;
    }
  }

  String? _optionalString(dynamic value) {
    final stringValue = value?.toString().trim();
    if (stringValue == null || stringValue.isEmpty) {
      return null;
    }
    return stringValue;
  }
}
