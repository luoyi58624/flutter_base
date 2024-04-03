part of flutter_base;

/// 获取设备信息工具类
class DeviceUtil {
  late final DeviceInfoPlugin plugin;

  static final DeviceUtil _instance = DeviceUtil._();

  factory DeviceUtil() => _instance;

  DeviceUtil._() {
    plugin = DeviceInfoPlugin();
  }

  /// 获取平台包信息
  /// * appName      app名字
  /// * packageName  包名
  /// * version      版本名字
  /// * buildNumber  版本号
  static Future<PackageInfo> getPackageInfo() async => PackageInfo.fromPlatform();

  /// 获取设备生产商：Huawei、XiaoMi、Apple
  static Future<String?> getManufacturer() async {
    if (GetPlatform.isAndroid) {
      return (await DeviceUtil().plugin.androidInfo).manufacturer;
    } else if (GetPlatform.isIOS) {
      return (await DeviceUtil().plugin.iosInfo).name;
    } else {
      return null;
    }
  }
}
