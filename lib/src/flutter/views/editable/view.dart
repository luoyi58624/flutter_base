import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../scroll/scroll_view.dart';
import '../selection/common/selection_core.dart';
import '../view/event/event.dart';
import '../view/view.dart';
import 'composer.dart';
import 'controller.dart';
import 'controller_adapter.dart';
import 'editable_controller.dart';
import 'editable_style.dart';
import 'editable_view.dart';
import 'projection/editable_hidden_areas_model.dart';
import 'style.dart';

/// 编辑文字，处理光标、选区和滚动；外观与编辑配置使用 [ElEditableStyle]。
class ElEditableView extends StatefulWidget {
  /// 创建文本编辑视图，未传控制器时自动管理其生命周期。
  const ElEditableView({
    super.key,
    this.controller,
    this.focusNode,
    this.event,
    this.style = const ElEditableStyle(),
    this.scrollController,
    this.horizontalScrollController,
    this.onAction,
    this.onKeyEvent,
    this.onViewChanged,
    this.textSpanBuilder,
    this.foregroundPainter,
    this.hiddenLines,
    this.onInsertNewline,
    this.onConnectionClosed,
    this.onPrivateCommand,
    this.onFloatingCursor,
    this.onAutocorrectionPromptRect,
    this.onShowToolbar,
    this.onTextPlaceholderChanged,
    this.onSelector,
    this.selectorHandler,
    this.wordBoundary,
    @internal this.selectionActions,
    this.onUnhandledContent,
    this.onInputControlChanged,
  });

  /// 文本与视口控制器。
  final ElEditableController? controller;

  /// 基础输入动作前的事件处理，preventDefault 可接管本次动作。
  final ElEvent? event;

  /// 焦点节点。
  final FocusNode? focusNode;

  /// 组合样式与编辑配置；正文沿 view 接入祖先 ElView 级联。
  final ElEditableStyle style;

  /// 垂直滚动控制器。
  final ElScrollController? scrollController;

  /// 不换行时的水平滚动控制器。
  final ScrollController? horizontalScrollController;

  /// 平台动作键回调。
  final ValueChanged<TextInputAction>? onAction;

  /// 基础键盘处理前的按键回调。
  final FocusOnKeyEventCallback? onKeyEvent;

  /// 挂载和卸载通知，卸载时传 null。
  final ValueChanged<ElEditableController?>? onViewChanged;

  /// 按需装配当前文字窗口；返回内容必须保持原文不变。
  final InlineSpan Function({
    required int line,
    required String text,
    required TextStyle style,
    required int start,
    required int lineLength,
  })?
  textSpanBuilder;

  /// 使用当前行的真实文字几何绘制前景。
  final void Function(
    Canvas canvas,
    Offset offset, {
    required int line,
    required int lineLength,
    required TextRange visibleRange,
    required TextStyle style,
    required TextDirection textDirection,
    required double lineHeight,
    required double originX,
    required Size size,
    required List<Rect> Function(TextRange) rects,
    required Rect Function(TextPosition, {double widthInCharacters}) characterCell,
  })?
  foregroundPainter;

  /// 上层已计算的隐藏行范围，使用从零开始的半开区间。
  final ValueListenable<List<TextRange>>? hiddenLines;

  /// 上层处理平台 selector，返回 true 表示已执行。
  final bool Function(String)? selectorHandler;

  /// 上层提供的词边界，用于点选和拖选。
  final TextRange Function(TextPosition)? wordBoundary;

  /// 上层提供的剪贴板与全选动作，视图仍应用只读和密码限制。
  @internal
  final SelectionActions Function()? selectionActions;

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

  /// 上层可接管换行输入，例如在代码编辑器中延续缩进。
  final VoidCallback? onInsertNewline;

  @override
  State<ElEditableView> createState() => _EditableHostState();
}

