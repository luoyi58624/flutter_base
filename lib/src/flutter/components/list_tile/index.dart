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

  /// 布尔开关入口。
  switcher,
}

/// 普通列表行或布尔开关行的公共声明，布局与交互由品牌实现提供。
class ElListTile extends StatelessWidget {
  /// 创建普通列表行，默认后缀由品牌实现解析为箭头。
  const ElListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.valueText,
    this.trailing = ElEmptyWidget.instance,
    this.onTap,
    this.disabled = false,
    this.style,
    this.event,
    this.focusNode,
    this.semanticLabel,
  }) : type = .basic,
       value = null,
       modelValue = null,
       onChanged = null,
       loading = false,
       switchStyle = null;

  /// 创建整行可切换的开关入口，值与模型互斥，末端固定为开关。
  const ElListTile.switcher({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.value,
    this.modelValue,
    this.onChanged,
    this.disabled = false,
    this.loading = false,
    this.style,
    this.switchStyle,
    this.event,
    this.focusNode,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥，二选一'),
       type = .switcher,
       valueText = null,
       trailing = null,
       onTap = null;

  /// 当前列表行的声明模式。
  final ElListTileType type;

  /// 主内容，接受文字、图标或 Widget。
  final Object title;

  /// 可选副内容。
  final Object? subtitle;

  /// 起边内容。
  final Object? leading;

  /// 普通行右侧的当前值，接受文本或 Widget，不受 trailing 是否显示影响。
  final Object? valueText;

  /// 普通行后缀：占位符表示品牌默认箭头，null 移除后缀及间距，其他值替换箭头。
  final Object? trailing;

  /// 普通行的默认激活动作，导航由调用方处理，可由 event.preventDefault 阻止。
  final VoidCallback? onTap;

  /// 禁止行激活、开关切换与焦点请求。
  final bool disabled;

  /// 开关行的初始值，重建时同步新值，未提供值通道时默认为 false。
  final bool? value;

  /// 开关行的外部双向模型，生命周期由调用方管理。
  final ValueNotifier<bool>? modelValue;

  /// 用户切换开关后的值通知，为空不等于禁用。
  final ValueChanged<bool>? onChanged;

  /// 开关行显示加载状态并暂时阻止切换。
  final bool loading;

  /// 在品牌默认行样式之后合并的样式。
  final ElStyle? style;

  /// 开关行末端开关的样式。
  final ElStyle? switchStyle;

  /// 用户事件，沿用默认动作与 preventDefault 规则，触摸延迟通过 config 设置。
  final ElEvent? event;

  /// 外部焦点节点，生命周期由调用方管理。
  final FocusNode? focusNode;

  /// 辅助技术读取的行名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => ElComponentProvider.of(context).listTileBuilder!(context, this);
}
