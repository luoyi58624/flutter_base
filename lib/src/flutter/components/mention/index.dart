import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/ui.dart';

/// Mention 弹层方向，限制为 Element Plus 官方的 top / bottom 两档。
enum ElMentionPlacement {
  /// 弹层出现在光标上方。
  top,

  /// 弹层出现在光标下方。
  bottom,
}

/// Mention 候选项。
class ElMentionOption<T> {
  /// 创建 Mention 候选；[value] 是最终写入文本的内容，不含 prefix 和 split。
  const ElMentionOption({required this.value, this.label, this.disabled = false, this.data});

  /// 选择后写入的值。
  final String value;

  /// 面板展示文本；为空时回落 [value]。
  final String? label;

  /// 禁用项仍展示但不会被键盘或指针选中。
  final bool disabled;

  /// 业务自定义载荷。
  final T? data;
}

/// 当前光标处可触发 Mention 的上下文。
class ElMentionContext {
  /// 创建 Mention 上下文。
  const ElMentionContext({
    required this.pattern,
    required this.start,
    required this.end,
    required this.prefix,
    required this.prefixIndex,
    required this.splitIndex,
    required this.selectionEnd,
  });

  /// prefix 后、光标前的查询文本。
  final String pattern;

  /// 替换候选时的起点，即 prefix 后第一个 offset。
  final int start;

  /// 替换候选时的终点，即当前折叠光标 offset。
  final int end;

  /// 命中的 prefix。
  final String prefix;

  /// prefix 在文档中的 offset。
  final int prefixIndex;

  /// prefix 左侧最近 split / 换行 offset；不存在时为 -1。
  final int splitIndex;

  /// 当前主选区折叠端。
  final int selectionEnd;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElMentionContext &&
          pattern == other.pattern &&
          start == other.start &&
          end == other.end &&
          prefix == other.prefix &&
          prefixIndex == other.prefixIndex &&
          splitIndex == other.splitIndex &&
          selectionEnd == other.selectionEnd;

  @override
  int get hashCode => Object.hash(pattern, start, end, prefix, prefixIndex, splitIndex, selectionEnd);
}

/// whole 模式下 Backspace 命中的完整 Mention 区间。
class ElMentionWholeContext {
  /// 创建完整 Mention 删除上下文。
  const ElMentionWholeContext({
    required this.pattern,
    required this.prefix,
    required this.prefixIndex,
    required this.splitIndex,
    required this.selectionEnd,
  });

  /// prefix 与尾随 split 之间的 Mention 文本。
  final String pattern;

  /// 命中的 prefix。
  final String prefix;

  /// prefix 在文档中的 offset。
  final int prefixIndex;

  /// 尾随 split 在文档中的 offset。
  final int splitIndex;

  /// 当前主选区折叠端，必须等于 `splitIndex + 1`。
  final int selectionEnd;
}

const int _mentionScanChunk = 256;

int _clampOffset(int value, int max) => value.clamp(0, max).toInt();

List<String> _normalizePrefixes(Iterable<String> raw) {
  final result = <String>[];
  for (final item in raw) {
    if (item.length != 1 || item == '\n') {
      throw ArgumentError.value(raw, 'prefix', 'Mention prefix 每一项必须是非换行的单个 UTF-16 code unit。');
    }
    if (!result.contains(item)) result.add(item);
  }
  if (result.isEmpty) {
    throw ArgumentError.value(raw, 'prefix', 'Mention 至少需要一个 prefix。');
  }
  return List<String>.unmodifiable(result);
}

String? _prefixAt(String chunk, int index, List<String> prefixes) {
  final unit = chunk.codeUnitAt(index);
  for (final prefix in prefixes) {
    if (prefix.codeUnitAt(0) == unit) return prefix;
  }
  return null;
}

