import 'package:flutter/widgets.dart';

import '../../commons/models.dart' show ElThemeType;
import '../../views/view/style/style.dart' show ElStyle;
import '../index.dart' show ElComponentProvider;

/// 按钮组的选择方式；普通组不设置选择方式。
enum ElButtonGroupMode {
  /// 单选，模型值对应一个条目。
  single,

  /// 多选，模型值为 List 或 Set。
  multi,
}

/// 按钮组条目，声明内容、身份与交互，外观由组统一配置。
class ElButtonGroupItem {
  /// 创建按钮组条目。
  const ElButtonGroupItem({
    this.child,
    this.value,
    this.disabled = false,
    this.flex,
    this.onPressed,
    this.semanticLabel,
  });

  /// 按钮内容，接受文本、图标、Widget 或任意对象。
  final Object? child;

  /// 任意类型的条目身份，须兼容单选模型或多选集合的元素类型，未指定时使用下标。
  final Object? value;

  /// 是否禁用该条目。
  final bool disabled;

  /// block 模式下的空间份额，默认 1；移动端暂用 Material 的等分布局。
  final int? flex;

  /// 条目激活回调，选择更新后调用。
  final VoidCallback? onPressed;

  /// 辅助技术读取的条目名称。
  final String? semanticLabel;
}

/// 公共按钮组配置，D 表示完整模型类型，外观、选择和值绑定由品牌实现提供。
class ElButtonGroup<D> extends StatelessWidget {
  /// 创建普通按钮组，不启用选择和值绑定。
  const ElButtonGroup({
    super.key,
    required this.children,
    this.type,
    this.bgColor,
    this.disabled = false,
    this.axis = Axis.horizontal,
    this.block = false,
    this.style,
    this.semanticLabel,
  }) : mode = null,
       mandatory = false,
       value = null,
       modelValue = null,
       onChanged = null,
       assert(children.length > 1, 'ElButtonGroup.children 必须至少包含 2 个按钮');

  /// 创建单选组；可空模型可清空选择，mandatory 时保留选中项。
  const ElButtonGroup.single({
    super.key,
    this.value,
    this.modelValue,
    this.onChanged,
    required this.children,
    this.mandatory = false,
    this.type,
    this.bgColor,
    this.disabled = false,
    this.axis = Axis.horizontal,
    this.block = false,
    this.style,
    this.semanticLabel,
  }) : mode = ElButtonGroupMode.single,
       assert(children.length > 1, 'ElButtonGroup.children 必须至少包含 2 个按钮'),
       assert(value == null || modelValue == null, 'value 与 modelValue 互斥，二选一');

  /// 创建多选组；模型为 List 或 Set，mandatory 时保留最后一个选中项。
  const ElButtonGroup.multi({
    super.key,
    this.value,
    this.modelValue,
    this.onChanged,
    required this.children,
    this.mandatory = false,
    this.type,
    this.bgColor,
    this.disabled = false,
    this.axis = Axis.horizontal,
    this.block = false,
    this.style,
    this.semanticLabel,
  }) : mode = ElButtonGroupMode.multi,
       assert(children.length > 1, 'ElButtonGroup.children 必须至少包含 2 个按钮'),
       assert(value == null || modelValue == null, 'value 与 modelValue 互斥，二选一');

  /// 组内条目，数量必须大于 1。
  final List<ElButtonGroupItem> children;

  /// 选择方式；null 表示普通组。
  final ElButtonGroupMode? mode;

  /// 初始完整模型值，单选为条目值，多选为 List 或 Set，重建时同步新值。
  final D? value;

  /// 外部双向绑定，生命周期由调用方管理。
  final ValueNotifier<D>? modelValue;

  /// 模型值变化时的回调。
  final ValueChanged<D>? onChanged;

  /// 是否必须保留至少一个选中项。
  final bool mandatory;

  /// 组级语义配色。
  final ElThemeType? type;

  /// 组级背景色或颜色 token，优先于语义色。
  final Color? bgColor;

  /// 是否禁用整组。
  final bool disabled;

  /// 条目排列方向。
  final Axis axis;

  /// 是否沿排列方向撑满可用空间。
  final bool block;

  /// 按钮组容器样式。
  final ElStyle? style;

  /// 辅助技术读取的组名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.builderOf(context, this, (b) => b.buttonGroup)<D>(context, this);
}
