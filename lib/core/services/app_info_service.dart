
import 'package:package_info_plus/package_info_plus.dart';

class AppInfoService {
  AppInfoService._privateConstructor();

  static final AppInfoService instance = AppInfoService._privateConstructor();

  late String appName;
  late String packageName;
  late String version;
  late String buildNumber;

  Future<void> init() async {
    final info = await PackageInfo.fromPlatform();

    appName = info.appName;
    packageName = info.packageName;
    version = info.version;
    buildNumber = info.buildNumber;
  }

  String get fullVersion => "$version+$buildNumber";
}