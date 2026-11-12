import 'package:flutter/widgets.dart';

import '../../views/view/style/style.dart';
import '../../views/view/event/event.dart';
import '../index.dart';

/// 页面标题、返回入口和操作区的通用声明。
class ElAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// 标题居中时按两侧较宽区域对称留白。
  const ElAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.centerTitle = true,
    this.back = false,
    this.onBack,
    this.style,
    this.event,
  });

  /// 标题内容。
  final Object title;

  /// 次要标题。
  final Object? subtitle;

  /// 自定义起边内容。
  final Widget? leading;

  /// 末端操作。
  final List<Widget> actions;

  /// 标题是否居中。
  final bool centerTitle;

  /// 未指定 leading 时显示返回按钮。
  final bool back;

  /// 返回动作，省略时弹出最近导航路由。
  final VoidCallback? onBack;

  /// 覆盖品牌样式。
  final ElStyle? style;

  /// 标题栏根节点事件。
  final ElEvent? event;
  @override
  Size get preferredSize => Size.fromHeight(style?.height is num ? (style!.height as num).toDouble() : 64);
  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.appBar)(context, this);
}
