import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/foundation.dart' show ValueChanged, VoidCallback, immutable;
import 'package:flutter/services.dart'
    show
        KeyboardInsertedContent,
        RawFloatingCursorPoint,
        SmartDashesType,
        SmartQuotesType,
        TextCapitalization,
        TextInputAction,
        TextInputControl,
        TextInputType,
        TextRange;
import 'package:flutter/widgets.dart'
    show Brightness, Color, EdgeInsets, FocusOnKeyEventCallback, Locale, ScrollPhysics, Size, TextAlign, TextStyle;

import '../selection/common/selection_core.dart' show SelectionControls;
import 'composer.dart' show EditableComposer;
import 'line_height.dart' show EditableLineHeightMode;

/// 可编辑视图除实例所有权对象之外的完整样式与行为声明。
///
/// 正文排版、光标、选区以及编辑行为、命令、滚动、IME、selection chrome
/// 和平台通知统一放在一个值对象中；控制器、焦点节点与滚动控制器仍由
/// `ElEditableView` 顶层持有，以保留清晰的生命周期和所有权。
@immutable
final class EditableConfiguration {
  /// 创建普通输入形态的完整样式与行为声明。
  const EditableConfiguration({
    this.composer = EditableComposer.plain,
    this.textStyle,
    this.textAlign = TextAlign.start,
    this.lineHeightMode = EditableLineHeightMode.content,
    this.caretColor,
    this.caretWidth = 1.5,
    this.caretAnimationDuration = const Duration(milliseconds: 80),
    this.selectionColor,
    this.selectionTextColor,
    this.retainSelectionOnBlur = false,
    this.composingUnderline = true,
    this.softWrap = true,
    this.contentPadding = EdgeInsets.zero,
    this.readOnly = false,
    this.selectAllRevealsCaret = true,
    this.autofocus = false,
    this.obscureText = false,
    this.obscuringCharacter = '•',
    this.semanticLabel,
    this.onKeyEvent,
    this.onAction,
    this.scrollPhysics,
    this.scrollbars = true,
    this.cacheExtent = 500,
    this.keyboardType,
    this.textInputAction,
    this.actionLabel,
    this.keyboardAppearance = .light,
    this.textCapitalization = .none,
    this.smartDashesType,
    this.smartQuotesType,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.enableIMEPersonalizedLearning = true,
    this.allowedMimeTypes = const <String>[],
    this.hintLocales = const <Locale>[],
    this.enableInlinePrediction,
    this.autofillHints,
    this.autofillHintText,
    @internal this.selectionControls,
    this.enableInteractiveSelection = true,
    this.enabledSelectionHandles = true,
    this.enabledMagnifier = true,
    this.enabledSelectionToolbar = true,
    this.enabledContextMenu = true,
    this.onConnectionClosed,
    this.onPrivateCommand,
    this.onFloatingCursor,
    this.onAutocorrectionPromptRect,
    this.onShowToolbar,
    this.onTextPlaceholderChanged,
    this.onSelector,
    this.onUnhandledContent,
    this.onInputControlChanged,
  }) : assert(caretWidth > 0, 'caretWidth 必须大于 0'),
       assert(obscuringCharacter.length == 1, 'obscuringCharacter 必须是单 code unit');

  /// 行装配器（语法高亮与富文本扩展点）。
  final EditableComposer composer;

  /// 正文基础样式；未声明前景时继承最近 ElView 的文本色，未指定行距分布时采用 CSS half-leading。
  final TextStyle? textStyle;

  /// 文本在每条视觉行可用宽度内的水平对齐方式。
  final TextAlign textAlign;

  /// 视觉行使用固定根样式度量，或允许内容 run 撑高。
  final EditableLineHeightMode lineHeightMode;

  /// 光标颜色；null 表示跟随正文颜色或内核缺省色。
  final Color? caretColor;

  /// 普通插入光标的逻辑像素宽度，默认 1.5 DIP。
  final double caretWidth;

  /// 主光标位置过渡时长；默认对齐 VS Code 的 80ms，零表示即时切换。
  final Duration caretAnimationDuration;

  /// 选区底色；null 优先继承最近 ElView 的 onSelection.bgColor，再回退内核缺省色。
  final Color? selectionColor;

  /// 选区文字色；null 优先继承最近 ElView 的 onSelection.color，未声明则保留 composer 前景。
  final Color? selectionTextColor;

  /// 失焦后是否继续显示选区高亮；默认关闭，编辑器预设开启，不改写模型选区。
  final bool retainSelectionOnBlur;

  /// 是否绘制输入法组合文本下划线。
  final bool composingUnderline;

  /// 是否自动换行；false 时使用双轴滚动。
  final bool softWrap;