/// 按 Element Plus 2.13.x helper 口径从光标向左分块解析 Mention 上下文。
ElMentionContext? resolveElMentionContext(
  ElEditableController document,
  TextSelection selection, {
  Iterable<String> prefix = const ['@'],
  String split = ' ',
}) {
  final prefixes = _normalizePrefixes(prefix);
  if (split.length != 1 || split == '\n') {
    throw ArgumentError.value(split, 'split', 'Mention split 必须是非换行的单个 UTF-16 code unit。');
  }
  if (!selection.isValid || !selection.isCollapsed) return null;
  final selectionEnd = _clampOffset(selection.extentOffset, document.length);
  var cursor = selectionEnd;
  final piecesRightToLeft = <String>[];
  final splitUnit = split.codeUnitAt(0);
  var splitIndex = -1;
  String? foundPrefix;
  int? prefixIndex;

  while (cursor > 0) {
    final start = math.max(0, cursor - _mentionScanChunk);
    final chunk = document.getText(start, cursor);
    var pieceEnd = chunk.length;
    for (var i = chunk.length - 1; i >= 0; i--) {
      final unit = chunk.codeUnitAt(i);
      if (splitIndex == -1 && (unit == splitUnit || unit == 0x0a || unit == 0x0d)) {
        splitIndex = start + i;
        piecesRightToLeft.clear();
        pieceEnd = i;
        continue;
      }
      final candidate = _prefixAt(chunk, i, prefixes);
      if (candidate == null) continue;
      foundPrefix = candidate;
      prefixIndex = start + i;
      piecesRightToLeft.add(chunk.substring(i + candidate.length, pieceEnd));
      break;
    }
    if (foundPrefix != null) break;
    if (pieceEnd > 0) piecesRightToLeft.add(chunk.substring(0, pieceEnd));
    cursor = start;
  }
  final matchedPrefix = foundPrefix;
  final matchedIndex = prefixIndex;
  if (matchedPrefix == null || matchedIndex == null) return null;
  final pattern = piecesRightToLeft.reversed.join();
  return ElMentionContext(
    pattern: pattern,
    start: matchedIndex + matchedPrefix.length,
    end: splitIndex == -1 ? selectionEnd : splitIndex,
    prefix: matchedPrefix,
    prefixIndex: matchedIndex,
    splitIndex: splitIndex,
    selectionEnd: selectionEnd,
  );
}

/// 解析 whole 模式 Backspace 是否命中一个完整 Mention。
ElMentionWholeContext? resolveElMentionWholeContext(
  ElEditableController document,
  TextSelection selection, {
  Iterable<String> prefix = const ['@'],
  String split = ' ',
  Iterable<String> values = const <String>[],
  bool Function(String pattern, String prefix)? checkIsWhole,
}) {
  final prefixes = _normalizePrefixes(prefix);
  if (split.length != 1 || split == '\n') {
    throw ArgumentError.value(split, 'split', 'Mention split 必须是非换行的单个 UTF-16 code unit。');
  }
  final ctx = resolveElMentionContext(document, selection, prefix: prefixes, split: split);
  if (ctx == null || ctx.splitIndex < 0 || ctx.splitIndex + 1 != ctx.selectionEnd) return null;
  final pattern = ctx.pattern;
  final exact = values.contains(pattern);
  final custom = checkIsWhole?.call(pattern, ctx.prefix) ?? false;
  if (!exact && !custom) return null;
  return ElMentionWholeContext(
    pattern: pattern,
    prefix: ctx.prefix,
    prefixIndex: ctx.prefixIndex,
    splitIndex: ctx.splitIndex,
    selectionEnd: ctx.selectionEnd,
  );
}

