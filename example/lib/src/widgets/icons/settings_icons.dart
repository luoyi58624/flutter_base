import 'package:flutter/widgets.dart';

part 'settings_icon.dart';

/// 从 my_ui 设置页提取的原版图标，条目名与原设置数据 id 一致。
enum ElSettingIcons {
  /// 飞行模式。
  airplane('飞行模式', Color(0xffffb600), ["m22 2-7 20-4-9-9-4Z", "M22 2 11 13"]),

  /// WLAN。
  wifi('WLAN', Color(0xff13b82c), [
    "M2 8.8a16 16 0 0 1 20 0",
    "M5 12a11 11 0 0 1 14 0",
    "M8.5 15.5a5.5 5.5 0 0 1 7 0",
    "M12 19h.01",
  ]),

  /// 蓝牙。
  bluetooth('蓝牙', Color(0xff13b82c), ["m7 7 10 10-5 5V2l5 5L7 17"]),

  /// 移动网络。
  mobile('移动网络', Color(0xff4144f2), ["M7 2h10v20H7Z", "M11 18h2"]),

  /// 设备互联。
  connect('设备互联', Color(0xff7778ef), [
    "M4 5h10v14H4Z",
    "M17 9h4v12h-4Z",
    "M7 2h4",
  ]),

  /// 桌面、锁屏与个性化。
  personalize('桌面、锁屏与个性化', Color(0xffff7247), [
    "M12 3a9 9 0 0 0 0 18h1a2 2 0 0 0 1-4 2 2 0 0 1 1-4h2a4 4 0 0 0 4-4 8 8 0 0 0-9-6Z",
    "M7 9h.01M10 6h.01M15 6h.01",
  ]),

  /// 显示与亮度。
  display('显示与亮度', Color(0xffffb600), [
    "M12 8a4 4 0 1 1 0 8 4 4 0 0 1 0-8",
    "M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.5 1.5m11 11L19 19M5 19l1.5-1.5m11-11L19 5",
  ]),

  /// 声音与振动。
  sound('声音与振动', Color(0xff4144f2), [
    "m11 3-6 5H2v8h3l6 5Z",
    "M15 8a6 6 0 0 1 0 8m3-11a10 10 0 0 1 0 14",
  ]),

  /// 通知与控制中心。
  notifications('通知与控制中心', Color(0xff13b82c), [
    "M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9",
    "M10 21h4",
  ]),

  /// 指纹、面部与密码。
  password('指纹、面部与密码', Color(0xff13b82c), [
    "M5 10h14v12H5Z",
    "M8 10V6a4 4 0 0 1 8 0v4",
  ]),

  /// 隐私与安全。
  privacy('隐私与安全', Color(0xff13b82c), [
    "m12 2 9 4v6c0 5-9 10-9 10S3 17 3 12V6Z",
    "m8 12 3 3 5-6",
  ]),

  /// 位置信息。
  location('位置信息', Color(0xff4144f2), [
    "M20 10c0 6-8 12-8 12S4 16 4 10a8 8 0 0 1 16 0Z",
    "M12 7a3 3 0 1 1 0 6 3 3 0 0 1 0-6",
  ]),

  /// 应用。
  apps('应用', Color(0xff4144f2), [
    "M3 3h7v7H3ZM14 3h7v7h-7ZM3 14h7v7H3ZM14 14h7v7h-7Z",
  ]),

  /// 电池。
  battery('电池', Color(0xff4144f2), [
    "M2 6h17v12H2Z",
    "M22 10v4M6 10v4M10 10v4M14 10v4",
  ]),

  /// 辅助功能。
  accessibility('辅助功能', Color(0xffff7247), [
    "M12 2a2 2 0 1 1 0 4 2 2 0 0 1 0-4",
    "M3 8l9 3 9-3M12 11v5m0 0-5 6m5-6 5 6",
  ]),

  /// 云服务。
  cloud('云服务', Color(0xff13b82c), [
    "M6 18a5 5 0 1 1 0-10 7 7 0 0 1 13 1 4.5 4.5 0 0 1-1 9Z",
  ]),

  /// 系统与更新。
  system('系统与更新', Color(0xff4144f2), [
    "M20 7a9 9 0 1 0 1 9",
    "M20 2v5h-5M12 7v5l3 2",
  ]),

  /// 关于本机。
  about('关于本机', Color(0xff4144f2), ["M7 2h10v20H7Z", "M11 18h2"]),

  /// 账号与备份。
  account('账号与备份', Color(0xff13b82c), [
    "M20 21v-2a7 7 0 0 0-14 0v2",
    "M16 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0",
  ]),

  /// 帮助与反馈。
  help('帮助与反馈', Color(0xffff7247), [
    "M12 2a10 10 0 1 1 0 20 10 10 0 0 1 0-20",
    "M9 8a3 3 0 1 1 4 3c-1 1-1 1-1 3M12 18h.01",
  ]),

  /// 搜索，使用设置页实际调用的共享图标。
  search(
    '搜索',
    Color(0xff626874),
    ["m16 16 5 5"],
    20,
    1.8,
    [Rect.fromLTWH(3.8, 3.8, 14, 14)],
  ),

  /// 头像，使用设置页实际调用的共享图标。
  user(
    '头像',
    Color(0xff626874),
    ["M4.5 21a7.5 7.5 0 0 1 15 0"],
    32,
    1.8,
    [Rect.fromLTWH(8, 4, 8, 8)],
  ),

  /// 右箭头，使用设置页实际调用的共享图标。
  chevronRight('右箭头', Color(0xff626874), ["m9 5 7 7-7 7"], 16, 1.8);

  const ElSettingIcons(
    this.label,
    this.color,
    this._sources, [
    this.size = 24,
    this.strokeWidth = 2.2,
    this._circles = const [],
  ]);

  /// 原设置页中的图标用途。
  final String label;

  /// 原设置页使用的默认颜色。
  final Color color;

  /// 原设置页使用的默认边长。
  final double size;

  /// 原设置页使用的描边宽度，坐标基准为 24。
  final double strokeWidth;

  final List<String> _sources;
  final List<Rect> _circles;
}
