part of flutter_base;

class PlatformUtil {
  PlatformUtil._();

  /// 是否是苹果平台：macos、ios
  static bool get isApple => GetPlatform.isMacOS || GetPlatform.isIOS;

  /// 是否是移动客户端平台
  static bool get isMobileClient => !kIsWeb && GetPlatform.isMobile;

  /// 是否是桌面客户端平台
  static bool get isDesktopClient => !kIsWeb && GetPlatform.isDesktop;
}