/// 公共 Mention 声明，由全局组件主题提供具体实现。
class ElMention<T> extends StatelessWidget {
  /// 创建 Mention 公共声明。
  ElMention({
    super.key,
    this.value,
    this.modelValue,
    this.onChanged,
    required this.options,
    this.prefix = const ['@'],
    this.split = ' ',
    this.filterOptions,
    this.filterOption,
    this.placement = ElMentionPlacement.bottom,
    this.showArrow = false,
    this.offset = 4,
    this.whole = false,
    this.checkIsWhole,
    this.loading = false,
    this.highlightFirst = true,
    this.loop = true,
    this.onSearch,
    this.onSelected,
    this.onWholeRemove,
    this.itemBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.header,
    this.footer,
    this.placeholder,
    this.disabled = false,
    this.readOnly = false,
    this.clearable = false,
    this.maxLength,
    this.textarea = false,
    this.minLine = 3,
    this.maxLine,
    this.autofocus = false,
    this.focusNode,
    this.onKeyEvent,
    this.onFocus,
    this.onBlur,
    this.onClear,
    this.onSubmitted,
    this.inputPrefix,
    this.inputSuffix,
    this.inputFormatters = const [],
    this.onAction,
    this.onConnectionClosed,
    this.onPrivateCommand,
    this.onFloatingCursor,
    this.onAutocorrectionPromptRect,
    this.onShowToolbar,
    this.onTextPlaceholderChanged,
    this.onSelector,
    this.onUnhandledContent,
    this.onInputControlChanged,
    this.textInputAction,
    this.keyboardType,
    this.actionLabel,
    this.keyboardAppearance = Brightness.light,
    this.textCapitalization = TextCapitalization.none,
    this.smartDashesType,
    this.smartQuotesType,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.enableInteractiveSelection = true,
    this.enableIMEPersonalizedLearning = true,
    this.allowedMimeTypes = const <String>[],
    this.hintLocales = const <Locale>[],
    this.enableInlinePrediction,
    this.autofillHints = const <String>[],
    this.width,
    this.panelWidth = 220,
    this.menuHeight = 240,
    this.scrollController,
    this.zIndex = 2000,
    this.textAlign,
    this.style,
    this.panelStyle,
    this.optionStyle,
    this.semanticLabel,
  }) : assert(prefix.isNotEmpty, 'prefix 至少需要一项'),
       assert(prefix.every((item) => item.length == 1 && item != '\n'), 'prefix 每项必须是非换行的单个 UTF-16 code unit'),
       assert(split.length == 1 && split != '\n', 'split 必须是非换行的单个 UTF-16 code unit'),
       assert(!prefix.contains(split), 'prefix 不能与 split 相同'),
       assert(offset.isFinite, 'offset 必须是有限数值'),
       assert(panelWidth > 0, 'panelWidth 必须大于 0'),
       assert(menuHeight > 0, 'menuHeight 必须大于 0'),
       assert(minLine >= 1, 'minLine 必须大于等于 1'),
       assert(maxLine == null || maxLine >= minLine, 'maxLine 不得小于 minLine'),
       assert(maxLength == null || maxLength > 0, 'maxLength 必须大于 0'),
       assert(value == null || modelValue == null, 'value 与 modelValue 互斥');

  /// 候选项列表。
  final List<ElMentionOption<T>> options;

  /// 触发 Mention 的 prefix 列表，每项必须是单个 UTF-16 code unit。
  final List<String> prefix;

  /// Mention token 的分隔符，必须是单个 UTF-16 code unit。
  final String split;

  /// 自定义整表过滤；非 null 时优先于 [filterOption]。
  final Iterable<ElMentionOption<T>> Function(Iterable<ElMentionOption<T>> options, String pattern, String prefix)?
  filterOptions;

  /// 自定义单项过滤；null 时使用 label/value 的大小写不敏感 contains。
  final bool Function(ElMentionOption<T> option, String pattern, String prefix)? filterOption;

  /// 弹层方向。
  final ElMentionPlacement placement;

  /// 是否显示箭头。
  final bool showArrow;

  /// 弹层与光标锚点的主轴间距。
  final double offset;

  /// 是否启用 Backspace 删除完整 Mention。
  final bool whole;

  /// 自定义完整 Mention 判定。
  final bool Function(String pattern, String prefix)? checkIsWhole;

  /// 是否显示加载状态。
  final bool loading;

  /// 面板打开后是否默认高亮第一个可用候选。
  final bool highlightFirst;

  /// 方向键到达边界后是否循环。
  final bool loop;

  /// pattern 或 prefix 变化后的查询通知。
  final void Function(String pattern, String prefix)? onSearch;

  /// 用户选择可用候选后的通知。
  final void Function(ElMentionOption<T> option, String prefix)? onSelected;

  /// whole 模式成功删除完整 Mention 后的通知。
  final void Function(String pattern, String prefix)? onWholeRemove;

  /// 自定义候选项内容。
  final Widget Function(BuildContext context, ElMentionOption<T> option, bool active)? itemBuilder;

  /// 加载中的自定义内容。
  final WidgetBuilder? loadingBuilder;

  /// 无候选时的自定义内容。
  final WidgetBuilder? emptyBuilder;

  /// 候选面板头部内容。
  final Widget? header;

  /// 候选面板底部内容。
  final Widget? footer;

  /// 空文本提示。
  final String? placeholder;

  /// 禁用后不挂 Editable、不可聚焦且关闭候选层。
  final bool disabled;

  /// 只读呈现，不打开 Mention 面板或写入候选。
  final bool readOnly;

  /// 是否显示清空按钮。
  final bool clearable;

  /// 最大 UTF-16 code unit 长度；候选提交同样先经 Editable 裁决。
  final int? maxLength;

  /// 是否使用多行 textarea 输入形态。
  final bool textarea;

  /// textarea 最小可见行数。
  final int minLine;

