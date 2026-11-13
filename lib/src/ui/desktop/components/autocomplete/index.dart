import 'dart:async';

import 'package:flutter/semantics.dart' show SemanticsProperties, SemanticsRole;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../../flutter/commons/models.dart' show ElLabelModel;
import '../../../../flutter/components/tokens.dart' show ElThemeContextExt;
import '../../../../flutter/components/autocomplete/index.dart' show ElAutocomplete;
import '../../../../flutter/components/input/index.dart' show ElInput, ElInputController;
import '../../../../flutter/views/editable/controller.dart' show ElEditableController;
import '../../../../flutter/views/editable/view.dart' show ElEditableView;
import '../../../../flutter/views/view/event/event.dart' show ElEvent;
import '../../../../flutter/views/view/semantics/semantics.dart' show ElSemantics;
import '../../../../flutter/views/view/style/style.dart' show ElStyle;
import '../../../../flutter/views/view/view.dart' show ElView;
import '../../../../flutter/widgets/form/index.dart' show ElFormItem, ElInputModelValue;
import '../../../../flutter/widgets/popup/anchor.dart' show ElOverlayAnchor;
import '../../../../flutter/widgets/popup/portal.dart' show ElPortal, ElPortalController, ElPortalPhase;
import '../../extensions/el.dart';
import '../input/metrics.dart';
import '../list_scroll.dart' show buildListScroll;

part 'panel.dart';

/// 基于 [ElInput] 与 [ElPortal] 的自动补全输入框。
///
/// 文本、IME、选区与 Autofill 只由内部 [ElInput] 的 [ElEditableView] 处理；
/// 本组件只负责任务防抖、候选请求、弹层和键盘 active 状态。值通道支持受控
/// [value]、双向 [modelValue] 与 [ElFormItem] 的 `prop` 绑定。
///
/// 桌面预设使用的 Element 自动补全实现。
class Autocomplete<T> extends ElInputModelValue<String> {
  Autocomplete(this.component, {super.key, this.themeStyle})
    : super(
        value: component.value ?? (component.modelValue == null ? '' : null),
        modelValue: component.modelValue,
        onChanged: component.onChanged,
      );

  final ElAutocomplete<T> component;

  /// 复用补全机制时由品牌注入的默认外观。
  final ElStyle? themeStyle;

  FutureOr<Iterable<ElLabelModel<T>>> Function(String query) get fetchSuggestions => component.fetchSuggestions;
  ValueChanged<ElLabelModel<T>>? get onSelected => component.onSelected;
  Duration get debounce => component.debounce;
  bool get triggerOnFocus => component.triggerOnFocus;
  bool get highlightFirst => component.highlightFirst;
  bool get loop => component.loop;
  Widget Function(BuildContext context, ElLabelModel<T> suggestion, bool active)? get itemBuilder =>
      component.itemBuilder;
  Widget? get header => component.header;
  Widget? get footer => component.footer;
  WidgetBuilder? get loadingBuilder => component.loadingBuilder;
  WidgetBuilder? get emptyBuilder => component.emptyBuilder;
  Widget Function(BuildContext context, Object error)? get errorBuilder => component.errorBuilder;
  String? get placeholder => component.placeholder;
  bool get clearable => component.clearable;
  bool get disabled => component.disabled;
  bool get readOnly => component.readOnly;
  bool get autofocus => component.autofocus;
  int? get maxLength => component.maxLength;
  FocusNode? get focusNode => component.focusNode;
  FocusOnKeyEventCallback? get onKeyEvent => component.onKeyEvent;
  VoidCallback? get onFocus => component.onFocus;
  VoidCallback? get onBlur => component.onBlur;
  VoidCallback? get onClear => component.onClear;
  ValueChanged<String>? get onSubmitted => component.onSubmitted;
  Object? get prefix => component.prefix;
  Object? get suffix => component.suffix;
  TextInputType? get keyboardType => component.keyboardType;
  TextInputAction? get textInputAction => component.textInputAction;
  List<TextInputFormatter> get inputFormatters => component.inputFormatters;
  Iterable<String>? get autofillHints => component.autofillHints;
  double? get width => component.width;
  double get menuHeight => component.menuHeight;
  ScrollController? get scrollController => component.scrollController;
  ElOverlayAnchor get anchor => component.anchor;
  int get zIndex => component.zIndex;
  ElStyle? get style => themeStyle == null ? component.style : themeStyle!.merge(component.style);
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

