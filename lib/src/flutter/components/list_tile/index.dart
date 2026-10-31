import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/ui.dart';

part 'group.dart';

/// 根据最近事件状态显示按压与悬停反馈的列表条目。
class MyListTile extends StatelessWidget {
  /// 创建列表条目。
  const MyListTile({super.key, required this.title, this.icon, this.onPressed});

  /// 条目标题。
  final String title;

  /// 标题前的可选图标。
  final Widget? icon;

  /// 点击条目时执行。
  final VoidCallback? onPressed;

  /// 图标区域的逻辑宽度。
  double get iconWidth => 56;

  @override
  Widget build(BuildContext context) {
    final isEnd = ElChildIndex.of(context).isEnd;
    Widget result = ElView(
      event: ElEvent(
        onTap: (e) => onPressed?.call(),
        config: ElEventConfig(delayTouchDown: Duration.zero, delayTouchUp: Duration(milliseconds: 100)),
      ),
      style: .new(
        padding: .symmetric(vertical: 16),
        onHover: .new(backgroundColor: Colors.grey.shade100),
        onTap: .new(backgroundColor: Colors.grey.shade300),
        transition: [.all()],
      ),
      child: Row(
        children: [
          icon == null
              ? ElView(style: .new(width: 16))
              : ElView(
                  style: .new(width: iconWidth),
                  child: Center(child: icon),
                ),
          Expanded(
            child: ElView(
              style: .new(fontWeight: .w500, fontSize: 15, color: Colors.black),
              child: title,
            ),
          ),
        ],
      ),
    );

    if (!isEnd) {
      result = Stack(
        children: [
          result,
          Positioned(
            left: icon == null ? 16 : iconWidth,
            right: 16,
            bottom: 0,
            child: ColoredBox(color: Colors.grey.shade300, child: SizedBox(height: 0.5)),
          ),
        ],
      );
    }
    return result;
  }
}

/// 列表行的声明模式。
enum ElListTileType {
  /// 普通内容与点击动作。
  basic,

  /// 页面导航入口。
  page,

  /// 布尔开关入口。
  switcher,
}

/// 列表内容、页面入口或布尔开关的公共声明。
class ElListTile extends StatelessWidget {
  /// 创建普通列表行。
  const ElListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.disabled = false,
    this.style,
  }) : type = .basic,
       page = null,
       rootNavigator = false,
       value = null,
       modelValue = null,
       onChanged = null,
       loading = false,
       switchStyle = null;

  /// 创建页面入口，导航行为由品牌实现提供。
  const ElListTile.page({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.page,
    this.rootNavigator = false,
    this.onTap,
    this.disabled = false,
    this.style,
  }) : type = .page,
       value = null,
       modelValue = null,
       onChanged = null,
       loading = false,
       switchStyle = null;

  /// 创建开关入口，仅声明值通道，不建立绑定。
  const ElListTile.switcher({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.value,
    this.modelValue,
    this.onChanged,
    this.disabled = false,
    this.loading = false,
    this.style,
    this.switchStyle,
  }) : type = .switcher,
       page = null,
       rootNavigator = false,
       onTap = null;

  /// 当前列表行的声明模式。
  final ElListTileType type;

  /// 主内容，接受文字、图标或 Widget。
  final Object title;

  /// 可选副内容。
  final Object? subtitle;

  /// 起边内容。
  final Object? leading;

  /// 末边内容。
  final Object? trailing;

  /// 普通行或页面入口的点击通知。
  final VoidCallback? onTap;

  /// 是否禁用列表行。
  final bool disabled;

  /// 页面入口的目标页面。
  final Widget? page;

  /// 是否由根导航器打开页面。
  final bool rootNavigator;

  /// 开关行的普通值输入，保留原有跨类型列表行的宽容值通道。
  final dynamic value;

  /// 开关行的外部双向模型。
  final ValueNotifier<dynamic>? modelValue;

  /// 开关值变化通知，开关模式的变化值为 bool。
  final ValueChanged<dynamic>? onChanged;

  /// 开关行是否处于加载状态。
  final bool loading;

  /// 列表行样式。
  final ElStyle? style;

  /// 开关入口样式。
  final ElStyle? switchStyle;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).listTileBuilder!(context, this);
}