class _EditableHostState extends State<ElEditableView> {
  late ElEditableController _controller;
  late EditableController _model;
  EditableLineMask? _projection;
  int _bindingGeneration = 0;
  ElEditableController? _reportedController;
  late void Function(EditableViewport?) _handleView;
  _SpanBuilder? _composer;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _controller = widget.controller ?? ElEditableController();
    final controller = _controller;
    final generation = ++_bindingGeneration;
    _handleView = (viewport) {
      if (!mounted || generation != _bindingGeneration) return;
      controller.bindEditableViewport(viewport);
      final reported = viewport == null ? null : controller;
      if (identical(_reportedController, reported)) return;
      _reportedController = reported;
      widget.onViewChanged?.call(reported);
    };
    _model = _controller is EditableController
        ? _controller as EditableController
        : EditableControllerAdapter(_controller);
    if (widget.hiddenLines != null) {
      _projection = EditableLineMask(_model);
      widget.hiddenLines!.addListener(_updateProjection);
      _updateProjection();
    }
  }

  void _updateProjection() {
    _projection?.update(widget.hiddenLines!.value);
  }

  void _detach(ElEditableView previous) {
    _bindingGeneration++;
    final wasReported = _reportedController != null;
    final callback = previous.onViewChanged;
    _reportedController = null;
    if (wasReported && callback != null) WidgetsBinding.instance.addPostFrameCallback((_) => callback(null));
    previous.hiddenLines?.removeListener(_updateProjection);
    final projection = _projection;
    final controller = _controller;
    final model = _model;
    _projection = null;
    controller.bindEditableViewport(null);
    // 子视图先解除 IME 和绘制监听，再释放其借用的内核对象。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      projection?.dispose();
      if (model is EditableControllerAdapter) model.dispose();
      if (previous.controller == null) controller.dispose();
    });
  }

  @override
  void didUpdateWidget(ElEditableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller || oldWidget.hiddenLines != widget.hiddenLines) {
      _detach(oldWidget);
      _attach();
    } else if (oldWidget.onViewChanged != widget.onViewChanged && _reportedController != null) {
      final previous = oldWidget.onViewChanged;
      final next = widget.onViewChanged;
      final controller = _controller;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        previous?.call(null);
        if (mounted && identical(widget.onViewChanged, next) && identical(_reportedController, controller)) {
          next?.call(controller);
        }
      });
    }
  }

  @override
  void dispose() {
    _detach(widget);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final input = widget.style.inputConfiguration;
    if (_composer?.builder != widget.textSpanBuilder || _composer?.painter != widget.foregroundPainter) {
      _composer = _SpanBuilder(widget.textSpanBuilder, widget.foregroundPainter);
    }
    final config = EditableConfiguration(
      softWrap: widget.style.softWrap,
      contentPadding: widget.style.contentPadding,
      readOnly: widget.style.readOnly,
      autofocus: widget.style.autofocus,
      obscureText: widget.style.obscureText,
      obscuringCharacter: widget.style.obscuringCharacter,
      caretColor: widget.style.caretColor,
      caretWidth: widget.style.caretWidth,
      caretAnimationDuration: widget.style.caretAnimationDuration,
      selectionColor: widget.style.selectionColor,
      selectionTextColor: widget.style.selectionTextColor,
      retainSelectionOnBlur: widget.style.retainSelectionOnBlur,
      selectAllRevealsCaret: widget.style.selectAllRevealsCaret,
      composingUnderline: widget.style.composingUnderline,
      lineHeightMode: widget.style.fixedLineHeight ? .fixed : .content,
      scrollPhysics: widget.style.scrollPhysics,
      scrollbar: widget.style.scrollbar,
      cacheExtent: widget.style.cacheExtent,
      keyboardType: input?.inputType,
      textInputAction: input?.inputAction,
      actionLabel: input?.actionLabel,
      keyboardAppearance: input?.keyboardAppearance ?? .light,
      textCapitalization: input?.textCapitalization ?? .none,
      smartDashesType: input?.smartDashesType,
      smartQuotesType: input?.smartQuotesType,
      autocorrect: input?.autocorrect ?? true,
      enableSuggestions: input?.enableSuggestions ?? true,
      enableIMEPersonalizedLearning: input?.enableIMEPersonalizedLearning ?? true,
      allowedMimeTypes: input?.allowedMimeTypes ?? const [],
      hintLocales: input?.hintLocales ?? const [],
      enableInlinePrediction: input?.enableInlinePrediction,
      autofillHints: input?.autofillConfiguration.enabled == true ? input!.autofillConfiguration.autofillHints : null,
      autofillHintText: input?.autofillConfiguration.hintText,
      selectionControls: widget.style.selectionControls,
      enableInteractiveSelection: widget.style.enableInteractiveSelection,
      enabledSelectionHandles: widget.style.enabledSelectionHandles,
      enabledMagnifier: widget.style.enabledMagnifier,
      enabledSelectionToolbar: widget.style.enabledSelectionToolbar,
      enabledContextMenu: widget.style.enabledContextMenu,
      onAction: widget.onAction,
      onKeyEvent: widget.onKeyEvent,
      semanticLabel: widget.style.semanticLabel,
      onConnectionClosed: widget.onConnectionClosed,
      onPrivateCommand: widget.onPrivateCommand,
      onFloatingCursor: widget.onFloatingCursor,
      onAutocorrectionPromptRect: widget.onAutocorrectionPromptRect,
      onShowToolbar: widget.onShowToolbar,
      onTextPlaceholderChanged: widget.onTextPlaceholderChanged,
      onSelector: widget.onSelector,
      onUnhandledContent: widget.onUnhandledContent,
      onInputControlChanged: widget.onInputControlChanged,

      composer: widget.textSpanBuilder == null && widget.foregroundPainter == null
          ? EditableComposer.plain
          : _composer!,
    );
    return ElView(
      style: widget.style.view,
      child: EditableView(
        controller: _model,
        hiddenAreas: _projection,
        focusNode: widget.focusNode,
        style: config,
        event: widget.event,
        selectorHandler: widget.selectorHandler,
        wordBoundary: widget.wordBoundary,
        selectionActions: widget.selectionActions,
        scrollController: widget.scrollController,
        horizontalScrollController: widget.horizontalScrollController,
        onStateChanged: _handleView,
        onInsertNewline: widget.onInsertNewline,
        tabSize: widget.style.tabSize,
        inheritTextAlign: true,
      ),
    );
  }
}

