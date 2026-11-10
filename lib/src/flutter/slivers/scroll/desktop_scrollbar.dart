import 'package:flutter/widgets.dart';

import 'scrollbar/mac_scroll_bar.dart' show ElMacScrollBar;
import 'scrollbar/window_scroll_bar.dart' show ElWindowScrollBar;
import 'scrollbar.dart' show buildElDesktopScrollbar;

/// 在官方 Scrollable 外安装桌面滚动条的交互与平台外观。
///
/// 轨道按下即跳转到对应位置并可继续拖动，滑块按下立即接管滚动；
/// Windows 使用常驻轨道、步进按钮和布局占位，macOS 使用悬浮、自动隐藏条带。
/// 滚动位置来自官方 ScrollController，不依赖旧 ElScrollView 的视口实现。
class ElDesktopScrollbar extends StatelessWidget {
  /// 创建 Windows 风格的桌面滚动条。
  const ElDesktopScrollbar.windows({super.key, required this.controller, required this.direction, required this.child})
    : _style = _ScrollbarStyle.windows;

  /// 创建 macOS 风格的桌面滚动条。
  const ElDesktopScrollbar.mac({super.key, required this.controller, required this.direction, required this.child})
    : _style = _ScrollbarStyle.mac;

  /// 关联当前 Scrollable 的真实滚动位置。
  final ScrollController controller;

  /// 当前滚动轴方向。
  final AxisDirection direction;

  /// 被滚动条包裹的 Scrollable。
  final Widget child;

  final _ScrollbarStyle _style;

  @override
  Widget build(BuildContext context) => buildElDesktopScrollbar(
    controller: controller,
    direction: direction,
    child: child,
    scrollbar: switch (_style) {
      _ScrollbarStyle.windows => const ElWindowScrollBar(),
      _ScrollbarStyle.mac => const ElMacScrollBar(),
    },
  );
}

enum _ScrollbarStyle { windows, mac }
