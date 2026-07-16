import 'dart:io';

class Constants {
  Constants._();
  // Live getter (not a captured final): embedders like flow_studio point
  // the engine at a project by setting [Directory.current]; the CLI's cwd
  // never changes mid-run, so CLI behavior is identical.
  static String get _projectDir => Directory.current.path;

  static String get projectDir => _projectDir;

  //.gitignore
  static String get gitignorePath => '$_projectDir/.gitignore';
  static String get buildIosIpaDirPath => '$_projectDir/build/ios/ipa';
  static String get buildAndroidApkPath =>
      '$_projectDir/build/app/outputs/flutter-apk/app-release.apk';

  // Directories
  static String get iosDirPath => '$_projectDir/ios';
  static String get androidDirPath => '$_projectDir/android';

  // Fastlane directories
  static String get iosFastlaneDirPath => '$iosDirPath/fastlane';
  static String get androidFastlaneDirPath => '$androidDirPath/fastlane';

  static String get androidFastlaneMetadataDirPath => '$androidFastlaneDirPath/metadata';

  // Fastfile
  static String get androidFastfilePath => '$androidFastlaneDirPath/Fastfile';
  static String get iosFastfilePath => '$iosFastlaneDirPath/Fastfile';

  // Deliverfile
  static String get iosDeliverfilePath => '$iosFastlaneDirPath/Deliverfile';
  static String get androidDeliverfilePath => '$androidFastlaneDirPath/Deliverfile';

  // Deploy config
  static String get deployConfigFilePath => '$_projectDir/.flow_deploy.json';
}