  /// 滚动内容坐标系中的内边距，仍属于可聚焦、可命中的编辑区域，并作为
  /// caret 自动 reveal 相对物理 viewport 的可见缓冲。
  final EdgeInsets contentPadding;

  /// 是否只读；只读仅呈现正文，不聚焦或显示内部光标/选区。
  ///
  /// 需要文档选中与复制时，在编辑器外层包裹 `ElSelectionView`。
  final bool readOnly;

  /// 全选（Ctrl+A / Cmd+A）后是否把光标与视口 reveal 到文档末尾；
  /// 单行输入与 textarea 默认 true 保持跳转，代码编辑器传 false 让
  /// 视口停留在原地（对齐主流编辑器行为）。
  final bool selectAllRevealsCaret;

  /// 首次挂载后是否自动请求焦点并连接输入法。
  final bool autofocus;

  /// 是否以密码掩码绘制并禁用复制、剪切。
  final bool obscureText;

  /// 密码掩码字符，必须是单个 UTF-16 code unit。
  final String obscuringCharacter;

  /// 无障碍文本框标签。
  final String? semanticLabel;

  /// 默认键盘处理之前的按键拦截器。
  final FocusOnKeyEventCallback? onKeyEvent;

  /// 平台输入动作通知。
  final ValueChanged<TextInputAction>? onAction;

  /// 缩进、词边界、剪贴板、拖放与多光标行为。

  /// 主轴滚动物理；null 表示使用滚动视图的平台默认。
  final ScrollPhysics? scrollPhysics;

  /// 是否显示平台滚动条，形制由环境 ScrollBehavior 决定。
  final bool scrollbars;

  /// 虚拟视口在可见区前后保留的逻辑像素范围。
  final double cacheExtent;

  /// 平台键盘类型；null 时按控制器的单行状态解析。
  final TextInputType? keyboardType;

  /// 平台动作键；null 时按控制器的单行状态解析。
  final TextInputAction? textInputAction;

  /// 平台动作键的自定义标签。
  final String? actionLabel;

  /// 软键盘亮暗外观。
  final Brightness keyboardAppearance;

  /// 平台自动大小写策略。
  final TextCapitalization textCapitalization;

  /// 平台智能破折号策略。
  final SmartDashesType? smartDashesType;

  /// 平台智能引号策略。
  final SmartQuotesType? smartQuotesType;

  /// 是否向平台输入法请求自动更正。
  final bool autocorrect;

  /// 是否向平台输入法请求候选建议。
  final bool enableSuggestions;

  /// 是否允许输入法学习用户输入。
  final bool enableIMEPersonalizedLearning;

  /// 允许键盘通过 commit-content 注入的 MIME 类型；传入后必须按不可变列表使用。
  final List<String> allowedMimeTypes;

  /// 提示输入法优先使用的语言区域列表；传入后必须按不可变列表使用。
  final List<Locale> hintLocales;

  /// 是否请求平台内联预测；null 表示使用平台默认策略。
  final bool? enableInlinePrediction;

  /// 平台自动填充类型提示；null 禁用，非 null 必须是有限且稳定的不可变序列。
  final Iterable<String>? autofillHints;

  /// 提供给自动填充服务的可见占位提示。
  final String? autofillHintText;

  /// 实例级选区 chrome；null 时按全局表与平台默认解析。
  @internal
  final SelectionControls? selectionControls;

  /// 是否允许平台与指针发起交互式选区动作。
  final bool enableInteractiveSelection;

  /// 是否启用移动端选区句柄。
  final bool enabledSelectionHandles;

  /// 是否启用移动端选区放大镜。
  final bool enabledMagnifier;

  /// 是否启用移动端选区工具条。
  final bool enabledSelectionToolbar;

  /// 是否启用桌面端右键上下文菜单。
  final bool enabledContextMenu;

  /// 平台主动关闭输入连接后的通知。
  final VoidCallback? onConnectionClosed;

  /// Android 输入法私有命令通知。
  final void Function(String action, Map<String, dynamic> data)? onPrivateCommand;

  /// iOS 浮动光标通知。
  final ValueChanged<RawFloatingCursorPoint>? onFloatingCursor;

  /// iOS 自动更正提示范围通知。
  final ValueChanged<TextRange>? onAutocorrectionPromptRect;

  /// 平台请求显示编辑工具栏的通知。
  final VoidCallback? onShowToolbar;

  /// Scribble 文本占位变化通知。
  final ValueChanged<Size?>? onTextPlaceholderChanged;

  /// macOS 标准键绑定 selector 观察通知。
  final ValueChanged<String>? onSelector;

  /// 无法由内核解码为纯文本的键盘插入内容通知。
  final ValueChanged<KeyboardInsertedContent>? onUnhandledContent;

  /// 平台输入控件切换通知。
  final void Function(TextInputControl? oldControl, TextInputControl? newControl)? onInputControlChanged;
}
