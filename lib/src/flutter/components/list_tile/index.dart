import 'package:flutter/widgets.dart';

import '../../../../dart.dart' show $absent;
import '../../../dart/gen/index.dart' show $absent;
import '../../commons/models.dart' show ElLabelModel;
import '../../utils/model_value/index.dart' show ElModelValue, ElModelValueType;
import '../../views/view/event/event.dart' show ElEvent;
import '../../views/view/style/style.dart' show ElStyle;
import '../../widgets/popup/anchor.dart' show ElOverlayAnchor;
import '../index.dart' show ElComponentProvider;

part 'group.dart';
part 'option.dart';

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
  ///
  /// [value] 是此行在单选或多选列表组中代表的选项值。
  ElListTile({
    super.key,
    super.value,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing = $absent,
    this.trailingText,
    this.onTap,
    this.disabled = false,
    this.style,
    this.event,
    this.focusNode,
    this.semanticLabel,
  }) : assert(value != null || null is T, '非空 T 必须提供 value，无选项值时请省略泛型或使用可空类型'),
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
       trailingText = null,
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
    this.trailing = $absent,
    this.trailingText,
    required this.options,
    this.popupAnchor,
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
       assert(_validMenuOptions<T>(options), '菜单树的 value 必须符合绑定类型 T 且唯一'),
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

  /// $absent 使用品牌默认图标，普通行显示右箭头，弹窗行显示菜单提示；null 移除后缀及间距。
  final Object? trailing;

  /// 右侧当前值的显示覆盖，弹窗行省略时显示选中项文案，与后缀是否显示无关。
  final Object? trailingText;

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

  /// 单选菜单项，简单项使用 ElLabelModel，嵌套、禁用或带说明的项使用 ElMenuOption。
  final List<ElLabelModel<T>> options;

  /// 显式设置元素锚定；省略时由品牌按指针位置或键盘触发元素定位。
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
  Widget obsBuilder(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.listTile)<T>(context, this);
}