  /// textarea 最大可见行数。
  final int? maxLine;

  /// 首次挂载后是否自动聚焦。
  final bool autofocus;

  /// 输入框焦点节点。
  final FocusNode? focusNode;

  /// Mention 键盘处理前的调用方拦截器。
  final FocusOnKeyEventCallback? onKeyEvent;

  /// 输入框获得焦点的通知。
  final VoidCallback? onFocus;

  /// 输入框真实失焦的通知。
  final VoidCallback? onBlur;

  /// 清空按钮触发后的通知。
  final VoidCallback? onClear;

  /// 普通输入提交动作的通知。
  final ValueChanged<String>? onSubmitted;

  /// 输入区前置内容，转发到 [ElInput.prefix]。
  final Object? inputPrefix;

  /// 输入区尾随内容，转发到 [ElInput.suffix]。
  final Object? inputSuffix;

  /// Flutter formatter 兼容入口，由 [ElInput] 适配进 Editable 事务。
  final List<TextInputFormatter> inputFormatters;

  /// 平台输入动作回调。
  final ValueChanged<TextInputAction>? onAction;

  /// 平台主动关闭输入连接后的通知。
  final VoidCallback? onConnectionClosed;

  /// Android IME 私有命令。
  final void Function(String action, Map<String, dynamic> data)? onPrivateCommand;

  /// iOS 浮动光标事件。
  final ValueChanged<RawFloatingCursorPoint>? onFloatingCursor;

  /// iOS 自动更正提示范围。
  final ValueChanged<TextRange>? onAutocorrectionPromptRect;

  /// 平台请求显示编辑工具栏。
  final VoidCallback? onShowToolbar;

  /// Scribble 文本占位变化。
  final ValueChanged<Size?>? onTextPlaceholderChanged;

  /// macOS 标准键绑定 selector。
  final ValueChanged<String>? onSelector;

  /// 无法解码为纯文本的键盘插入内容。
  final ValueChanged<KeyboardInsertedContent>? onUnhandledContent;

  /// 平台输入控件切换通知。
  final void Function(TextInputControl? oldControl, TextInputControl? newControl)? onInputControlChanged;

  /// IME 动作键。
  final TextInputAction? textInputAction;

  /// 平台软键盘类型。
  final TextInputType? keyboardType;

  /// IME 动作键自定义标签。
  final String? actionLabel;

  /// 软键盘亮暗外观。
  final Brightness keyboardAppearance;

  /// 平台自动大小写策略。
  final TextCapitalization textCapitalization;

  /// 平台智能破折号策略。
  final SmartDashesType? smartDashesType;

  /// 平台智能引号策略。
  final SmartQuotesType? smartQuotesType;

  /// 是否启用平台自动更正。
  final bool autocorrect;

  /// 是否启用平台候选建议。
  final bool enableSuggestions;

  /// 是否允许平台输入控件发起交互式选区动作。
  final bool enableInteractiveSelection;

  /// 是否允许 IME 学习输入。
  final bool enableIMEPersonalizedLearning;

  /// 允许 commit-content 注入的 MIME 类型。
  final List<String> allowedMimeTypes;

  /// 提示 IME 优先使用的语言区域列表。
  final List<Locale> hintLocales;

  /// 是否请求平台内联预测。
  final bool? enableInlinePrediction;

  /// 平台自动填充类型提示；null 禁用。
  final Iterable<String>? autofillHints;

  /// 输入框宽度；null 时使用 240。
  final double? width;

  /// 候选面板宽度。
  final double panelWidth;

  /// 候选面板最大高度。
  final double menuHeight;

  /// 候选列表滚动控制器；null 时组件内部创建并管理。
  final ScrollController? scrollController;

  /// 旧层级兼容参数；浮层顺序由官方 Portal 的打开顺序决定。
  final int zIndex;

  /// 正文、placeholder 与 caret 的水平对齐。
  final TextAlign? textAlign;

  /// 输入框样式覆盖。
  final ElStyle? style;

  /// 候选面板样式覆盖。
  final ElStyle? panelStyle;

  /// 候选项样式覆盖。
  final ElStyle? optionStyle;

  /// 输入框无障碍标签。
  final String? semanticLabel;

  /// 当前值；也可由品牌实现接入祖先表单字段。
  final String? value;

  /// 外部双向绑定，生命周期由调用方管理。
  final ValueNotifier<String>? modelValue;

  /// 用户修改已确认值后的通知。
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.mention)(context, this);
}
