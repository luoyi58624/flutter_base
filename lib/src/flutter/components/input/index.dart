import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 公共输入框声明，编辑、值绑定与外观由全局组件主题提供。
class ElInput extends StatelessWidget {
  /// 创建输入框，并按表单、响应式或受控参数自动选择数据绑定通道。
  const ElInput({
    super.key,
    this.value,
    this.modelValue,
    this.onChanged,
    this.placeholder,
    this.disabled = false,
    this.readOnly = false,
    this.clearable = false,
    this.showPassword = false,
    this.maxLength,
    this.inputFormatters = const [],
    this.showWordLimit = false,
    this.prefix,
    this.suffix,
    this.autofocus = false,
    this.focusNode,
    this.control,
    this.onKeyEvent,
    this.onFocus,
    this.onBlur,
    this.onSubmitted,
    this.onClear,
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
    this.semanticLabel,
    this.caretColor,
    this.textAlign,
    this.style,
    this.placeholderStyle,
    this.affixStyle,
    this.actionStyle,
    this.width,
    this.textarea = false,
    this.minLine = 3,
    this.maxLine,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥，二选一'),
       assert(minLine >= 1),
       assert(maxLine == null || maxLine >= minLine, 'maxLine 不得小于 minLine');

  /// 初始文本；重建时同步新值，Element 也可由祖先表单字段提供值。
  final String? value;

  /// 外部双向绑定，生命周期由调用方管理。
  final ValueNotifier<String>? modelValue;

  /// 已确认文本变化时回调，IME 组字期间不回传候选文本。
  final ValueChanged<String>? onChanged;

  /// 是否接入品牌表单；复合字段的内部输入可覆写为 false，避免重复绑定。
  bool get formBindable => true;

  /// 空值时显示的提示文字。
  final String? placeholder;

  /// 禁用后不可交互，不进入 Tab 焦点链。
  final bool disabled;

  /// 只读呈现，不进入编辑焦点链且不显示清除动作；跨文本选择由外层选区提供。
  final bool readOnly;

  /// 显示清除动作。
  final bool clearable;

  /// 密码框：掩码显示 + 眼睛切换明文；copy/cut 被内核拦截。
  final bool showPassword;

  /// 最大长度（UTF-16 code unit 计），内核截断输入。
  final int? maxLength;

  /// Flutter 文本 formatter 兼容入口；用户输入会被适配成 editable 原子事务，
  /// 程序性 value/modelValue 回灌不经过本列表。
  final List<TextInputFormatter> inputFormatters;

  /// 显示 `当前/上限` 计数（需 [maxLength]；disabled/readOnly/密码框不显示）。
  final bool showWordLimit;

  /// 前后缀，宽容输入：IconData（跟随有效尺寸档、样式中的 iconColor）或任意
  /// Widget；内容被约束在稳定内联槽中，不会撑高单行输入框。
  final Object? prefix;

  /// 输入框后缀内容。
  final Object? suffix;

  /// 挂载后自动请求焦点。
  final bool autofocus;

  /// 焦点节点；未传时由组件内部管理。
  final FocusNode? focusNode;

  /// 非拥有型控制门面；用于补全、Mention 等上层组件读取 editable 与光标几何。
  final ElInputController? control;

  /// editable 默认键盘处理前的可选拦截器；返回 handled 时不再移动 caret，
  /// 返回 ignored 时回落到输入框默认编辑行为。
  final FocusOnKeyEventCallback? onKeyEvent;

  /// 获得焦点时回调。
  final VoidCallback? onFocus;

  /// 失去焦点时回调。
  final VoidCallback? onBlur;

  /// 提交回调（桌面 Enter / 软键盘 done 族动作），回传当前文本；
  /// 内置行为：收起键盘 + 失焦。
  final ValueChanged<String>? onSubmitted;

  /// 用户点击清除动作后回调。
  final VoidCallback? onClear;

  /// 平台输入动作回调；多行 newline 由内核消化且不触发本回调，单行输入的
  /// [onSubmitted] 在其他动作回调之后收到当前文本。
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

  /// IME 动作键，单行缺省 done（textarea 恒 newline）。
  final TextInputAction? textInputAction;

  /// 平台键盘输入类型。
  final TextInputType? keyboardType;

  /// IME 动作键的自定义标签。
  final String? actionLabel;

  /// 软键盘亮暗外观。
  final Brightness keyboardAppearance;

  /// 平台自动大小写策略。
  final TextCapitalization textCapitalization;

  /// 平台智能破折号策略。
  final SmartDashesType? smartDashesType;

  /// 平台智能引号策略。
  final SmartQuotesType? smartQuotesType;

  /// 是否启用平台自动更正；密码形态始终关闭。
  final bool autocorrect;

  /// 是否启用平台候选建议；密码形态始终关闭。
  final bool enableSuggestions;

  /// 是否允许平台输入控件发起交互式选区动作。
  final bool enableInteractiveSelection;

  /// 是否允许 IME 学习输入；密码形态始终关闭。
  final bool enableIMEPersonalizedLearning;

  /// 允许 commit-content 注入的 MIME 类型；非 text/plain 需同时提供
  /// [onUnhandledContent]。
  final List<String> allowedMimeTypes;

  /// 提示 IME 优先使用的语言区域列表。
  final List<Locale> hintLocales;

  /// 是否请求平台内联预测。
  final bool? enableInlinePrediction;

  /// 平台自动填充类型提示；null 禁用，空列表启用但不指定字段类型。
  final Iterable<String>? autofillHints;

  /// 辅助技术读取的输入框名称。
  final String? semanticLabel;

  /// 光标颜色；null 时跟随完整正文样式。Select 等只读复合触发器可显式透明，
  /// 不影响焦点环、键盘导航与可过滤形态。
  final Color? caretColor;

  /// 正文、placeholder 与 caret 的水平对齐；null 时读取 [style] 的
  /// `textAlign`，再回落到 [TextAlign.start]。
  final TextAlign? textAlign;

  /// 外观覆盖，merge 在默认样式之上。
  final ElStyle? style;

  /// 占位文字样式，在品牌默认样式之后合并。
  final ElStyle? placeholderStyle;

  /// 前后缀槽样式，在品牌默认样式之后合并。
  final ElStyle? affixStyle;

  /// 清除和密码切换按钮样式，支持悬停、按下等状态。
  final ElStyle? actionStyle;

  /// 输入框宽度，未指定时采用品牌默认宽度；style.width 可进一步覆盖。
  final double? width;

  /// 多行文本域形态：softWrap + 按内容行数自动增高 + 超限内滚动。开启后
  /// showPassword / 前后缀 / onSubmitted / textInputAction 等单行槽位自动
  /// 失效；clearable 照常（清除图标同单行右侧槽位、对齐首行）。
  final bool textarea;

  /// textarea 最小可见行数（自动增高的下限），仅 [textarea] 生效。
  final int minLine;

  /// textarea 最大可见行数（增长上限，超出内滚动）；null 不封顶。仅 [textarea] 生效。
  final int? maxLine;

  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.inputBuilder)(context, this);
}

/// 输入框控制门面：只引用已挂载的 ElInput，不创建或销毁底层编辑对象。
class ElInputController extends ChangeNotifier {
  /// 创建一个可传给 [ElInput.control] 的非拥有型控制器。
  ElInputController();

