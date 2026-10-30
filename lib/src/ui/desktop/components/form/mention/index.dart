import 'dart:async' show scheduleMicrotask, Timer;
import 'dart:math' as math;

import 'package:flutter_base/flutter_base.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../app/index.dart';
import '../../../extensions/el.dart';

part 'panel.dart';

class _ResolvedMentionOption<T> {
  const _ResolvedMentionOption({
    required this.source,
    required this.index,
    required this.label,
  });

  final ElMentionOption<T> source;
  final int index;
  final String label;
}

List<_ResolvedMentionOption<T>> _resolveMentionOptions<T>(
  Iterable<ElMentionOption<T>> source,
) {
  final result = <_ResolvedMentionOption<T>>[];
  var index = 0;
  for (final option in source) {
    if (option.value.isEmpty) {
      throw FlutterError('ElMention options[$index].value 必须是非空字符串。');
    }
    final label = option.label == null || option.label!.isEmpty
        ? option.value
        : option.label!;
    result.add(
      _ResolvedMentionOption<T>(source: option, index: index, label: label),
    );
    index++;
  }
  return result;
}

/// 基于 [ElInput] 与 [ElPortal] 的 Mention 输入框。
///
/// 文本、IME、选区、Autofill 与输入拦截全部由内部唯一 [ElInput] 的
/// [ElEditableView] 承接；本组件只读取 editable 光标上下文，在光标处锚定候选
/// 面板，并用 command 事务替换当前 Mention pattern。
///
/// Element 提及输入框主题实现：只服务 [ElementPlusThemeData]，由 barrel 挡住、不经 `element_plus.dart` 导出。
class Mention<T> extends ElInputModelValue<String> {
  Mention(this.component, {super.key})
    : super(
        value: component.value ?? (component.modelValue == null ? '' : null),
        modelValue: component.modelValue,
        onChanged: component.onChanged,
      );

  final ElMention<T> component;

