import 'package:flutter/widgets.dart';

import '../scaffold/index.dart';

/// 可接入脚手架导航槽的侧栏组件协议。
abstract interface class ElSidebar implements Widget {
  /// 展开态逻辑宽度。
  double? get width;

  /// 是否延伸至视口顶部。
  bool get expandTop;

  /// 是否始终使用抽屉形态。
  bool get drawer;

  /// 抽屉关闭后是否保留内容状态。
  bool get keepAlive;
}

/// 脚手架向侧栏提供的只读状态数据。
final class ElSidebarState {
  /// 创建侧栏状态快照，不注册上下文。
  const ElSidebarState({
    required this.collapsed,
    required this.drawer,
    required this.controller,
  });

  /// 当前桌面侧栏是否折叠。
  final bool collapsed;

  /// 当前是否处于抽屉形态。
  final bool drawer;

  /// 所属脚手架的命令接口。
  final ElScaffoldController controller;
}