    return _AutocompleteBody<T>(
      config: this,
      value: $obs.value,
      onQueryChanged: updateValue,
      onFocus: onFocus,
      onBlur: () {
        $formBlurValidate();
        onBlur?.call();
      },
    );
  }
}

class _ResolvedSuggestion<T> {
  const _ResolvedSuggestion({required this.source, required this.index, required this.label});

  final ElLabelModel<T> source;
  final int index;
  final String label;
}

List<_ResolvedSuggestion<T>> _resolveSuggestions<T>(Iterable<ElLabelModel<T>> source) {
  final result = <_ResolvedSuggestion<T>>[];
  var index = 0;
  for (final suggestion in source) {
    final label = suggestion.label;
    if (label == null || label.trim().isEmpty) {
      throw FlutterError('ElAutocomplete suggestions[$index] 的 label 必须是非空字符串。');
    }
    result.add(_ResolvedSuggestion<T>(source: suggestion, index: index, label: label));
    index++;
  }
  return result;
}

class _AutocompleteScrollController extends ScrollController {
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

bool _isAutocompleteOverlayControlKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.arrowDown ||
    key == LogicalKeyboardKey.arrowUp ||
    key == LogicalKeyboardKey.home ||
    key == LogicalKeyboardKey.end ||
    key == LogicalKeyboardKey.enter ||
    key == LogicalKeyboardKey.numpadEnter ||
    key == LogicalKeyboardKey.space ||
    key == LogicalKeyboardKey.escape;

bool _hasAutocompleteOverlayModifier() {
  final keyboard = HardwareKeyboard.instance;
  return keyboard.isControlPressed || keyboard.isMetaPressed || keyboard.isAltPressed;
}

class _AutocompleteBody<T> extends StatefulWidget {
  const _AutocompleteBody({
    required this.config,
    required this.value,
    required this.onQueryChanged,
    required this.onFocus,
    required this.onBlur,
  });

  final Autocomplete<T> config;
  final String value;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback? onFocus;
  final VoidCallback onBlur;

  @override
  State<_AutocompleteBody<T>> createState() => _AutocompleteBodyState<T>();
}

class _AutocompleteBodyState<T> extends State<_AutocompleteBody<T>> {
  final ElPortalController _portal = ElPortalController();
  // Portal 冻结会话入口，候选内容通过独立值通道跟随输入和键盘状态。
  final _panel = ValueNotifier<Widget>(const SizedBox.shrink());
  final ElInputController _inputControl = ElInputController();
  final _AutocompleteScrollController _ownScrollController = _AutocompleteScrollController();
  final Object _semanticsIdentity = Object();
  late final FocusNode _ownFocusNode;
  ElEditableController? _listenedController;
  Timer? _debounceTimer;
  Timer? _exitSettledTimer;
  var _requestEpoch = 0;
  var _query = '';
  var _renderedFieldText = '';
  var _suggestions = <_ResolvedSuggestion<T>>[];
  Object? _error;
  int? _activeIndex;
  bool _loading = false;
  bool _portalOpen = false;
  bool _optionPointerActive = false;
  bool _reopenRequested = false;
  bool _focusReported = false;
  bool _committingSuggestion = false;
  bool _imeComposing = false;

  FocusNode get _focusNode => widget.config.focusNode ?? _ownFocusNode;

  ScrollController get _scrollController => widget.config.scrollController ?? _ownScrollController;