  List<ElMentionOption<T>> get options => component.options;
  List<String> get prefix => component.prefix;
  String get split => component.split;
  Iterable<ElMentionOption<T>> Function(
    Iterable<ElMentionOption<T>> options,
    String pattern,
    String prefix,
  )?
  get filterOptions => component.filterOptions;
  bool Function(ElMentionOption<T> option, String pattern, String prefix)?
  get filterOption => component.filterOption;
  ElMentionPlacement get placement => component.placement;
  bool get showArrow => component.showArrow;
  double get offset => component.offset;
  bool get whole => component.whole;
  bool Function(String pattern, String prefix)? get checkIsWhole =>
      component.checkIsWhole;
  bool get loading => component.loading;
  bool get highlightFirst => component.highlightFirst;
  bool get loop => component.loop;
  void Function(String pattern, String prefix)? get onSearch =>
      component.onSearch;
  void Function(ElMentionOption<T> option, String prefix)? get onSelected =>
      component.onSelected;
  void Function(String pattern, String prefix)? get onWholeRemove =>
      component.onWholeRemove;
  Widget Function(BuildContext context, ElMentionOption<T> option, bool active)?
  get itemBuilder => component.itemBuilder;
  WidgetBuilder? get loadingBuilder => component.loadingBuilder;
  WidgetBuilder? get emptyBuilder => component.emptyBuilder;
  Widget? get header => component.header;
  Widget? get footer => component.footer;
  String? get placeholder => component.placeholder;
  bool get disabled => component.disabled;
  bool get readOnly => component.readOnly;
  bool get clearable => component.clearable;
  int? get maxLength => component.maxLength;
  bool get textarea => component.textarea;
  int get minLine => component.minLine;
  int? get maxLine => component.maxLine;
  bool get autofocus => component.autofocus;
  FocusNode? get focusNode => component.focusNode;
  FocusOnKeyEventCallback? get onKeyEvent => component.onKeyEvent;
  VoidCallback? get onFocus => component.onFocus;
  VoidCallback? get onBlur => component.onBlur;
  VoidCallback? get onClear => component.onClear;
  ValueChanged<String>? get onSubmitted => component.onSubmitted;
  Object? get inputPrefix => component.inputPrefix;
  Object? get inputSuffix => component.inputSuffix;
  List<TextInputFormatter> get inputFormatters => component.inputFormatters;
  ValueChanged<TextInputAction>? get onAction => component.onAction;
  VoidCallback? get onConnectionClosed => component.onConnectionClosed;
  void Function(String action, Map<String, dynamic> data)?
  get onPrivateCommand => component.onPrivateCommand;
  ValueChanged<RawFloatingCursorPoint>? get onFloatingCursor =>
      component.onFloatingCursor;
  ValueChanged<TextRange>? get onAutocorrectionPromptRect =>
      component.onAutocorrectionPromptRect;
  VoidCallback? get onShowToolbar => component.onShowToolbar;
  ValueChanged<Size?>? get onTextPlaceholderChanged =>
      component.onTextPlaceholderChanged;
  ValueChanged<String>? get onSelector => component.onSelector;
  ValueChanged<KeyboardInsertedContent>? get onUnhandledContent =>
      component.onUnhandledContent;
  void Function(TextInputControl? oldControl, TextInputControl? newControl)?
  get onInputControlChanged => component.onInputControlChanged;
  TextInputAction? get textInputAction => component.textInputAction;
  TextInputType? get keyboardType => component.keyboardType;
  String? get actionLabel => component.actionLabel;
  Brightness get keyboardAppearance => component.keyboardAppearance;
  TextCapitalization get textCapitalization => component.textCapitalization;
  SmartDashesType? get smartDashesType => component.smartDashesType;
  SmartQuotesType? get smartQuotesType => component.smartQuotesType;
  bool get autocorrect => component.autocorrect;
  bool get enableSuggestions => component.enableSuggestions;
  bool get enableInteractiveSelection => component.enableInteractiveSelection;
  bool get enableIMEPersonalizedLearning =>
      component.enableIMEPersonalizedLearning;
  List<String> get allowedMimeTypes => component.allowedMimeTypes;
  List<Locale> get hintLocales => component.hintLocales;
  bool? get enableInlinePrediction => component.enableInlinePrediction;
  Iterable<String>? get autofillHints => component.autofillHints;
  double? get width => component.width;
  double get panelWidth => component.panelWidth;
  double get menuHeight => component.menuHeight;
  ScrollController? get scrollController => component.scrollController;
  int get zIndex => component.zIndex;
  TextAlign? get textAlign => component.textAlign;
  ElStyle? get style => component.style;
  ElStyle? get panelStyle => component.panelStyle;
  ElStyle? get optionStyle => component.optionStyle;
  String? get semanticLabel => component.semanticLabel;

  @override
  Widget obsBuilder(BuildContext context) {
    void updateValue(String next) {
      if ($obs.value == next) return;
      final target = modelValue;
      if (target != null) {
        target.value = next;
      } else {
        $obs.value = next;
      }
    }

    return _MentionBody<T>(
      config: this,
      value: $obs.value,
      onValueChanged: updateValue,
      onBlur: () {
        $formBlurValidate();
        onBlur?.call();
      },
    );
  }
}

class _MentionScrollController extends ScrollController {
  bool _disposeAfterLastDetach = false;

  void disposeWhenDetached() {
    if (!hasClients) {
      dispose();
    } else {
      _disposeAfterLastDetach = true;
    }
  }

  @override
  void detach(ScrollPosition position) {
    super.detach(position);
    if (_disposeAfterLastDetach && !hasClients) dispose();
  }
}

class _MentionBody<T> extends StatefulWidget {
  const _MentionBody({
    required this.config,
    required this.value,
    required this.onValueChanged,
    required this.onBlur,
  });

  final Mention<T> config;
  final String value;
  final ValueChanged<String> onValueChanged;
  final VoidCallback onBlur;

  @override
  State<_MentionBody<T>> createState() => _MentionBodyState<T>();
}

