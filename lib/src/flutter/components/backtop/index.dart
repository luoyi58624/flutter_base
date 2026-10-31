import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// Element Plus 回到顶部。
///
/// 需要与滚动视图放进同一个 [Stack]（本组件自带 [Positioned] 定位），
/// 并把该视图的 [ScrollController] 传进来：
/// ```dart
/// Stack(children: [ElScrollView(controller: c, children: [...]), ElBacktop(controller: c)])
/// ```
class ElBacktop extends StatelessWidget {
  /// 创建组件参数声明。
  const ElBacktop({
    super.key,
    required this.controller,
    this.visibilityHeight = 200,
    this.right = 40,
    this.bottom = 40,
    this.duration = const Duration(milliseconds: 300),
    this.onTap,
    this.child,
    this.style,
    this.semanticLabel,
  });

  /// 被监听与被滚动的控制器
  final ScrollController controller;

  /// 滚动超过该高度才出现
  final double visibilityHeight;

  /// 右侧定位距离。
  final double right;

  /// 底部定位距离。
  final double bottom;

  /// 回到顶部的动画时长
  final Duration duration;

  /// 额外回调；不影响内置的回到顶部行为
  final VoidCallback? onTap;

  /// 自定义内容，缺省是官方向上箭头
  final Object? child;

  /// style 层的样式覆写。
  final ElStyle? style;

  /// 辅助技术读取的组件名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).backtopBuilder!(context, this);
}
