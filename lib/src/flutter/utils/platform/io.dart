import 'dart:io';

class GeneralPlatform {
  static final bool isMacOS = Platform.isMacOS;

  static final bool isWindows = Platform.isWindows;

  static final bool isLinux = Platform.isLinux;

  static final bool isAndroid = Platform.isAndroid;

  static final bool isIOS = Platform.isIOS;

  static final bool isFuchsia = Platform.isFuchsia;

  static final bool isDesktop =
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  static final bool isApple = isMacOS || isIOS;

  static const bool isMobileWeb = false;

  static const bool isDesktopWeb = false;

  static final bool isMobileClient = isIOS || isAndroid || isFuchsia;

  static final bool isDesktopClient = isMacOS || isWindows || isLinux;

  /// flutter test 运行环境（工具链注入的 FLUTTER_TEST 环境变量，非 dart-define）。
  static final bool isFlutterTest = Platform.environment.containsKey(
    'FLUTTER_TEST',
  );
}