class _MentionBodyState<T> extends State<_MentionBody<T>> {
  final ElPortalController _portal = ElPortalController();
  // Portal 冻结会话入口，候选内容通过独立值通道跟随输入和键盘状态。
  final _panel = ValueNotifier<Widget>(const SizedBox.shrink());
  final ElInputController _inputControl = ElInputController();
  final _MentionScrollController _ownScrollController =
      _MentionScrollController();
  final GlobalKey _triggerKey = GlobalKey(debugLabel: 'ElMention trigger');
  late final FocusNode _ownFocusNode;
  ElEditableController? _listenedController;
  ValueListenable<Rect?>? _listenedCaretGeometry;
  Timer? _exitSettledTimer;
  ElMentionContext? _context;
  var _suggestions = <_ResolvedMentionOption<T>>[];
  int? _activeIndex;
  Offset? _markerOffset;
  bool _portalOpen = false;
  bool _optionPointerActive = false;
  bool _reopenRequested = false;
  bool _focusReported = false;
  bool _evaluationScheduled = false;
  bool _pendingNotifySearch = false;
  bool _committingSuggestion = false;
  bool _suppressMentionUntilImeCommit = false;
  bool _imeCommitReleaseRequested = false;
  bool _imeCompositionObserved = false;
  int _focusBindingEpoch = 0;
  String? _lastSearchKey;

  FocusNode get _focusNode => widget.config.focusNode ?? _ownFocusNode;

  ScrollController get _scrollController =>
      widget.config.scrollController ?? _ownScrollController;

  bool get _canOpen =>
      mounted &&
      !widget.config.disabled &&
      !widget.config.readOnly &&
      _focusNode.hasFocus;

  bool get _canRequestFocus =>
      mounted &&
      !widget.config.disabled &&
      !widget.config.readOnly &&
      _focusNode.context != null &&
      _focusNode.canRequestFocus;

  ElLevelType get _effectiveSize =>
      context.elComponentSize(widget.config.style);

  ElOverlayAnchor get _portalAnchor => ElOverlayAnchor(
    // 有箭头时需要官方 top/bottom 居中；无箭头时按 caret 起点对齐候选面板。
    placement: switch ((widget.config.placement, widget.config.showArrow)) {
      (ElMentionPlacement.top, true) => .top,
      (ElMentionPlacement.top, false) => .topStart,
      (ElMentionPlacement.bottom, true) => .bottom,
      (ElMentionPlacement.bottom, false) => .bottomStart,
    },
    offset: widget.config.offset + (widget.config.showArrow ? 6 : 0),
    matchWidth: false,
  );

  @override
  void initState() {
    super.initState();
    _ownFocusNode = FocusNode(debugLabel: 'ElMention');
    _portal.addListener(_handlePortalChanged);
    _inputControl.addListener(_handleControlChanged);
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(_MentionBody<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.config.focusNode != oldWidget.config.focusNode) {
      (oldWidget.config.focusNode ?? _ownFocusNode).removeListener(
        _handleFocusChanged,
      );
      _focusNode.addListener(_handleFocusChanged);
      final reportBlur = _focusReported;
      final epoch = ++_focusBindingEpoch;
      scheduleMicrotask(() {
        if (!mounted || epoch != _focusBindingEpoch || _focusNode.hasFocus) {
          return;
        }
        _focusReported = false;
        _closePanel(clear: true);
        if (reportBlur) widget.onBlur();
      });
    }
    if (widget.config.disabled || widget.config.readOnly) {
      _closePanel(clear: true);
      if (widget.config.disabled) _focusNode.unfocus();
    } else {
      _scheduleEvaluate(notifySearch: true);
    }
  }

  @override
  void dispose() {
    _exitSettledTimer?.cancel();
    _detachControllerVisuals();
    _focusNode.removeListener(_handleFocusChanged);
    _inputControl.removeListener(_handleControlChanged);
    // 子 ElInput 会在本 State.dispose 之后才 detach，直接 dispose control 会误判为仍被占用。
    _portal
      ..removeListener(_handlePortalChanged)
      ..close()
      ..dispose();
    _panel.dispose();
    _ownScrollController.disposeWhenDetached();
    _ownFocusNode.dispose();
    super.dispose();
  }