  String get _panelSemanticsIdentifier => 'el-autocomplete-options-${identityHashCode(_semanticsIdentity)}';

  bool get _canOpen => mounted && !widget.config.disabled && !widget.config.readOnly && _focusNode.hasFocus;

  bool get _compact => context.elComponentCompact(widget.config.style);

  @override
  void initState() {
    super.initState();
    _query = widget.value;
    _ownFocusNode = FocusNode(debugLabel: 'ElAutocomplete');
    _portal.addListener(_handlePortalChanged);
    _inputControl.addListener(_handleInputControlChanged);
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(_AutocompleteBody<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.config.focusNode != oldWidget.config.focusNode) {
      (oldWidget.config.focusNode ?? _ownFocusNode).removeListener(_handleFocusChanged);
      _focusNode.addListener(_handleFocusChanged);
      final reportBlur = _focusReported;
      _focusReported = false;
      _cancelPending(clear: true);
      _reopenRequested = false;
      _portal.close();
      scheduleMicrotask(() {
        if (!mounted) return;
        if (_focusNode.hasFocus) {
          _handleFocusChanged();
        } else if (reportBlur) {
          widget.onBlur();
        }
      });
    }
    if (widget.value != oldWidget.value && widget.value != _query) {
      _query = widget.value;
      _cancelPending(clear: true);
      _reopenRequested = false;
      _portal.close();
    }
    if (widget.config.scrollController != oldWidget.config.scrollController) {
      _cancelPending(clear: true);
      _reopenRequested = false;
      _portal.close();
    }
    if (widget.config.disabled || widget.config.readOnly) {
      _cancelPending(clear: true);
      _reopenRequested = false;
      _portal.close();
      if (widget.config.disabled) _focusNode.unfocus();
    }
    if (_activeIndex != null && _activeIndex! >= _suggestions.length) {
      _activeIndex = widget.config.highlightFirst && _suggestions.isNotEmpty ? 0 : null;
    }
  }

  @override
  void dispose() {
    _requestEpoch++;
    _debounceTimer?.cancel();
    _exitSettledTimer?.cancel();
    _listenedController?.removeListener(_handleEditableVisualChanged);
    _inputControl.removeListener(_handleInputControlChanged);
    _focusNode.removeListener(_handleFocusChanged);
    _portal
      ..removeListener(_handlePortalChanged)
      ..close()
      ..dispose();
    _panel.dispose();
    _ownScrollController.disposeWhenDetached();
    _ownFocusNode.dispose();
    super.dispose();
  }

  void _handleInputControlChanged() {
    final controller = _inputControl.controller;
    if (!identical(controller, _listenedController)) {
      _listenedController?.removeListener(_handleEditableVisualChanged);
      _listenedController = controller;
      _listenedController?.addListener(_handleEditableVisualChanged);
    }
    _syncImeComposing();
  }

  void _handleEditableVisualChanged() => _syncImeComposing();

