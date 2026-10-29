import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// InputTag 草稿提交键。
enum ElInputTagTrigger {
  /// 按 Enter 提交草稿。
  enter,

  /// 按 Space 提交草稿。
  space,
}

/// InputTag 重复值策略。
enum ElInputTagDuplicatePolicy {
  /// 拒绝与已有标签完全相同的值。
  reject,

  /// 允许重复值。
  allow,
}

/// InputTag 暴露给业务侧的控制门面。
class ElInputTagController {
  Object? _owner;
  bool Function()? _focus;
  bool Function()? _blur;

  /// 是否已挂载标签输入框。
  bool get attached => _owner != null;

  /// 聚焦草稿输入；未挂载或禁用时返回 false。
  bool focus() => _focus?.call() ?? false;

  /// 释放草稿焦点；未挂载时返回 false。
  bool blur() => _blur?.call() ?? false;

  /// 供品牌实现挂载草稿焦点动作，同一 owner 在生命周期内保持稳定。
  void attach({required Object owner, required bool Function() focus, required bool Function() blur}) {
    if (_owner != null && !identical(_owner, owner)) {
      throw StateError('同一个 ElInputTagController 不能同时绑定多个 ElInputTag');
    }
    _owner = owner;
    _focus = focus;
    _blur = blur;
  }

  /// 供品牌实现卸载自身持有的动作。
  void detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _focus = null;
    _blur = null;
  }
}

/// 公共 InputTag 声明，由全局组件主题提供具体实现。
class ElInputTag extends StatelessWidget {
  /// 创建 InputTag 公共声明。
  ElInputTag({
    super.key,
    this.value,
    this.modelValue,
    this.onChanged,
    this.controller,
    this.trigger = ElInputTagTrigger.enter,
    this.delimiter,
    this.saveOnBlur = true,
    this.addOnBlur,
    this.minLength,
    this.max,
    this.clearable = false,
    this.disabled = false,
    this.readOnly = false,
    this.placeholder,
    this.duplicatePolicy = ElInputTagDuplicatePolicy.reject,
    this.validate,
    this.onInvalid,
    this.onInput,
    this.onAdd,
    this.onRemove,
    this.onClear,
    this.onDragTag,
    this.autofocus = false,
    this.focusNode,
    this.onKeyEvent,
    this.onFocus,
    this.onBlur,
    this.maxLength,
    this.prefix,
    this.suffix,
    this.tagBuilder,
    this.clearIcon,
    this.collapseTags = false,
    this.maxCollapseTags = 1,
    this.collapseTagsTooltip = false,
    this.draggable = false,
    this.tagType = ElThemeType.primary,
    this.tagEffect = ElTagEffect.light,
    this.tagSize,
    this.style,
    this.tagStyle,
    this.semanticLabel,
  }) : assert(delimiter == null || delimiter is! String || delimiter.isNotEmpty, 'delimiter 字符串不得为空'),
       assert(minLength == null || minLength >= 0, 'minLength 不得为负'),
       assert(max == null || max >= 0, 'max 不得为负'),
       assert(maxLength == null || maxLength > 0, 'maxLength 必须大于 0'),
       assert(maxCollapseTags > 0, 'maxCollapseTags 必须大于 0'),
       assert(value == null || modelValue == null, 'value 与 modelValue 互斥');

  /// 控制门面，用于业务代码主动 focus / blur 内部草稿输入框。
  final ElInputTagController? controller;

  /// 草稿提交键。
  final ElInputTagTrigger trigger;

  /// 输入中出现分隔符时自动拆成标签；支持 [String] 与 [RegExp]。
  final Pattern? delimiter;

  /// 真正失焦时是否尝试提交非空草稿；对齐官方 `save-on-blur`，默认开启。
  final bool saveOnBlur;

  /// 兼容旧命名的失焦提交开关；null 时使用 [saveOnBlur]。
  final bool? addOnBlur;

  /// 标签提交前的最小 Unicode 字素长度；null 表示不限。
  final int? minLength;

  /// 最大标签数量；null 表示不限。
  final int? max;

  /// 是否在有标签或草稿时显示清空按钮。
  final bool clearable;

  /// 禁用后标签不可操作，草稿区不挂载 Editable。
  final bool disabled;

  /// 只读呈现，禁止增删标签与清空。
  final bool readOnly;

  /// 没有标签和草稿时显示的提示文本。
  final String? placeholder;

  /// 重复值处理策略。
  final ElInputTagDuplicatePolicy duplicatePolicy;

  /// 标签级同步校验；内建空值、重复与数量上限检查通过后调用。
  final String? Function(String value, List<String> current)? validate;

  /// 添加被拒绝时的通知。
  final void Function(String value, String reason)? onInvalid;

  /// 草稿输入变更通知；IME composing 中间态不会触发。
  final ValueChanged<String>? onInput;

  /// 成功添加单个标签后的通知。
  final ValueChanged<String>? onAdd;

  /// 成功移除标签后的通知，参数依次是值与原索引。
  final void Function(String value, int index)? onRemove;

  /// 用户点击清空按钮后的通知。
  final VoidCallback? onClear;

  /// 拖拽重排成功后的通知，参数为旧索引、新索引和值。
  final void Function(int oldIndex, int newIndex, String value)? onDragTag;

  /// 首次挂载后是否自动聚焦草稿输入。
  final bool autofocus;

  /// 草稿输入焦点节点；null 时由组件内部管理。
  final FocusNode? focusNode;

  /// InputTag 内建键盘状态机之前的调用方拦截器。
  final FocusOnKeyEventCallback? onKeyEvent;

  /// 草稿输入获得焦点的通知。
  final VoidCallback? onFocus;

  /// 整个标签输入交互真正离开后的通知。
  final VoidCallback? onBlur;

  /// 草稿最大 UTF-16 code unit 长度；完整 Unicode 字素不会被劈开。
  final int? maxLength;

  /// 输入区前置内容。
  final Object? prefix;

  /// 输入区尾随内容。
  final Object? suffix;

  /// 自定义标签内容。
  final Widget Function(BuildContext context, String value, int index, bool selected)? tagBuilder;

  /// 清空按钮图标。
  final IconData? clearIcon;

  /// 是否折叠多余标签。
  final bool collapseTags;

  /// 折叠时直接显示的标签数量。
  final int maxCollapseTags;

  /// 折叠标签悬停时是否显示隐藏标签 tooltip。
  final bool collapseTagsTooltip;

  /// 是否允许拖拽标签重排。
  final bool draggable;

  /// 标签主题类型。
  final ElThemeType tagType;

  /// 标签外观效果。
  final ElTagEffect tagEffect;

  /// 标签尺寸；null 时跟随 Element 当前尺寸档。
  final ElLevelType? tagSize;

  /// 输入框壳样式覆盖。
  final ElStyle? style;

  /// 每个标签的样式覆盖。
  final ElStyle? tagStyle;

  /// 草稿输入的无障碍标签。
  final String? semanticLabel;

  /// 当前值；也可由品牌实现接入祖先表单字段。
  final List<String>? value;

  /// 外部双向绑定，生命周期由调用方管理。
  final ValueNotifier<List<String>>? modelValue;

  /// 用户修改已确认值后的通知。
  final ValueChanged<List<String>>? onChanged;

  @override
  Widget build(BuildContext context) => ElComponentProvider.of(context).inputTagBuilder!(context, this);
}