  Object? _owner;
  ElEditableController? _controller;
  FocusNode? _focusNode;
  bool _notifyScheduled = false;
  bool _disposed = false;

  /// 是否已经被某个 [ElInput] 挂载；禁用态也算挂载但没有 editable。
  bool get attached => _owner != null;

  /// 当前输入框内部的 editable 文本控制器；禁用或未挂载时为 null。
  ElEditableController? get controller => _controller;

  /// 当前输入框内部的焦点节点；禁用或未挂载时为 null。
  FocusNode? get focusNode => _focusNode;

  /// 当前输入框是否持有焦点；禁用或未挂载时恒为 false。
  bool get hasFocus => _focusNode?.hasFocus ?? false;

  /// 请求输入框聚焦；禁用、未挂载或节点不可聚焦时返回 false。
  bool focus() {
    final node = _focusNode;
    if (node == null || !node.canRequestFocus) return false;
    node.requestFocus();
    return true;
  }

  /// 释放输入框焦点；未挂载或禁用时返回 false。
  bool blur({UnfocusDisposition disposition = UnfocusDisposition.scope}) {
    final node = _focusNode;
    if (node == null) return false;
    node.unfocus(disposition: disposition);
    return true;
  }

  /// 清空当前文本并把光标收敛到开头；无 editable 时返回 false。
  bool clear() {
    final controller = _controller;
    if (controller == null) return false;
    controller.replaceRange(0, controller.length, '', selection: const TextSelection.collapsed(offset: 0));
    return true;
  }

  /// 选中全部文本；无 editable 时返回 false。
  bool selectAll() {
    final controller = _controller;
    if (controller == null) return false;
    controller.setSelection(TextSelection(baseOffset: 0, extentOffset: controller.length));
    return true;
  }

  /// 供主题实现挂载编辑对象；owner 必须在组件生命周期内保持唯一且稳定。
  void attach({required Object owner, required ElEditableController? controller, required FocusNode? focusNode}) {
    if (_disposed) throw StateError('已释放的 ElInputController 不能再次挂载到 ElInput。');
    final current = _owner;
    if (current != null && !identical(current, owner)) {
      throw StateError('同一个 ElInputController 不能同时挂载到多个 ElInput。');
    }
    var changed = current == null;
    _owner = owner;
    if (!identical(_focusNode, focusNode)) {
      _focusNode?.removeListener(_handleFocusChanged);
      _focusNode = focusNode;
      _focusNode?.addListener(_handleFocusChanged);
      changed = true;
    }
    if (!identical(_controller, controller)) {
      _controller = controller;
      changed = true;
    }
    if (changed) _markChanged();
  }

  /// 供主题实现卸载编辑对象；仅当前 owner 可以解除挂载。
  void detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _focusNode?.removeListener(_handleFocusChanged);
    _owner = null;
    _controller = null;
    _focusNode = null;
    _markChanged();
  }

  void _handleFocusChanged() => _markChanged();

  void _markChanged() {
    if (_disposed || _notifyScheduled) return;
    _notifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    if (_owner != null) {
      throw StateError('ElInputController 仍挂载在 ElInput 上，必须先卸载对应输入框再 dispose。');
    }
    _disposed = true;
    _focusNode?.removeListener(_handleFocusChanged);
    _owner = null;
    _controller = null;
    _focusNode = null;
    super.dispose();
  }
}
