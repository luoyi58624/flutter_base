import 'package:flutter/material.dart'
    show DropdownMenuCloseBehavior, DropdownMenuEntry, FilterCallback, InputDecorationTheme, MenuStyle, SearchCallback;
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/ui.dart';

/// 公共 Select 声明，由全局组件主题提供具体实现。
class ElSelect<T> extends StatelessWidget {
  /// 创建 Select 公共声明。
  ElSelect({
    super.key,
    this.value,
    this.modelValue,
    this.onChanged,
    this.controller,
    required this.children,
    this.enabled = true,
    this.disabled = false,
    this.width,
    this.menuHeight,
    this.scrollController,
    this.anchor = const ElOverlayAnchor(placement: .bottomStart, offset: 4, matchWidth: true),
    this.zIndex = 2000,
    this.focusNode,
    this.leadingIcon,
    this.trailingIcon,
    this.selectedTrailingIcon,
    this.showTrailingIcon = true,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.enableFilter = false,
    this.enableSearch = false,
    this.keyboardType,
    this.textStyle,
    this.textAlign,
    this.filterCallback,
    this.optionFilter,
    this.searchCallback,
    this.inputDecorationTheme,
    this.menuStyle,
    this.panelStyle,
    this.initialSelection,
    this.onSelected,
    this.requestFocusOnTap = true,
    this.expandedInsets,
    this.alignmentOffset,
    this.inputFormatters,
    this.closeBehavior = DropdownMenuCloseBehavior.all,
    this.maxLines,
    this.textInputAction,
    this.restorationId,
    this.style,
    this.optionStyle,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥') {
    if (width != null && (!width!.isFinite || width! <= 0)) {
      throw FlutterError('ElSelect width 必须是正的有限数。');
    }
    if (menuHeight != null && (!menuHeight!.isFinite || menuHeight! <= 0)) {
      throw FlutterError('ElSelect menuHeight 必须是正的有限数。');
    }
    final seen = <T>{};
    for (final option in children) {
      final resolved = option.value ?? (option.label is T ? option.label as T : null);
      if (option.label == null ||
          (option.label!.trim().isEmpty && option is! ElSelectOption<T>) ||
          resolved == null ||
          !seen.add(resolved)) {
        throw FlutterError('ElSelect 的选项 label 必须非空，value 必须能解析且唯一。');
      }
    }
  }

  /// 旧 Material 文本控制器兼容入口；新 ElEditable 后端不消费该对象。
  @Deprecated('ElSelect 已迁到 ElEditable；请通过 value/modelValue 与 enableFilter 控制内容。')
  final TextEditingController? controller;

  /// 可选项；label 必须非空，解析后的 value 必须唯一。
  final List<ElLabelModel<T>> children;

  /// 是否可交互；false 时关闭已开启菜单并退出焦点链。
  final bool enabled;

  /// 禁用交互，优先于 enabled。
  final bool disabled;

  /// 触发器宽度；菜单默认与触发器严格同宽。
  final double? width;

  /// 菜单最大高度；null 时由当前 overlay host 的可用空间约束。
  final double? menuHeight;

  /// 菜单滚动控制器；null 时选择器内部自建自管，键盘导航始终可自动滚动。
  final ScrollController? scrollController;

  /// 菜单锚定配置；默认下方左对齐、间距 4，且严格匹配触发器宽度。
  final ElOverlayAnchor anchor;

  /// 旧层级兼容参数；浮层顺序由官方 Portal 的打开顺序决定。
  final int zIndex;

  /// 触发器焦点节点；null 时组件内部自建自管。
  final FocusNode? focusNode;

  /// 输入区前置图标。
  final Widget? leadingIcon;

  /// 菜单关闭时的尾随图标；null 时显示默认向下箭头。
  final Widget? trailingIcon;

  /// 菜单开启时的尾随图标；null 时显示默认向上箭头。
  final Widget? selectedTrailingIcon;

  /// 是否显示尾随图标。
  final bool showTrailingIcon;

  /// 旧 Material label 兼容入口；新后端不渲染该槽位。
  @Deprecated('请在 ElSelect 外部组合 label。')
  final Widget? label;

  /// 尚无可显示选中项时的提示文本。
  final String? hintText;

  /// 旧 Material helperText 兼容入口；新后端不渲染该槽位。
  @Deprecated('请用 ElFormItem 或外部 ElView 展示帮助文本。')
  final String? helperText;

  /// 旧 Material errorText 兼容入口；新后端改由 ElFormItem 展示校验错误。
  @Deprecated('请使用 ElFormItem 的 error/规则校验。')
  final String? errorText;

  /// 是否允许输入 query 筛选 option。
  final bool enableFilter;

  /// 旧 Material 搜索高亮开关；新后端只在 [searchCallback] 非 null 时消费。
  @Deprecated('请使用键盘 active 导航，或提供 searchCallback 兼容旧搜索逻辑。')
  final bool enableSearch;

  /// 旧 Material 输入类型；仍透传给内部 ElInput。
  final TextInputType? keyboardType;

  /// 旧 Material 文本样式兼容入口；新后端请改用 [style]。
  @Deprecated('请使用 style。')
  final TextStyle? textStyle;

  /// 旧 Material 文本对齐兼容入口；新后端固定按输入方向起始边对齐。
  @Deprecated('ElSelect 新后端固定按输入方向起始边对齐。')
  final TextAlign? textAlign;

  /// 旧 Material 筛选回调；新后端把 option 临时映射为数据型
  /// [DropdownMenuEntry] 后消费，不会创建 Material DropdownMenu。
  final FilterCallback<T>? filterCallback;

  /// ElSelect 原生 option 筛选器；null 时回落旧 [filterCallback]，再回落
  /// label 不区分大小写的 contains 匹配。
  final bool Function(ElLabelModel<T> option, String query)? optionFilter;

  /// 旧 Material 搜索回调；返回索引用于设置当前键盘 active option。
  final SearchCallback<T>? searchCallback;

  /// 旧 Material 输入装饰主题兼容入口；新后端不消费。
  @Deprecated('请使用 style/panelStyle/optionStyle。')
  final InputDecorationTheme? inputDecorationTheme;

  /// 旧 Material 菜单样式兼容入口；新后端不消费。
  @Deprecated('请使用 panelStyle。')
  final MenuStyle? menuStyle;

  /// ElPortal 菜单面板样式覆盖。
  final ElStyle? panelStyle;

  /// 旧 Material 初始选中值；仅在 value/modelValue 都未提供时作为初值。
  final T? initialSelection;

  /// 旧 Material 选择回调；与 onChanged 并存时各调用一次。
  final ValueChanged<T?>? onSelected;

  /// 旧 Material 点击聚焦开关兼容入口；ElEditable 后端暂不消费。
  @Deprecated('ElEditable trigger 统一按指针语义聚焦。')
  final bool requestFocusOnTap;

  /// 旧 Material 展开 inset 兼容入口；新后端请使用 [anchor] 与 [width]。
  @Deprecated('请使用 anchor 与 width。')
  final EdgeInsets? expandedInsets;

  /// 旧 Material 对齐偏移兼容入口；新后端请使用 [anchor]。
  @Deprecated('请使用 ElOverlayAnchor.offset/crossOffset。')
  final Offset? alignmentOffset;

  /// Material formatter 兼容入口；过滤 query 时适配进 editable 事务管线。
  final List<TextInputFormatter>? inputFormatters;

  /// 选择 option 后的关闭策略；none 保持菜单，all/self 都关闭当前 Select。
  final DropdownMenuCloseBehavior closeBehavior;

  /// 旧 Material 最大行数兼容入口；Select trigger 恒为单行。
  @Deprecated('ElSelect trigger 恒为单行。')
  final int? maxLines;

  /// 旧 Material IME action；仍透传给内部 ElInput。
  final TextInputAction? textInputAction;

  /// 旧 Material restorationId 兼容入口；新 retained 后端不消费。
  @Deprecated('ElSelect retained 后端暂不消费 restorationId。')
  final String? restorationId;

  /// 触发器输入框样式覆盖。
  final ElStyle? style;

  /// 每个 option 的样式覆盖。
  final ElStyle? optionStyle;

  /// 选择器无障碍标签。
  final String? semanticLabel;

  /// 当前值；也可由品牌实现接入祖先表单字段。
  final T? value;

  /// 外部双向绑定，生命周期由调用方管理。
  final ValueNotifier<T>? modelValue;

  /// 用户修改已确认值后的通知。
  final ValueChanged<T>? onChanged;

  /// 查找模型值对应的选项文字，未匹配时回落 toString。
  String toTextEditing(T value) {
    for (final option in children) {
      if ((option.value ?? option.label) == value) return option.label!;
    }
    return value.toString();
  }

  /// 把精确匹配的选项文字转换成模型值。
  T toModelValue(String text) {
    for (final option in children) {
      if (option.label == text) return (option.value ?? option.label) as T;
    }
    return text as T;
  }

  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.selectBuilder)(context, this);
}

/// 支持自定义呈现、禁用与无障碍名称的选择项，也兼容普通 ElLabelModel。
class ElSelectOption<T> extends ElLabelModel<T> {
  /// 创建选择项；Widget 内容的文本匹配使用 semanticLabel。
  ElSelectOption(this.content, T value, {this.disabled = false, this.semanticLabel})
    : super(content is String ? content : semanticLabel ?? '', value);

  /// 展示内容，可传文字或 Widget。
  final Object content;

  /// 是否禁止用户选择本项。
  final bool disabled;

  /// 辅助技术读取的名称。
  final String? semanticLabel;

  @override
  T get value => super.value as T;
}
