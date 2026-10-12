import 'package:web/web.dart' as web;

String _userAgent = web.window.navigator.userAgent;

class GeneralPlatform {
  static final bool isMacOS = _userAgent.contains('Mac OS') && !isIOS;

  /// 'Windows' 而非 'Win'：避免 UA 中任意 Win 子串（如 Windows Phone 之外的
  /// 品牌词）误命中。
  static final bool isWindows = _userAgent.contains('Windows');

  /// 真实 UA 是大写 'X11'（Firefox/ChromeOS）；'CrOS' 兜住 ChromeOS
  /// （其 UA 不含 'Linux'，漏判会跌成 mobile）。
  static final bool isLinux =
      (_userAgent.contains('Linux') ||
          _userAgent.contains('X11') ||
          _userAgent.contains('CrOS')) &&
      !isAndroid;

  static final bool isAndroid = _userAgent.contains('Android');

  /// iPadOS 13+ Safari 默认请求桌面版站点，UA 伪装成 Macintosh 且无 iPad
  /// token，靠多点触控识别回 iOS（真 Mac 的 maxTouchPoints 为 0）。
  static final bool isIOS =
      RegExp(r'(iPad|iPhone|iPod)').hasMatch(_userAgent) ||
      (_userAgent.contains('Mac') && web.window.navigator.maxTouchPoints > 1);

  static const bool isFuchsia = false;

  static final bool isDesktop = isMacOS || isWindows || isLinux;

  static final bool isApple = isMacOS || isIOS;

  static final bool isMobileWeb = isIOS || isAndroid || isFuchsia;

  static final bool isDesktopWeb = isMacOS || isWindows || isLinux;

  static const bool isMobileClient = false;

  static const bool isDesktopClient = false;

  static const bool isFlutterTest = false;
}
