import 'package:PiliPlus/build_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Version metadata reported by the installed application package.
///
/// Package metadata is authoritative for user-visible version checks. Dart
/// defines remain fallbacks for platforms whose package build number is not a
/// decimal integer and for build diagnostics such as commit hash and time.
class AppVersion {
  const AppVersion({required this.name, required this.code});

  final String name;
  final int code;

  String get display => '$name+$code';

  static Future<AppVersion> load() async {
    final info = await PackageInfo.fromPlatform();
    return fromPackageValues(
      version: info.version,
      buildNumber: info.buildNumber,
    );
  }

  static AppVersion fromPackageValues({
    required String version,
    required String buildNumber,
  }) {
    return AppVersion(
      name: version.isEmpty ? BuildConfig.versionName : version,
      code: int.tryParse(buildNumber) ?? BuildConfig.versionCode,
    );
  }
}