  void _syncImeComposing() {
    final composing = _inputControl.controller?.hasActiveImeComposition ?? false;
    if (!mounted || composing == _imeComposing) return;
    setState(() => _imeComposing = composing);
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
          if (!mounted || !_reopenRequested || !_canOpen) return;
          _reopenRequested = false;
          _portal.open();
          WidgetsBinding.instance.addPostFrameCallback((_) => _ensureActiveVisible());
        });
      }
    });
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      if (!_focusReported) {
        _focusReported = true;
        widget.onFocus?.call();
      }
      if (widget.config.triggerOnFocus && !widget.config.readOnly) {
        _scheduleQuery(widget.value, allowEmpty: true);
      }
      return;
    }
    if (_optionPointerActive && _portal.isOpen) {
      scheduleMicrotask(() {
        if (!_canRequestFocus) return;
        _focusNode.requestFocus();
      });
      return;
    }
    _cancelPending(clear: true);
    _reopenRequested = false;
    final reportBlur = _focusReported;
    _focusReported = false;
    // FocusManager 正在遍历本轮脏节点；同步关闭 Portal 会再次改写同一集合。
    // 两级微任务先结算本轮失焦与可能的立即回焦，再按最终状态关闭弹层。
    scheduleMicrotask(() {
      scheduleMicrotask(() {
        if (!mounted) return;
        if (!_focusNode.hasFocus) _portal.close();
        if (reportBlur) widget.onBlur();
      });
    });
  }

  bool get _canRequestFocus =>
      mounted &&
      !widget.config.disabled &&
      !widget.config.readOnly &&
      _focusNode.context != null &&
      _focusNode.canRequestFocus;

  void _handleOptionPointerDown() {
    _optionPointerActive = true;
  }

  void _handleOptionPointerEnd() {
    _optionPointerActive = false;
  }

  void _cancelPending({required bool clear}) {
    _requestEpoch++;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (!clear) return;
    _loading = false;
    _error = null;
    _suggestions = <_ResolvedSuggestion<T>>[];
    _activeIndex = null;
  }

  void _scheduleQuery(String query, {bool allowEmpty = false, bool immediate = false}) {
    if (!_canOpen) return;
    if (query.isEmpty && !allowEmpty) {
      setState(() => _cancelPending(clear: true));
      _reopenRequested = false;
      _portal.close();
      return;
    }
    final epoch = ++_requestEpoch;
    _debounceTimer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
      _suggestions = <_ResolvedSuggestion<T>>[];
      _activeIndex = null;
    });
    _openPanel();
    final delay = immediate ? Duration.zero : widget.config.debounce;
    _debounceTimer = Timer(delay, () {
      _debounceTimer = null;
      _loadSuggestions(query, epoch);
    });
  }

  Future<void> _loadSuggestions(String query, int epoch) async {
    if (!_requestIsCurrent(query, epoch)) return;
    try {
      final source = await widget.config.fetchSuggestions(query);
      if (!_requestIsCurrent(query, epoch)) return;
      final suggestions = _resolveSuggestions<T>(source);
      setState(() {
        _loading = false;
        _error = null;
        _suggestions = suggestions;
        _activeIndex = widget.config.highlightFirst && suggestions.isNotEmpty ? 0 : null;
      });
      _openPanel();
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureActiveVisible());
    } catch (error) {
      if (!_requestIsCurrent(query, epoch)) return;
      setState(() {
        _loading = false;
        _error = error;
        _suggestions = <_ResolvedSuggestion<T>>[];
        _activeIndex = null;
      });
      _openPanel();
    }
  }

  bool _requestIsCurrent(String query, int epoch) => mounted && epoch == _requestEpoch && query == _query && _canOpen;

  void _openPanel() {
    if (!_canOpen || _portal.isOpen) return;
    if (_exitSettledTimer != null) {
      _reopenRequested = true;
      return;
    }
    _portal.open();
  }

  void _handleQueryChanged(String value) {
    if (value == _renderedFieldText) {
      _query = value;
      return;
    }
    _query = value;
    widget.onQueryChanged(value);
    if (_committingSuggestion) return;
    if (value.isEmpty) {
      setState(() => _cancelPending(clear: true));
      _reopenRequested = false;
      _portal.close();
      return;
    }
    _scheduleQuery(value);
  }

  void _handleClear() {
    _query = '';
    setState(() => _cancelPending(clear: true));
    _reopenRequested = false;
    _portal.close();
    widget.config.onClear?.call();
  }

  void _expandFromSemantics() {
    if (widget.config.disabled || widget.config.readOnly || _portal.isOpen) {
      return;
    }
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
    scheduleMicrotask(() {
      if (!mounted || _portal.isOpen || !_focusNode.hasFocus) return;
      _query = widget.value;
      _scheduleQuery(widget.value, allowEmpty: true, immediate: true);
    });
  }

  void _collapseFromSemantics() {
    if (!_portal.isOpen && !_loading) return;
    setState(() => _cancelPending(clear: true));
    _reopenRequested = false;
    _portal.close();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final intercepted = widget.config.onKeyEvent?.call(node, event);
    if (intercepted != null && intercepted != KeyEventResult.ignored) {
      return intercepted;
    }
    final key = event.logicalKey;
    final overlayControlKey = _isAutocompleteOverlayControlKey(key);
    if ((_inputControl.controller?.hasActiveImeComposition ?? false) && overlayControlKey) {
      return KeyEventResult.skipRemainingHandlers;
    }
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (_hasAutocompleteOverlayModifier() && overlayControlKey) {
      return key == LogicalKeyboardKey.escape ? KeyEventResult.skipRemainingHandlers : KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.tab) {
      _cancelPending(clear: false);
      _reopenRequested = false;
      _portal.close();
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (!_portal.isOpen && !_loading) return KeyEventResult.ignored;
      setState(() => _cancelPending(clear: true));
      _reopenRequested = false;
      _portal.close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      if (!_portal.isOpen) {
        _query = widget.value;
        _scheduleQuery(widget.value, allowEmpty: true, immediate: true);
      } else {
        _moveActive(key == LogicalKeyboardKey.arrowDown ? 1 : -1);
      }
      return KeyEventResult.handled;
    }
    if (_portal.isOpen && (key == LogicalKeyboardKey.home || key == LogicalKeyboardKey.end)) {
      _moveToEdge(end: key == LogicalKeyboardKey.end);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter && _portal.isOpen) {
      if (event is! KeyRepeatEvent) _selectActive();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _moveActive(int delta) {
    final length = _suggestions.length;
    if (length == 0) return;
    final current = _activeIndex;
    final int next;
    if (current == null) {
      next = delta > 0 ? 0 : length - 1;
    } else if (widget.config.loop) {
      next = (current + delta) % length;
    } else {
      next = (current + delta).clamp(0, length - 1);
    }
    setState(() => _activeIndex = next);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureActiveVisible());
  }

  void _moveToEdge({required bool end}) {
    if (_suggestions.isEmpty) return;
    setState(() => _activeIndex = end ? _suggestions.length - 1 : 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureActiveVisible());
  }

  void _selectActive() {
    final index = _activeIndex;
    if (index == null || index < 0 || index >= _suggestions.length) return;
    _select(_suggestions[index]);
  }

  void _select(_ResolvedSuggestion<T> suggestion) {
    final controller = _fieldController();
    if (controller == null) return;
    _cancelPending(clear: false);
    final previousRevision = controller.docRevision;
    _committingSuggestion = true;
    try {
      controller.insertText(suggestion.label, range: TextRange(start: 0, end: controller.length));
    } finally {
      _committingSuggestion = false;
    }
    // 格式化规则拒绝输入时，不发布候选选择通知。
    if (controller.docRevision == previousRevision) return;
    final committed = controller.text;
    _query = committed;
    _reopenRequested = false;
    _portal.close();
    if (_canRequestFocus) _focusNode.requestFocus();
    _collapseCommittedCaret(committed);
    widget.config.onSelected?.call(suggestion.source);
  }

  void _collapseCommittedCaret(String label, [int retries = 2]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _query != label) return;
      final controller = _fieldController();
      if (controller != null && controller.text == label) {
        controller.collapseTo(controller.length);
      } else if (retries > 0) {
        _collapseCommittedCaret(label, retries - 1);
      }
    });
  }

  ElEditableController? _fieldController() {
    return _inputControl.controller;
  }

  void _ensureActiveVisible() {
    if (!mounted || !_portal.isOpen) return;
    final index = _activeIndex;
    final controller = _scrollController;
    if (index == null || !controller.hasClients) return;
    final itemHeight = _autocompleteOptionHeight(_compact);
    final start = index * itemHeight;
    final end = start + itemHeight;
    final metrics = controller.position;
    if (start < metrics.pixels) {
      metrics.jumpTo(start.clamp(metrics.minScrollExtent, metrics.maxScrollExtent));
    } else if (end > metrics.pixels + metrics.viewportDimension) {
      metrics.jumpTo((end - metrics.viewportDimension).clamp(metrics.minScrollExtent, metrics.maxScrollExtent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    _renderedFieldText = widget.value;
    final trigger = ElView(
      style: ElStyle(width: config.width ?? 240),
      event: config.disabled ? ElEvent(disabled: true) : null,
      semantics: ElSemantics(
        mergeDescendants: true,
        properties: SemanticsProperties(
          // 当前 Flutter 的 SemanticsRole.comboBox 校验器仍是 unimplemented，
          // 开启语义会直接断言；先用真实 textField + expanded/controls 合同。
          expanded: _portal.isOpen,
          enabled: !config.disabled,
          readOnly: config.disabled || config.readOnly,
          controlsNodes: <String>{_panelSemanticsIdentifier},
          onExpand: !config.disabled && !config.readOnly && !_portal.isOpen ? _expandFromSemantics : null,
          onCollapse: _portal.isOpen ? _collapseFromSemantics : null,
        ),
      ),
      child: _AutocompleteField(
        value: widget.value,
        onChanged: _handleQueryChanged,
        control: _inputControl,
        placeholder: config.placeholder,
        clearable: config.clearable,
        disabled: config.disabled,
        readOnly: config.readOnly,
        autofocus: config.autofocus,
        maxLength: config.maxLength,
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        onClear: _handleClear,
        onSubmitted: config.onSubmitted,
        prefix: config.prefix,
        suffix: config.suffix,
        keyboardType: config.keyboardType,
        textInputAction: config.textInputAction,
        inputFormatters: config.inputFormatters,
        autofillHints: config.autofillHints,
        style: config.style,
        semanticLabel: config.semanticLabel,
      ),
    );

    _panel.value = _AutocompletePanel<T>(
      semanticsIdentifier: _panelSemanticsIdentifier,
      suggestions: _suggestions,
      loading: _loading,
      error: _error,
      activeIndex: _activeIndex,
      maxHeight: config.menuHeight,
      scrollController: _scrollController,
      compact: _compact,
      panelStyle: config.panelStyle,
      optionStyle: config.optionStyle,
      itemBuilder: config.itemBuilder,
      header: config.header,
      footer: config.footer,
      loadingBuilder: config.loadingBuilder,
      emptyBuilder: config.emptyBuilder,
      errorBuilder: config.errorBuilder,
      onOptionPointerDown: _handleOptionPointerDown,
      onOptionPointerEnd: _handleOptionPointerEnd,
      onSelected: _select,
    );

    // 裸组件没有官方 Overlay 时保留输入，不挂载候选面板。
    if (Overlay.maybeOf(context) == null) return trigger;
    return ElPortal(
      // 建议列表由输入框处理键盘与 IME，保持输入宿主的主焦点。
      captureFocus: false,
      restoreFocus: false,
      controller: _portal,
      anchor: config.anchor,
      exitDuration: _autocompletePanelExitDuration,
      overlayBuilder: (_) => ValueListenableBuilder<Widget>(valueListenable: _panel, builder: (_, panel, _) => panel),
      closeOnEscape: !_imeComposing,
      hideWhenUnlinked: true,
      child: trigger,
    );
  }
}

class _AutocompleteField extends ElInput {
  const _AutocompleteField({
    required super.value,
    required super.onChanged,
    required super.control,
    super.placeholder,
    super.clearable,
    super.disabled,
    super.readOnly,
    super.autofocus,
    super.maxLength,
    super.focusNode,
    super.onKeyEvent,
    super.onClear,
    super.onSubmitted,
    super.prefix,
    super.suffix,
    super.keyboardType,
    super.textInputAction,
    super.inputFormatters,
    super.autofillHints,
    super.style,
    super.semanticLabel,
  });

  @override
  bool get formBindable => false;
}
