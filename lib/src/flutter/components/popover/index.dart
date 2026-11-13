import 'package:flutter/widgets.dart';

import '../../views/view/event/event.dart';
import '../../views/view/style/style.dart';
import '../../widgets/popup/anchor.dart';
import '../../widgets/popup/hover_intent.dart';
import '../../widgets/popup/popup.dart';
import '../index.dart';

/// 在目标周围弹出的卡片，内容可包含任意可交互 Widget；外观与进退场由品牌实现。
class ElPopover extends StatelessWidget {
  /// 默认点击目标切换，trigger 可组合悬停、焦点与右键。
  const ElPopover({
    super.key,
    required this.child,
    required this.content,
    this.title,
    this.trigger = const {ElPopupTrigger.click},
    this.placement = .bottom,
    this.width,
    this.showArrow = true,
    this.hoverIntent = const ElHoverIntent(),
    this.disabled = false,
    this.controller,
    this.onOpenChanged,
    this.style,
    this.event,
  });

  /// 触发目标。
  final Widget child;

  /// 卡片正文，接受文字或 Widget。
  final Object content;

  /// 可选标题。
  final Object? title;

  /// 触发方式。
  final Set<ElPopupTrigger> trigger;

  /// 卡片相对目标的首选方位，空间不足时自动翻转。
  final ElPlacement placement;

  /// 卡片宽度，省略时按内容与品牌最小宽度。
  final double? width;

  /// 显示指向目标的箭头。
  final bool showArrow;

  /// 悬停触发的打开、关闭延迟。
  final ElHoverIntent hoverIntent;

  /// 禁用全部触发，已打开时关闭。
  final bool disabled;

  /// 可选开闭控制器。
  final ElPopupController? controller;

  /// 开闭状态变化。
  final ValueChanged<bool>? onOpenChanged;

  /// 在品牌卡片样式后合并。
  final ElStyle? style;

  /// 目标的原生事件，preventDefault 可阻止打开或关闭。
  final ElEvent? event;

  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.popover)(context, this);
}