final class _SpanBuilder extends EditableComposer implements EditableWindowedComposer, EditableCanvasComposer {
  const _SpanBuilder(this.builder, this.painter);
  final InlineSpan Function({
    required int line,
    required String text,
    required TextStyle style,
    required int start,
    required int lineLength,
  })?
  builder;
  final void Function(
    Canvas canvas,
    Offset offset, {
    required int line,
    required int lineLength,
    required TextRange visibleRange,
    required TextStyle style,
    required TextDirection textDirection,
    required double lineHeight,
    required double originX,
    required Size size,
    required List<Rect> Function(TextRange) rects,
    required Rect Function(TextPosition, {double widthInCharacters}) characterCell,
  })?
  painter;
  @override
  InlineSpan compose(EditableLineContext context) =>
      builder?.call(
        line: context.line,
        text: context.text,
        style: context.baseStyle,
        start: context.textStart,
        lineLength: context.lineLength,
      ) ??
      TextSpan(text: context.text, style: context.baseStyle);
  @override
  void paintForeground(
    Canvas canvas,
    Offset offset, {
    required int line,
    required int lineLength,
    required TextRange visibleRange,
    required TextStyle style,
    required TextDirection textDirection,
    required double lineHeight,
    required double originX,
    required Size size,
    required List<Rect> Function(TextRange) rects,
    required Rect Function(TextPosition, {double widthInCharacters}) characterCell,
  }) => painter?.call(
    canvas,
    offset,
    line: line,
    lineLength: lineLength,
    visibleRange: visibleRange,
    style: style,
    textDirection: textDirection,
    lineHeight: lineHeight,
    originX: originX,
    size: size,
    rects: rects,
    characterCell: characterCell,
  );
}