  void _handlePortalChanged() {
    if (!mounted) return;
    final open = _portal.isOpen;
    if (_portalOpen == open) return;
    setState(() {
      _portalOpen = open;
      if (!open) {
        _optionPointerActive = false;
        _reopenRequested = false;
        _exitSettledTimer?.cancel();
        _exitSettledTimer = Timer(const Duration(milliseconds: 100), () {
          _exitSettledTimer = null;
          if (!mounted || !_reopenRequested || !_canOpen || _context == null) {
            return;
          }
          _reopenRequested = false;
          _portal.open();
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _ensureActiveVisible(),
          );
        });
      }
    });
  }

  void _handleControlChanged() {
    final nextController = _inputControl.controller;
    final nextCaretGeometry = _inputControl.controller?.caretGeometry;
    var needsEvaluate = false;
    if (!identical(_listenedController, nextController)) {
      _listenedController?.removeListener(_handleEditableVisualChanged);
      _listenedController = nextController;
      _listenedController?.addListener(_handleEditableVisualChanged);
      _resetImeSuppression();
      needsEvaluate = true;
    }
    if (!identical(_listenedCaretGeometry, nextCaretGeometry)) {
      _listenedCaretGeometry?.removeListener(_handleCaretGeometryChanged);
      _listenedCaretGeometry = nextCaretGeometry;
      _listenedCaretGeometry?.addListener(_handleCaretGeometryChanged);
      needsEvaluate = true;
    }
    if (needsEvaluate) _scheduleEvaluate(notifySearch: false);
  }

  void _detachControllerVisuals() {
    _listenedController?.removeListener(_handleEditableVisualChanged);
    _listenedCaretGeometry?.removeListener(_handleCaretGeometryChanged);
    _listenedController = null;
    _listenedCaretGeometry = null;
  }

  void _handleEditableVisualChanged() {
    final composing =
        _inputControl.controller?.hasActiveImeComposition ?? false;
    if (composing) {
      _markImeComposing();
      _closePanel(clear: true);
      return;
    }
    if (_suppressMentionUntilImeCommit && _imeCompositionObserved) {
      _imeCommitReleaseRequested = true;
      _imeCompositionObserved = false;
    }
    if (_suppressMentionUntilImeCommit && !_imeCommitReleaseRequested) {
      _closePanel(clear: true);
      return;
    }
    _scheduleEvaluate(notifySearch: true);
  }

  void _handleCaretGeometryChanged() {
    if (!_updateMarkerFromCaret(closeWhenUnavailable: true)) return;
    if (_portal.isOpen) setState(() {});
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      if (!_focusReported) {
        _focusReported = true;
        widget.config.onFocus?.call();
      }
      _scheduleEvaluate(notifySearch: true);
      return;
    }
    _resetImeSuppression();
    if (_optionPointerActive && _portal.isOpen) {
      scheduleMicrotask(() {
        if (_canRequestFocus) _focusNode.requestFocus();
      });
      return;
    }
    final reportBlur = _focusReported;
    _focusReported = false;
    final epoch = _focusBindingEpoch;
    scheduleMicrotask(() {
      scheduleMicrotask(() {
        if (!mounted || epoch != _focusBindingEpoch) return;
        if (!_focusNode.hasFocus) _closePanel(clear: true);
        if (reportBlur) widget.onBlur();
      });
    });
  }

  void _scheduleEvaluate({required bool notifySearch}) {
    _pendingNotifySearch = _pendingNotifySearch || notifySearch;
    if (_evaluationScheduled) return;
    _evaluationScheduled = true;
    scheduleMicrotask(() {
      _evaluationScheduled = false;
      if (!mounted) return;
      final notify = _pendingNotifySearch;
      _pendingNotifySearch = false;
      _evaluateMention(notifySearch: notify);
    });
  }

  void _evaluateMention({required bool notifySearch}) {
    if (_committingSuggestion) return;
    final controller = _inputControl.controller;
    if (!_canOpen || controller == null) {
      _resetImeSuppression();
      _closePanel(clear: true);
      return;
    }
    if (controller.hasActiveImeComposition) {
      _markImeComposing();
      _closePanel(clear: true);
      return;
    }
    if (_suppressMentionUntilImeCommit) {
      if (!_imeCommitReleaseRequested) {
        _closePanel(clear: true);
        return;
      }
      _resetImeSuppression();
    }
    final ctx = resolveElMentionContext(
      controller,
      controller.selection,
      prefix: widget.config.prefix,
      split: widget.config.split,
    );
    if (ctx == null ||
        ctx.splitIndex != -1 ||
        !_updateMarkerFromCaret(closeWhenUnavailable: false)) {
      _closePanel(clear: true);
      return;
    }
    final suggestions = widget.config.loading
        ? <_ResolvedMentionOption<T>>[]
        : _filterOptions(ctx);
    final active = widget.config.loading
        ? null
        : _correctActive(_activeIndex, suggestions);
    setState(() {
      _context = ctx;
      _suggestions = suggestions;
      _activeIndex = active;
    });
    if (notifySearch &&
        _lastSearchKey !=
            '${ctx.prefixIndex}:${ctx.selectionEnd}:${ctx.prefix}:${ctx.pattern}') {
      _lastSearchKey =
          '${ctx.prefixIndex}:${ctx.selectionEnd}:${ctx.prefix}:${ctx.pattern}';
      widget.config.onSearch?.call(ctx.pattern, ctx.prefix);
    }
    _openPanel();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureActiveVisible());
  }

  List<_ResolvedMentionOption<T>> _filterOptions(ElMentionContext ctx) {
    final config = widget.config;
    Iterable<ElMentionOption<T>> filtered;
    if (config.filterOptions != null) {
      filtered = config.filterOptions!(config.options, ctx.pattern, ctx.prefix);
    } else {
      filtered = config.options.where((option) {
        final filter = config.filterOption;
        if (filter != null) return filter(option, ctx.pattern, ctx.prefix);
        if (ctx.pattern.isEmpty) return true;
        final query = ctx.pattern.toLowerCase();
        final label = option.label ?? option.value;
        return label.toLowerCase().contains(query) ||
            option.value.toLowerCase().contains(query);
      });
    }
    return _resolveMentionOptions(filtered);
  }

  int? _correctActive(
    int? current,
    List<_ResolvedMentionOption<T>> suggestions,
  ) {
    if (suggestions.isEmpty) return null;
    if (current != null &&
        current >= 0 &&
        current < suggestions.length &&
        !suggestions[current].source.disabled) {
      return current;
    }
    if (!widget.config.highlightFirst) return null;
    return _firstEnabledIndex(suggestions);
  }

  int? _firstEnabledIndex(List<_ResolvedMentionOption<T>> suggestions) {
    for (var index = 0; index < suggestions.length; index++) {
      if (!suggestions[index].source.disabled) return index;
    }
    return null;
  }

  int? _lastEnabledIndex(List<_ResolvedMentionOption<T>> suggestions) {
    for (var index = suggestions.length - 1; index >= 0; index--) {
      if (!suggestions[index].source.disabled) return index;
    }
    return null;
  }

  bool _updateMarkerFromCaret({required bool closeWhenUnavailable}) {
    final viewState = _inputControl.controller;
    final rect = viewState?.caretRectGlobal() ?? viewState?.caretGeometry.value;
    final root = _triggerKey.currentContext?.findRenderObject();
    if (viewState == null ||
        rect == null ||
        root is! RenderBox ||
        !root.attached ||
        !root.hasSize) {
      if (closeWhenUnavailable) _closePanel(clear: true);
      return false;
    }
    final global = widget.config.placement == ElMentionPlacement.top
        ? rect.topLeft
        : rect.bottomLeft;
    final local = root.globalToLocal(global);
    if (!local.dx.isFinite || !local.dy.isFinite) {
      if (closeWhenUnavailable) _closePanel(clear: true);
      return false;
    }
    if (_markerOffset == local) return true;
    _markerOffset = local;
    return true;
  }

  void _openPanel() {
    if (!_canOpen || _context == null || _portal.isOpen) return;
    if (_exitSettledTimer != null) {
      _reopenRequested = true;
      return;
    }
    _portal.open();
  }

  void _closePanel({required bool clear}) {
    _reopenRequested = false;
    _portal.close();
    _lastSearchKey = null;
    if (!clear) return;
    if (_context == null && _suggestions.isEmpty && _activeIndex == null) {
      return;
    }
    setState(() {
      _context = null;
      _suggestions = <_ResolvedMentionOption<T>>[];
      _activeIndex = null;
    });
  }

  void _handleOptionPointerDown() {
    _optionPointerActive = true;
  }

  void _handleOptionPointerEnd() {
    _optionPointerActive = false;
  }

  void _handleInputChanged(String value) {
    if (_suppressMentionUntilImeCommit) {
      _imeCommitReleaseRequested = true;
      _imeCompositionObserved = false;
    }
    widget.onValueChanged(value);
    if (!_committingSuggestion) _scheduleEvaluate(notifySearch: true);
  }

  void _resetImeSuppression() {
    _suppressMentionUntilImeCommit = false;
    _imeCommitReleaseRequested = false;
    _imeCompositionObserved = false;
  }

  void _markImeComposing() {
    _suppressMentionUntilImeCommit = true;
    if (!_imeCommitReleaseRequested) _imeCompositionObserved = true;
  }

  bool _hasMentionModifier({bool allowShift = false}) {
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed ||
        (!allowShift && keyboard.isShiftPressed);
  }

  bool _isMentionControlKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.backspace ||
      key == LogicalKeyboardKey.escape ||
      key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.home ||
      key == LogicalKeyboardKey.end ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter;

  bool _isPureModifierKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.shiftLeft ||
      key == LogicalKeyboardKey.shiftRight ||
      key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight ||
      key == LogicalKeyboardKey.metaLeft ||
      key == LogicalKeyboardKey.metaRight ||
      key == LogicalKeyboardKey.altLeft ||
      key == LogicalKeyboardKey.altRight;

  void _handleClear() {
    _closePanel(clear: true);
    widget.config.onClear?.call();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final intercepted = widget.config.onKeyEvent?.call(node, event);
    if (intercepted != null && intercepted != KeyEventResult.ignored) {
      return intercepted;
    }
    final controller = _inputControl.controller;
    final key = event.logicalKey;
    if (controller?.hasActiveImeComposition ?? false) {
      _markImeComposing();
      _closePanel(clear: true);
      if (_isPureModifierKey(key)) return KeyEventResult.skipRemainingHandlers;
      if (event is KeyUpEvent) return KeyEventResult.ignored;
      if (!_hasMentionModifier() && _isMentionControlKey(key)) {
        return KeyEventResult.skipRemainingHandlers;
      }
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (_suppressMentionUntilImeCommit && _isMentionControlKey(key)) {
      _closePanel(clear: true);
      return KeyEventResult.ignored;
    }

    final modified = _hasMentionModifier();
    if (modified &&
        (key == LogicalKeyboardKey.backspace ||
            key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.home ||
            key == LogicalKeyboardKey.end ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.backspace && _handleWholeBackspace()) {
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      if (_hasMentionModifier(allowShift: true)) return KeyEventResult.ignored;
      _closePanel(clear: false);
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (!_portal.isOpen && _context == null) return KeyEventResult.ignored;
      _closePanel(clear: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      if (_context == null) _evaluateMention(notifySearch: true);
      if (_context == null) return KeyEventResult.ignored;
      if (!_moveActive(key == LogicalKeyboardKey.arrowDown ? 1 : -1)) {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }
    if (_portal.isOpen &&
        (key == LogicalKeyboardKey.home || key == LogicalKeyboardKey.end)) {
      return _moveToEdge(end: key == LogicalKeyboardKey.end)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        _portal.isOpen) {
      if (event is KeyRepeatEvent) {
        return _canSelectActive
            ? KeyEventResult.handled
            : KeyEventResult.ignored;
      }
      return _selectActive() ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  bool _handleWholeBackspace() {
    final config = widget.config;
    final controller = _inputControl.controller;
    if (!config.whole || controller == null || !_canOpen) return false;
    final ctx = resolveElMentionWholeContext(
      controller,
      controller.selection,
      prefix: config.prefix,
      split: config.split,
      values: config.options.map((option) => option.value),
      checkIsWhole: config.checkIsWhole,
    );
    if (ctx == null) return false;
    final previousRevision = controller.docRevision;
    controller.insertText(
      '',
      range: TextRange(start: ctx.prefixIndex, end: ctx.splitIndex + 1),
      selection: TextSelection.collapsed(offset: ctx.prefixIndex),
    );
    if (controller.docRevision != previousRevision) {
      _closePanel(clear: true);
      config.onWholeRemove?.call(ctx.pattern, ctx.prefix);
    }
    return true;
  }

  bool _moveActive(int delta) {
    if (widget.config.loading || _suggestions.isEmpty) return false;
    final enabled = <int>[
      for (var index = 0; index < _suggestions.length; index++)
        if (!_suggestions[index].source.disabled) index,
    ];
    if (enabled.isEmpty) return false;
    final current = _activeIndex;
    final next = current == null || !enabled.contains(current)
        ? (delta > 0 ? enabled.first : enabled.last)
        : _moveEnabledIndex(enabled, current, delta);
    if (next != current) {
      setState(() => _activeIndex = next);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureActiveVisible(),
      );
    }
    return true;
  }

  int _moveEnabledIndex(List<int> enabled, int current, int delta) {
    final position = enabled.indexOf(current);
    final next = position + delta;
    if (widget.config.loop) return enabled[next % enabled.length];
    return enabled[next.clamp(0, enabled.length - 1)];
  }

  bool _moveToEdge({required bool end}) {
    if (widget.config.loading || _suggestions.isEmpty) return false;
    final index = end
        ? _lastEnabledIndex(_suggestions)
        : _firstEnabledIndex(_suggestions);
    if (index == null) return false;
    if (index != _activeIndex) {
      setState(() => _activeIndex = index);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureActiveVisible(),
      );
    }
    return true;
  }

  bool get _canSelectActive {
    final index = _activeIndex;
    return !widget.config.loading &&
        index != null &&
        index >= 0 &&
        index < _suggestions.length &&
        !_suggestions[index].source.disabled;
  }

  bool _selectActive() {
    final index = _activeIndex;
    if (!_canSelectActive || index == null) return false;
    return _select(_suggestions[index]);
  }

  bool _select(_ResolvedMentionOption<T> suggestion) {
    if (widget.config.loading || suggestion.source.disabled) return false;
    final controller = _inputControl.controller;
    final ctx = controller == null
        ? null
        : resolveElMentionContext(
            controller,
            controller.selection,
            prefix: widget.config.prefix,
            split: widget.config.split,
          );
    if (controller == null || ctx == null || ctx.splitIndex != -1) return false;
    final split = widget.config.split;
    final value = suggestion.source.value;
    final hasExistingSplit =
        ctx.end < controller.length &&
        controller.getText(ctx.end, ctx.end + 1) == split;
    final replacement = value + (hasExistingSplit ? '' : split);
    final caretOffset = ctx.start + value.length + split.length;
    _committingSuggestion = true;
    final previousRevision = controller.docRevision;
    final previousSelection = controller.selection;
    try {
      controller.insertText(
        replacement,
        range: TextRange(start: ctx.start, end: ctx.end),
        selection: TextSelection.collapsed(offset: caretOffset),
      );
    } finally {
      _committingSuggestion = false;
    }
    if (controller.docRevision == previousRevision &&
        controller.selection == previousSelection) {
      return true;
    }
    _closePanel(clear: true);
    if (_canRequestFocus) _focusNode.requestFocus();
    widget.config.onSelected?.call(suggestion.source, ctx.prefix);
    return true;
  }

  void _ensureActiveVisible() {
    if (!mounted || !_portal.isOpen) return;
    final index = _activeIndex;
    final controller = _scrollController;
    if (index == null || !controller.hasClients) return;
    final itemHeight = _mentionOptionHeights[_effectiveSize.index];
    final start = index * itemHeight;
    final end = start + itemHeight;
    final metrics = controller.position;
    if (start < metrics.pixels) {
      metrics.jumpTo(
        start.clamp(metrics.minScrollExtent, metrics.maxScrollExtent),
      );
    } else if (end > metrics.pixels + metrics.viewportDimension) {
      metrics.jumpTo(
        (end - metrics.viewportDimension).clamp(
          metrics.minScrollExtent,
          metrics.maxScrollExtent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final marker = _markerOffset ?? Offset.zero;
    _panel.value = _MentionPanel<T>(
      suggestions: _suggestions,
      loading: config.loading,
      activeIndex: _activeIndex,
      maxHeight: config.menuHeight,
      width: config.panelWidth,
      showArrow: config.showArrow,
      placement: config.placement,
      scrollController: _scrollController,
      size: _effectiveSize,
      panelStyle: config.panelStyle,
      optionStyle: config.optionStyle,
      itemBuilder: config.itemBuilder,
      header: config.header,
      footer: config.footer,
      loadingBuilder: config.loadingBuilder,
      emptyBuilder: config.emptyBuilder,
      onOptionPointerDown: _handleOptionPointerDown,
      onOptionPointerEnd: _handleOptionPointerEnd,
      onSelected: _select,
    );

    return ElView(
      key: _triggerKey,
      style: ElStyle(width: config.width ?? 240),
      event: config.disabled ? ElEvent(disabled: true) : null,
      child: ElStackView(
        clipBehavior: Clip.none,
        children: [
          _MentionField(
            value: widget.value,
            onChanged: _handleInputChanged,
            placeholder: config.placeholder,
            clearable: config.clearable,
            disabled: config.disabled,
            readOnly: config.readOnly,
            autofocus: config.autofocus,
            maxLength: config.maxLength,
            focusNode: _focusNode,
            control: _inputControl,
            onKeyEvent: _handleKeyEvent,
            onClear: _handleClear,
            onSubmitted: config.onSubmitted,
            prefix: config.inputPrefix,
            suffix: config.inputSuffix,
            keyboardType: config.keyboardType,
            textInputAction: config.textInputAction,
            actionLabel: config.actionLabel,
            keyboardAppearance: config.keyboardAppearance,
            textCapitalization: config.textCapitalization,
            smartDashesType: config.smartDashesType,
            smartQuotesType: config.smartQuotesType,
            autocorrect: config.autocorrect,
            enableSuggestions: config.enableSuggestions,
            enableInteractiveSelection: config.enableInteractiveSelection,
            enableIMEPersonalizedLearning: config.enableIMEPersonalizedLearning,
            allowedMimeTypes: config.allowedMimeTypes,
            hintLocales: config.hintLocales,
            enableInlinePrediction: config.enableInlinePrediction,
            autofillHints: config.autofillHints,
            onAction: config.onAction,
            onConnectionClosed: config.onConnectionClosed,
            onPrivateCommand: config.onPrivateCommand,
            onFloatingCursor: config.onFloatingCursor,
            onAutocorrectionPromptRect: config.onAutocorrectionPromptRect,
            onShowToolbar: config.onShowToolbar,
            onTextPlaceholderChanged: config.onTextPlaceholderChanged,
            onSelector: config.onSelector,
            onUnhandledContent: config.onUnhandledContent,
            onInputControlChanged: config.onInputControlChanged,
            inputFormatters: config.inputFormatters,
            textAlign: config.textAlign,
            style: config.style,
            textarea: config.textarea,
            minLine: config.minLine,
            maxLine: config.maxLine,
            semanticLabel: config.semanticLabel,
          ),
          if (Overlay.maybeOf(context) != null)
            ElPositioned(
              left: marker.dx,
              top: marker.dy,
              width: 0,
              height: 0,
              child: ElPortal(
                // 候选面板由正文输入节点导航，不切断正在进行的编辑会话。
                captureFocus: false,
                restoreFocus: false,
                controller: _portal,
                anchor: _portalAnchor,
                exitDuration: _mentionPanelExitDuration,
                overlayBuilder: (_) => ValueListenableBuilder<Widget>(
                  valueListenable: _panel,
                  builder: (_, panel, _) => panel,
                ),
                hideWhenUnlinked: true,
                onDismiss: () => _closePanel(clear: true),
                child: const ElView(
                  style: ElStyle(
                    width: 0,
                    height: 0,
                    pointerEvents: .none,
                    userSelect: .none,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MentionField extends ElInput {
  const _MentionField({
    required super.value,
    required super.onChanged,
    super.placeholder,
    super.clearable,
    super.disabled,
    super.readOnly,
    super.autofocus,
    super.maxLength,
    super.focusNode,
    super.control,
    super.onKeyEvent,
    super.onClear,
    super.onSubmitted,
    super.prefix,
    super.suffix,
    super.keyboardType,
    super.textInputAction,
    super.actionLabel,
    super.keyboardAppearance,
    super.textCapitalization,
    super.smartDashesType,
    super.smartQuotesType,
    super.autocorrect,
    super.enableSuggestions,
    super.enableInteractiveSelection,
    super.enableIMEPersonalizedLearning,
    super.allowedMimeTypes,
    super.hintLocales,
    super.enableInlinePrediction,
    super.autofillHints,
    super.onAction,
    super.onConnectionClosed,
    super.onPrivateCommand,
    super.onFloatingCursor,
    super.onAutocorrectionPromptRect,
    super.onShowToolbar,
    super.onTextPlaceholderChanged,
    super.onSelector,
    super.onUnhandledContent,
    super.onInputControlChanged,
    super.inputFormatters,
    super.textAlign,
    super.style,
    super.textarea,
    super.minLine,
    super.maxLine,
    super.semanticLabel,
  });

  @override
  bool get formBindable => false;
}
