import 'package:flutter/widgets.dart';

import '../../views/view/style/style.dart';
import '../../views/view/event/event.dart';
import '../../widgets/popup/anchor.dart';
import '../index.dart';

/// 悬停、点击或长按触发的锚定提示，内容可包含可交互 Widget。
class ElTooltip extends StatelessWidget {
  /// 提示复用 ElPortal 的定位、外点关闭和主题作用域。
  const ElTooltip({
    super.key,
    required this.content,
    required this.child,
    this.placement = .top,
    this.waitDuration = const Duration(milliseconds: 400),
    this.showDuration = const Duration(seconds: 3),
    this.disabled = false,
    this.arrow = true,
    this.style,
    this.event,
  });

  /// 提示文字或内容。
  final Object content;

  /// 触发目标。
  final Widget child;

  /// 提示相对目标的方向。
  final ElPlacement placement;

  /// 指针悬停多久后显示。
  final Duration waitDuration;

  /// 点击或长按显示后的自动关闭时间。
  final Duration showDuration;

  /// 禁止显示提示。
  final bool disabled;

  /// 是否显示指向目标的箭头。
  final bool arrow;

  /// 提示面板的样式。
  final ElStyle? style;

  /// 触发目标的原生事件。
  final ElEvent? event;
  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.tooltip)(context, this);
}
