import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 卡片内容、区域名称和可选整卡操作的公共声明。
class ElCard extends StatelessWidget {
  /// 创建卡片配置，布局、加载展示和交互由品牌实现提供。
  const ElCard({
    super.key,
    this.child,
    this.title,
    this.description,
    this.sample,
    this.loading = false,
    this.interactive = false,
    this.delayTouchDown = Duration.zero,
    this.delayTouchUp = const Duration(milliseconds: 100),
    this.onActivate,
    this.focusNode,
    this.style,
    this.semanticLabel,
  });

  /// 卡片正文，接受文本、图标或 Widget。
  final Object? child;

  /// 可选标题，交互卡片可将其作为辅助名称。
  final String? title;

  /// 标题下方的说明文字。
  final String? description;

  /// 可选示例或附加编号。
  final String? sample;

  /// 是否展示卡片加载状态。
  final bool loading;

  /// 是否将整卡声明为可激活区域。
  final bool interactive;

  /// 触摸按下反馈的等待时间。
  final Duration delayTouchDown;

  /// 触摸按下反馈的最短保留时间。
  final Duration delayTouchUp;

  /// 整卡激活时的通知。
  final ElEventHandler? onActivate;

  /// 外部焦点节点，生命周期由调用方管理。
  final FocusNode? focusNode;

  /// 在品牌默认样式之后合并的样式。
  final ElStyle? style;

  /// 卡片区域的辅助名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).cardBuilder!(context, this);
}
