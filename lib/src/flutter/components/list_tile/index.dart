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

  /// 弹出单选菜单的入口。
  popup,
}

/// 泛型列表行，值绑定由 ElModelValue 持有，布局与弹窗由品牌实现提供。
class ElListTile<T> extends ElModelValue<T> {
  /// 创建普通列表行，默认后缀由品牌实现解析为箭头。
  ElListTile({
    super.key,
    super.value,
    super.modelValue,
    super.onChanged,
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
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥，二选一'),
       assert(value != null || modelValue != null || null is T, '非空 T 必须提供 value 或 modelValue，无选中值时使用可空类型'),
       type = .basic,
       loading = false,
       switchStyle = null,
       options = const [],
       popupAnchor = null,
       popupMaxHeight = null,
       popupStyle = null,
       optionStyle = null,
       closeOnSelect = true,
       popupLabel = null;

  /// 创建布尔开关行，使用 bool 泛型，未提供值时从 false 开始。
  ElListTile.switcher({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    T? value,
    super.modelValue,
    super.onChanged,
    this.disabled = false,
    this.loading = false,
    this.style,
    this.switchStyle,
    this.event,
    this.focusNode,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥，二选一'),
       assert(false is T, 'switcher 的绑定类型必须兼容 bool'),
       assert(value == null || value is bool, 'switcher 只接受 bool 值'),
       assert(modelValue == null || modelValue.value is bool, 'switcher 的模型必须持有 bool 值'),
       type = .switcher,
       valueText = null,
       trailing = null,
       onTap = null,
       options = const [],
       popupAnchor = null,
       popupMaxHeight = null,
       popupStyle = null,
       optionStyle = null,
       closeOnSelect = true,
       popupLabel = null,
       super(value: value ?? false as T);

  /// 创建弹出单选菜单的列表行，选中值沿泛型模型回写。
  ElListTile.popup({
    super.key,
    super.value,
    super.modelValue,
    super.onChanged,
    required this.title,
    this.subtitle,
    this.leading,
    this.valueText,
    this.trailing = ElEmptyWidget.instance,
    required this.options,
    this.popupAnchor = const ElOverlayAnchor(placement: .bottomStart, offset: 4),
    this.popupMaxHeight,
    this.popupStyle,
    this.optionStyle,
    this.closeOnSelect = true,
    this.popupLabel,
    this.disabled = false,
    this.style,
    this.event,
    this.focusNode,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥，二选一'),
       assert(value != null || modelValue != null || null is T, '非空 T 必须提供 value 或 modelValue，无选中值时使用可空类型'),
       assert(options.every((option) => option.value is T), '菜单项 value 必须符合绑定类型 T'),
       assert(popupMaxHeight == null || (popupMaxHeight > 0 && popupMaxHeight.isFinite), 'popupMaxHeight 必须是正的有限数'),
       type = .popup,
       onTap = null,
       loading = false,
       switchStyle = null;

  /// 当前列表行的声明模式。
  final ElListTileType type;

  /// 挂载后的当前模型值，供品牌构建与事件读取。
  T get currentValue => $obs.value;

  /// 写入同一模型并沿用基类通知，品牌实现无需另建绑定。
  set currentValue(T value) => $obs.value = value;

  /// 主内容，接受文字、图标或 Widget。
  final Object title;

  /// 可选副内容。
  final Object? subtitle;

  /// 起边内容。
  final Object? leading;

  /// 右侧当前值的显示覆盖，弹窗行省略时显示选中项文案，与后缀是否显示无关。
  final Object? valueText;

  /// 后缀占位符表示品牌默认图标，普通行显示右箭头，弹窗行显示菜单提示；null 移除后缀及间距。
  final Object? trailing;

  /// 普通行的默认激活动作，导航由调用方处理，可由 event.preventDefault 阻止。
  final VoidCallback? onTap;

  /// 禁止行激活、开关切换与焦点请求。
  final bool disabled;

  /// 开关行显示加载状态并暂时阻止切换。
  final bool loading;

  /// 在品牌默认行样式之后合并的样式。
  final ElStyle? style;

  /// 开关行末端开关的样式。
  final ElStyle? switchStyle;

  /// 弹出菜单的选项，每项 value 须符合 T 并回写模型，label 用于默认展示。
  final List<ElLabelModel<T>> options;

  /// 弹出菜单相对列表行的定位、间距、宽度匹配和边界避让配置。
  final ElOverlayAnchor? popupAnchor;

  /// 弹出菜单最大高度，省略时由可用空间限制。
  final double? popupMaxHeight;

  /// 弹出菜单面板样式。
  final ElStyle? popupStyle;

  /// 弹出菜单条目的默认样式。
  final ElStyle? optionStyle;

  /// 选择菜单项后是否关闭弹窗。
  final bool closeOnSelect;

  /// 弹出菜单的辅助名称，省略时可使用文本标题。
  final String? popupLabel;

  /// 用户事件，沿用默认动作与 preventDefault 规则，触摸延迟通过 config 设置。
  final ElEvent? event;

  /// 外部焦点节点，生命周期由调用方管理。
  final FocusNode? focusNode;

  /// 辅助技术读取的行名称。
  final String? semanticLabel;

  @override
  Widget obsBuilder(BuildContext context) => ElComponentProvider.of(context).listTileBuilder!<T>(context, this);
}
