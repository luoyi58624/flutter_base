import 'web.dart' if (dart.library.io) 'io.dart';

/// 统一读取原生与 Web 平台的运行环境。
class ElPlatform {
  ElPlatform._();

  /// macos、macos web
  static final bool isMacOS = GeneralPlatform.isMacOS;

  /// windows、windows web
  static final bool isWindows = GeneralPlatform.isWindows;

  /// linux、linux web
  static final bool isLinux = GeneralPlatform.isLinux;

  /// android、android web
  static final bool isAndroid = GeneralPlatform.isAndroid;

  /// ios、ios web、ipad
  static final bool isIOS = GeneralPlatform.isIOS;

  /// fuchsia、fuchsia web
  static final bool isFuchsia = GeneralPlatform.isFuchsia;

  /// mobile、mobile web
  static final bool isMobile = !isDesktop;

  /// desktop、desktop web（macos/windows/linux 及对应桌面浏览器）
  static final bool isDesktop = isMacOS || isWindows || isLinux;

  /// ios、ios web、macos、macos web
  static final bool isApple = GeneralPlatform.isApple;

  /// only mobile web
  static final bool isMobileWeb = GeneralPlatform.isMobileWeb;

  /// only desktop web
  static final bool isDesktopWeb = GeneralPlatform.isDesktopWeb;

  /// only mobile client
  static final bool isMobileClient = GeneralPlatform.isMobileClient;

  /// only desktop client
  static final bool isDesktopClient = GeneralPlatform.isDesktopClient;

  /// flutter test 运行环境（FLUTTER_TEST 环境变量，web 恒 false）
  static final bool isFlutterTest = GeneralPlatform.isFlutterTest;
}
