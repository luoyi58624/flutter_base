import 'package:flutter/cupertino.dart';
import 'package:flutter_base/flutter_base.dart';

/// 为官方与回收列表接入可直接拖拽的 iOS 风格滚动条。
class RecyclerExampleScrollbar extends StatelessWidget {
  /// 使用列表自身的控制器关联真实滚动位置。
  // ignore: prefer_const_constructors_in_immutables
  RecyclerExampleScrollbar({super.key, required this.controller, required this.child});

  /// 与当前列表共用且仅连接一个位置的控制器。
  final ScrollController controller;

  /// 当前选择的列表容器。
  final Widget child;

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    // 平台自动滚动条与显式 CupertinoScrollbar 只能保留一份。
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: CupertinoScrollbar(controller: controller, thumbVisibility: true, child: child),
  );
}

/// 为 ElScrollView 对比列表保持同样常显、可拖拽的 iOS 风格滚动条。
class RecyclerExampleIosScrollbar extends ElIosScrollBar {
  @override
  bool resolveAlwaysVisible(BuildContext context, ElScrollbarAxisDetails axis) => true;
}
