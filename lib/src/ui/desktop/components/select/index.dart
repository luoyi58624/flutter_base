import 'dart:async';

import 'package:flutter/material.dart'
    show DropdownMenuCloseBehavior, DropdownMenuEntry, FilterCallback, SearchCallback;
import 'package:flutter/semantics.dart' show SemanticsProperties, SemanticsRole;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../../flutter/commons/models.dart' show ElLabelModel;
import '../../../../flutter/commons/theme/index.dart' show ElThemeContextExt;
import '../../../../flutter/components/input/index.dart' show ElInput, ElInputController;
import '../../../../flutter/components/select/index.dart' show ElSelect, ElSelectOption;
import '../../../../flutter/views/editable/controller.dart' show ElEditableController;
import '../../../../flutter/views/scroll/scroll_view.dart' show ElScrollView;
import '../../../../flutter/views/view/event/event.dart' show ElEvent, ElEventExt;
import '../../../../flutter/views/view/semantics/semantics.dart' show ElSemantics;
import '../../../../flutter/views/view/style/style.dart' show ElStyle;
import '../../../../flutter/views/view/view.dart' show ElView;
import '../../../../flutter/widgets/form/index.dart' show ElFormItem, ElFormModelValue, ElInputModelValue;
import '../../../../flutter/widgets/popup/anchor.dart' show ElOverlayAnchor;
import '../../../../flutter/widgets/popup/portal.dart' show ElPortal, ElPortalController, ElPortalPhase;
import '../../extensions/content.dart';
import '../../extensions/el.dart';
import '../icon/index.dart';
import '../input/metrics.dart';
import '../index.dart' show ElementPlusThemeData;

part 'panel.dart';

/// 基于 El 输入、焦点与弹层系统的单选选择器。
///
/// 值通道由 [ElFormModelValue] 提供：可传 `value`、`modelValue`，或置于带
/// `prop` 的 [ElFormItem] 中。组件只会提交 [children] 中解析出的 option 值，
/// 筛选 query 永远不会被强转成 `T` 或写入表单。
///
/// Element 选择器主题实现：只服务 [ElementPlusThemeData]，由 barrel 挡住、不经 `element_plus.dart` 导出。
class Select<T> extends ElInputModelValue<T> {
  Select(this.component, {super.key})
    : super(
        value: component.value ?? (component.modelValue == null ? component.initialSelection : null),
        modelValue: component.modelValue,
        onChanged: component.onChanged,
      );

  final ElSelect<T> component;

  List<ElLabelModel<T>> get children => component.children;
  bool get enabled => component.enabled && !component.disabled;
  double? get width => component.width;
  double? get menuHeight => component.menuHeight;
  ScrollController? get scrollController => component.scrollController;
  ElOverlayAnchor get anchor => component.anchor;
  int get zIndex => component.zIndex;
  FocusNode? get focusNode => component.focusNode;
  Widget? get leadingIcon => component.leadingIcon;
  Widget? get trailingIcon => component.trailingIcon;
  Widget? get selectedTrailingIcon => component.selectedTrailingIcon;
  bool get showTrailingIcon => component.showTrailingIcon;
  String? get hintText => component.hintText;
  bool get enableFilter => component.enableFilter;
  TextInputType? get keyboardType => component.keyboardType;
  FilterCallback<T>? get filterCallback => component.filterCallback;
  // ignore: deprecated_member_use -- 保留既有搜索回调兼容入口。
  bool get enableSearch => component.enableSearch;
  bool Function(ElLabelModel<T> option, String query)? get optionFilter => component.optionFilter;
  SearchCallback<T>? get searchCallback => component.searchCallback;
  ElStyle? get panelStyle => component.panelStyle;
  T? get initialSelection => component.initialSelection;
  ValueChanged<T?>? get onSelected => component.onSelected;
  List<TextInputFormatter>? get inputFormatters => component.inputFormatters;
  DropdownMenuCloseBehavior get closeBehavior => component.closeBehavior;
  TextInputAction? get textInputAction => component.textInputAction;
  ElStyle? get style => component.style;
  ElStyle? get optionStyle => component.optionStyle;
  String? get semanticLabel => component.semanticLabel;

  /// 把模型值转换成 option label；保留旧 ElInputModelValue 公开转换入口。
  @override
  String toTextEditing(T value) {
    for (final option in _resolveSelectOptions(children)) {
      if (option.value == value) return option.label;
    }
    return value.toString();
  }

  /// 把精确匹配的 option label 转回模型值；保留旧公开转换入口。
  @override
  T toModelValue(String text) {
    for (final option in _resolveSelectOptions(children)) {
      if (option.label == text) return option.value;
    }
    return text as T;
  }

  @override
  Widget obsBuilder(BuildContext context) {
    return _ElSelectBody<T>(
      config: this,
      value: $obs.value,
      onSelected: (value) {
        if ($obs.value == value) return;
        final target = modelValue;
        if (target != null) {
          // 先写外部 notifier，让基类的入站同步只触发一次业务回调；直接写
          // $obs 会先镜像 modelValue、再被 notifier 回灌，造成同值重复通知。
          target.value = value;
        } else {
          $obs.value = value;
        }
        onSelected?.call(value);
      },
      onBlur: $formBlurValidate,
    );
  }
}

class _ResolvedSelectOption<T> {
  const _ResolvedSelectOption({required this.source, required this.index, required this.label, required this.value});

  final ElLabelModel<T> source;
  bool get disabled => source is ElSelectOption<T> && (source as ElSelectOption<T>).disabled;
  Object get content => source is ElSelectOption<T> ? (source as ElSelectOption<T>).content : label;
  final int index;
  final String label;
  final T value;
}

class _ElSelectScrollController extends ScrollController {
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

bool _isSelectOverlayControlKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.arrowDown ||
    key == LogicalKeyboardKey.arrowUp ||
    key == LogicalKeyboardKey.home ||
    key == LogicalKeyboardKey.end ||
    key == LogicalKeyboardKey.enter ||
    key == LogicalKeyboardKey.numpadEnter ||
    key == LogicalKeyboardKey.space ||
    key == LogicalKeyboardKey.escape;

bool _hasSelectOverlayModifier() {
  final keyboard = HardwareKeyboard.instance;
  return keyboard.isControlPressed || keyboard.isMetaPressed || keyboard.isAltPressed;
}

List<_ResolvedSelectOption<T>> _resolveSelectOptions<T>(List<ElLabelModel<T>> children) {
  final result = <_ResolvedSelectOption<T>>[];
  for (var index = 0; index < children.length; index++) {
    final option = children[index];
    final label = option.label;
    if (label == null || (label.trim().isEmpty && option is! ElSelectOption<T>)) {
      throw FlutterError('ElSelect children[$index] 的 label 必须是非空字符串。');
    }
    final rawValue = option.value;
    final T value;
    if (rawValue != null) {
      value = rawValue;
    } else if (label is T) {
      value = label as T;
    } else {
      throw FlutterError(
        'ElSelect children[$index] 省略 value 时，label 必须可作为泛型 T 的值；'
        '当前 label 是 String，T 为 $T。',
      );
    }
    if (result.any((item) => item.value == value)) {
      throw FlutterError('ElSelect option value 必须唯一，children[$index] 与更早选项重复：$value。');
    }
    result.add(_ResolvedSelectOption<T>(source: option, index: index, label: label, value: value));
  }
  return result;
}

List<DropdownMenuEntry<T>> _materialEntries<T>(List<_ResolvedSelectOption<T>> options) {
  return [for (final option in options) DropdownMenuEntry<T>(value: option.value, label: option.label)];
}

class _ElSelectBody<T> extends StatefulWidget {
  const _ElSelectBody({required this.config, required this.value, required this.onSelected, required this.onBlur});

  final Select<T> config;
  final T value;
  final ValueChanged<T> onSelected;
  final VoidCallback onBlur;

  @override
  State<_ElSelectBody<T>> createState() => _ElSelectBodyState<T>();
}

class _ElSelectBodyState<T> extends State<_ElSelectBody<T>> {
  final ElPortalController _portal = ElPortalController();
  // Portal 冻结会话入口，候选内容通过独立值通道跟随输入和键盘状态。
  final _panel = ValueNotifier<Widget>(const SizedBox.shrink());
  final ElInputController _inputControl = ElInputController();
  final _ElSelectScrollController _ownScrollController = _ElSelectScrollController();
  final Object _semanticsIdentity = Object();
  late final FocusNode _ownFocusNode;
  ElEditableController? _listenedController;
  String _query = '';
  int? _activeIndex;
  bool _portalOpen = false;
  bool _optionPointerActive = false;
  Timer? _exitSettledTimer;
  bool _reopenRequested = false;
  String _renderedFieldText = '';
  bool _focusReported = false;
  int _focusSession = 0;
  // ElEvent 的键回调只要被调用就会向 Focus 返回 handled，无法表达 Select
  // 必需的 ignored / skipRemainingHandlers 三态；这里仅为非筛选 trigger 安装
  // 可安全恢复的 FocusNode handler，节点 attach/canRequestFocus 仍统一交给 ElView 焦点层。
  bool _imeComposing = false;
  bool _insideNonFilterKeyHandler = false;
  FocusNode? _nonFilterKeyNode;
  FocusOnKeyEventCallback? _previousNonFilterKeyHandler;

  late final FocusOnKeyEventCallback _nonFilterKeyHandler = _handleNonFilterKeyEvent;

  FocusNode get _focusNode => widget.config.focusNode ?? _ownFocusNode;

  ScrollController get _scrollController => widget.config.scrollController ?? _ownScrollController;

  String get _panelSemanticsIdentifier => 'el-select-options-${identityHashCode(_semanticsIdentity)}';

  List<_ResolvedSelectOption<T>> get _options => _resolveSelectOptions(widget.config.children);

  List<_ResolvedSelectOption<T>> get _filteredOptions {
    final options = _options;
    if (!widget.config.enableFilter || _query.isEmpty) return options;
    final callback = widget.config.optionFilter;
    final normalized = _query.toLowerCase();
    if (callback != null) {
      return [
        for (final option in options)
          if (callback(option.source, _query)) option,
      ];
    }
    final legacyCallback = widget.config.filterCallback;
    if (legacyCallback != null) {
      final filtered = legacyCallback(_materialEntries(options), _query);
      return [
        for (final option in options)
          if (filtered.any((entry) => entry.value == option.value)) option,
      ];
    }
    return [
      for (final option in options)
        if (option.label.toLowerCase().contains(normalized)) option,
    ];
  }

  @override
  void initState() {
    super.initState();
    // 非筛选 trigger 自己处理 Tab（见 _handleNonFilterKeyEvent），不再依赖节点的
    // Tab 遍历开关；菜单用方向键移动 active。
    _ownFocusNode = FocusNode(debugLabel: 'ElSelect');
    _portal.addListener(_handlePortalChanged);
    _inputControl.addListener(_handleInputControlChanged);
    _focusNode.addListener(_handleFocusChanged);
    _focusReported = _focusNode.hasFocus;
    _correctActive(preferSelected: true);
    _bindNonFilterKeyHandler();
  }

  @override
  void didUpdateWidget(_ElSelectBody<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focusNodeChanged = widget.config.focusNode != oldWidget.config.focusNode;
    final focusModeChanged =
        widget.config.enableFilter != oldWidget.config.enableFilter ||
        widget.config.enabled != oldWidget.config.enabled;
    if (focusNodeChanged) {
      final oldFocusNode = oldWidget.config.focusNode ?? _ownFocusNode;
      final reportBlur = _focusReported;
      oldFocusNode.removeListener(_handleFocusChanged);
      _focusSession++;
      _focusNode.addListener(_handleFocusChanged);
      _focusReported = false;
      _optionPointerActive = false;
      _reopenRequested = false;
      _exitSettledTimer?.cancel();
      _exitSettledTimer = null;
      _portal.close();
      _query = '';
      _activeIndex = null;
      final session = _focusSession;
      scheduleMicrotask(() {
        if (!mounted || session != _focusSession) return;
        if (_focusNode.hasFocus) {
          _focusReported = true;
        } else if (reportBlur) {
          widget.onBlur();
        }
      });
    }
    if (!widget.config.enabled) {
      _portal.close();
      _focusNode.unfocus();
    }
    if (focusNodeChanged || focusModeChanged) {
      _bindNonFilterKeyHandler();
    }
    if (!focusNodeChanged || _focusNode.hasFocus) {
      _correctActive(
        preferSelected: widget.value != oldWidget.value || widget.config.children != oldWidget.config.children,
      );
    }
  }

  @override
  void dispose() {
    _detachNonFilterKeyHandler();
    _listenedController?.removeListener(_handleEditableVisualChanged);
    _inputControl.removeListener(_handleInputControlChanged);
    _focusNode.removeListener(_handleFocusChanged);
    _portal
      ..removeListener(_handlePortalChanged)
      ..close()
      ..dispose();
    _exitSettledTimer?.cancel();
    // Portal 退场会比 trigger 多存活 90ms；等滚动位置真正 detach 后再销毁，
    // 避免退场层读取已 dispose 的 controller，同时不延长外部 controller 生命周期。
    _panel.dispose();
    _ownScrollController.disposeWhenDetached();
    _ownFocusNode.dispose();
    super.dispose();
  }

  /// 在任何构建之前把 handler 装到节点上。
  ///
  /// 必须同步安装：ElView 的焦点宿主会在构建时把「当前 handler」收作自己的
  /// previous 并把自己装到最外层；若延到帧尾再装，记下的 previous 就是 ElView
  /// 的 wrapper，两边互相链回去会形成调用回环。
  void _bindNonFilterKeyHandler() {
    _detachNonFilterKeyHandler();
    if (!widget.config.enabled || widget.config.enableFilter) return;
    final node = _focusNode;
    _nonFilterKeyNode = node;
    _previousNonFilterKeyHandler = node.onKeyEvent;
    node.onKeyEvent = _nonFilterKeyHandler;
  }

  void _detachNonFilterKeyHandler() {
    final node = _nonFilterKeyNode;
    if (node == null) return;
    if (identical(node.onKeyEvent, _nonFilterKeyHandler)) {
      node.onKeyEvent = _previousNonFilterKeyHandler;
    }
    _nonFilterKeyNode = null;
    _previousNonFilterKeyHandler = null;
  }

  KeyEventResult _handleNonFilterKeyEvent(FocusNode node, KeyEvent event) {
    if (!mounted || widget.config.enableFilter || !widget.config.enabled || !identical(node, _focusNode)) {
      return KeyEventResult.ignored;
    }
    // ElView wrapper 与自身 handler 可能互相链成环（双方都把对方记作 previous），
    // 重入即视为「外层已经处理过本键」，直接放行。
    if (_insideNonFilterKeyHandler) return KeyEventResult.ignored;
    _insideNonFilterKeyHandler = true;
    try {
      return _handleNonFilterKeyEventBody(node, event);
    } finally {
      _insideNonFilterKeyHandler = false;
    }
  }

  KeyEventResult _handleNonFilterKeyEventBody(FocusNode node, KeyEvent event) {
    final previous = _previousNonFilterKeyHandler;
    final previousResult = previous?.call(node, event);
    if (previousResult != null && previousResult != KeyEventResult.ignored) {
      return previousResult;
    }
    final result = _handleKeyEvent(node, event);
    if (result != KeyEventResult.ignored) return result;
    if ((event is KeyDownEvent || event is KeyRepeatEvent) && event.logicalKey == LogicalKeyboardKey.tab) {
      final keyboard = HardwareKeyboard.instance;
      if (keyboard.isControlPressed || keyboard.isMetaPressed || keyboard.isAltPressed) {
        return KeyEventResult.ignored;
      }
      final moved = keyboard.isShiftPressed ? node.previousFocus() : node.nextFocus();
      return moved ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
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
    _portalOpen = open;
    setState(() {
      if (!open) {
        _optionPointerActive = false;
        _query = '';
        _correctActive(preferSelected: true);
        _reopenRequested = false;
        _exitSettledTimer?.cancel();
        // 退场面板仍持有同一个 ScrollController；在它摘树前延迟重开，避免
        // 快速关闭/重开时一个 controller 同时附着两个滚动位置。
        _exitSettledTimer = Timer(const Duration(milliseconds: 100), () {
          _exitSettledTimer = null;
          if (!mounted || !_reopenRequested || !widget.config.enabled) return;
          _reopenRequested = false;
          _open();
        });
      }
    });
  }

  void _handleFocusChanged() {
    final focusNode = _focusNode;
    final session = _focusSession;
    if (focusNode.hasFocus) {
      _focusReported = true;
      return;
    }
    // option 在 overlay sibling 中，mouse down 会被全局焦点仲裁视为
    // 点击非聚焦区。这一次是 Select 内部交互，要先把焦点交回
    // trigger，否则慢按会在 tap 前关闭面板并用旧值触发 blur 校验。
    if (_optionPointerActive && _portal.isOpen) {
      // FocusManager 正在应用本次 unfocus，同步 request 会被后续状态
      // 覆盖；微任务里再交回可确保快按与慢按都保持 trigger 聚焦。
      scheduleMicrotask(() {
        if (!mounted || session != _focusSession || !identical(focusNode, _focusNode) || !widget.config.enabled) {
          return;
        }
        focusNode.requestFocus();
      });
      return;
    }
    final reportBlur = _focusReported;
    _focusReported = false;
    // FocusManager 正在遍历本轮脏节点；此时同步关闭 Portal 会让 overlay 的
    // 焦点门禁再次改写同一个 dirty set，触发 ConcurrentModificationError。
    // 两级微任务让当前失焦通知与同轮 requestFocus 都先结算，再按最终焦点
    // 状态关闭 Portal；blur 仍按每次真实边沿通知，不能被立即回焦吞掉。
    scheduleMicrotask(() {
      scheduleMicrotask(() {
        if (!mounted || session != _focusSession || !identical(focusNode, _focusNode)) {
          return;
        }
        if (!focusNode.hasFocus) {
          _reopenRequested = false;
          _portal.close();
        }
        if (reportBlur) widget.onBlur();
      });
    });
  }

  void _handleOptionPointerDown() {
    _optionPointerActive = true;
  }

  void _handleOptionPointerEnd() {
    _optionPointerActive = false;
  }

  void _correctActive({required bool preferSelected}) {
    final filtered = _filteredOptions.where((option) => !option.disabled).toList();
    if (filtered.isEmpty) {
      _activeIndex = null;
      return;
    }
    final search = widget.config.searchCallback;
    if (!preferSelected && widget.config.enableSearch && _query.isNotEmpty && search != null) {
      final index = search(_materialEntries(filtered), _query);
      if (index != null && index >= 0 && index < filtered.length) {
        _activeIndex = filtered[index].index;
        return;
      }
    }
    final selected = filtered.where((option) => option.value == widget.value).firstOrNull;
    if (preferSelected && selected != null) {
      _activeIndex = selected.index;
      return;
    }
    if (!filtered.any((option) => option.index == _activeIndex)) {
      _activeIndex = selected?.index ?? filtered.first.index;
    }
  }

  void _open() {
    if (!widget.config.enabled || _portal.isOpen) return;
    if (_exitSettledTimer != null) {
      _reopenRequested = true;
      return;
    }
    _query = '';
    _correctActive(preferSelected: true);
    _portal.open();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureActiveVisible());
  }

  void _toggleFromPointer() {
    if (!widget.config.enabled) return;
    if (_portal.isOpen) {
      if (!widget.config.enableFilter) _portal.close();
    } else {
      _open();
    }
  }

  void _handleQueryChanged(String value) {
    if (!widget.config.enableFilter) return;
    // ElInput 的值通道会把父级程序性回灌也派成 onChanged；与本轮已渲染文本
    // 相同的是显示同步，不是用户 query，不能因此重开刚关闭的菜单。
    if (value == _renderedFieldText) return;
    if (!_portal.isOpen) _open();
    setState(() {
      _query = value;
      _correctActive(preferSelected: false);
    });
  }

  void _expandFromSemantics() {
    if (!widget.config.enabled || _portal.isOpen) return;
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
    _open();
  }

  void _collapseFromSemantics() {
    if (!_portal.isOpen) return;
    _reopenRequested = false;
    _portal.close();
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;
    final overlayControlKey = _isSelectOverlayControlKey(key);
    if ((_inputControl.controller?.hasActiveImeComposition ?? false) && overlayControlKey) {
      return KeyEventResult.skipRemainingHandlers;
    }
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (_hasSelectOverlayModifier() && overlayControlKey) {
      return key == LogicalKeyboardKey.escape ? KeyEventResult.skipRemainingHandlers : KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.tab) {
      _portal.close();
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (!_portal.isOpen) return KeyEventResult.ignored;
      _portal.close();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      if (!_portal.isOpen) {
        _open();
      } else {
        _moveActive(key == LogicalKeyboardKey.arrowDown ? 1 : -1);
      }
      return KeyEventResult.handled;
    }
    if (_portal.isOpen && (key == LogicalKeyboardKey.home || key == LogicalKeyboardKey.end)) {
      _moveToEdge(end: key == LogicalKeyboardKey.end);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      _portal.isOpen ? _selectActive() : _open();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      if (widget.config.enableFilter && _portal.isOpen) {
        return KeyEventResult.ignored;
      }
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      _portal.isOpen ? _selectActive() : _open();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _moveActive(int delta) {
    final options = _filteredOptions.where((option) => !option.disabled).toList();
    if (options.isEmpty) return;
    final current = options.indexWhere((option) => option.index == _activeIndex);
    final next = current < 0 ? (delta > 0 ? 0 : options.length - 1) : (current + delta).clamp(0, options.length - 1);
    setState(() => _activeIndex = options[next].index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureActiveVisible());
  }

  void _moveToEdge({required bool end}) {
    final options = _filteredOptions.where((option) => !option.disabled).toList();
    if (options.isEmpty) return;
    setState(() => _activeIndex = (end ? options.last : options.first).index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureActiveVisible());
  }

  void _selectActive() {
    final active = _filteredOptions.where((option) => option.index == _activeIndex).firstOrNull;
    if (active == null) return;
    _select(active);
  }

  void _select(_ResolvedSelectOption<T> option) {
    if (!mounted || option.disabled) return;
    widget.onSelected(option.value);
    if (widget.config.closeBehavior != DropdownMenuCloseBehavior.none) {
      _portal.close();
    }
  }

  void _ensureActiveVisible() {
    if (!mounted || !_portal.isOpen) return;
    final controller = _scrollController;
    if (!controller.hasClients) return;
    final options = _filteredOptions;
    final position = options.indexWhere((option) => option.index == _activeIndex);
    if (position < 0) return;
    final itemHeight = _selectOptionHeight(_compact);
    final start = position * itemHeight;
    final end = start + itemHeight;
    final metrics = controller.position;
    if (start < metrics.pixels) {
      metrics.jumpTo(start.clamp(metrics.minScrollExtent, metrics.maxScrollExtent));
    } else if (end > metrics.pixels + metrics.viewportDimension) {
      metrics.jumpTo((end - metrics.viewportDimension).clamp(metrics.minScrollExtent, metrics.maxScrollExtent));
    }
  }

  bool get _compact => context.elComponentCompact(widget.config.style);

  String get _selectedLabel {
    for (final option in _options) {
      if (option.value == widget.value) return option.label;
    }
    return '';
  }

  Widget? _trailing(double iconSize) {
    if (!widget.config.showTrailingIcon) return null;
    if (_portal.isOpen) {
      return elContent(
        widget.config.selectedTrailingIcon ?? ElIcon(ElIcons.arrowUp, size: iconSize),
        iconSize: iconSize,
      ) as Widget;
    }
    return elContent(widget.config.trailingIcon ?? ElIcon(ElIcons.arrowDown, size: iconSize), iconSize: iconSize)
        as Widget;
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final inputText = config.enableFilter && _portal.isOpen ? _query : _selectedLabel;
    _renderedFieldText = inputText;
    final panelOptions = _filteredOptions;
    final activeIndex = _activeIndex;
    final menuHeight = config.menuHeight;
    final scrollController = _scrollController;
    final compact = _compact;
    final inputIconSize = config.style?.iconSize ?? elInputDefaultIconSize(compact);
    final panelStyle = config.panelStyle;
    final optionStyle = config.optionStyle;
    final onSelected = _select;
    final trigger = ElView(
      style: ElStyle(width: config.width ?? 240),

      event: !config.enabled
          ? ((config.enabled ? ElEvent(onTap: (_) => _toggleFromPointer()) : null) ?? ElEvent()).copyWith(
              disabled: true,
            )
          : (config.enabled ? ElEvent(onTap: (_) => _toggleFromPointer()) : null),
      // 非筛选 trigger 自己处理 Tab（见 _handleNonFilterKeyEvent），不参与
      // ElView 默认 Tab 遍历；筛选态由输入框内部处理，不继承本开关。
      focusNode: config.enabled && !config.enableFilter ? _focusNode : null,
      semantics: ElSemantics(
        mergeDescendants: true,
        properties: SemanticsProperties(
          // 当前 Flutter 的 SemanticsRole.comboBox 校验器仍是 unimplemented，
          // 开启语义会直接断言；先用真实 textField + expanded/controls 合同。
          expanded: _portal.isOpen,
          enabled: config.enabled,
          readOnly: !config.enabled || !config.enableFilter,
          controlsNodes: <String>{_panelSemanticsIdentifier},
          onExpand: config.enabled && !_portal.isOpen ? _expandFromSemantics : null,
          onCollapse: _portal.isOpen ? _collapseFromSemantics : null,
        ),
      ),
      child: _ElSelectField(
        value: inputText,
        onChanged: _handleQueryChanged,
        control: _inputControl,
        disabled: !config.enabled,
        readOnly: !config.enableFilter,
        prefix: config.leadingIcon,
        suffix: _trailing(inputIconSize),
        placeholder: config.hintText,
        focusNode: config.enableFilter ? _focusNode : null,
        onKeyEvent: config.enableFilter ? _handleKeyEvent : null,
        keyboardType: config.keyboardType,
        textInputAction: config.textInputAction,
        inputFormatters: config.inputFormatters ?? const [],
        style: config.style,
        semanticLabel: config.semanticLabel,
        caretColor: config.enableFilter ? null : const Color(0x00000000),
        autofillHints: null,
      ),
    );

    _panel.value = _ElSelectPanel<T>(
      semanticsIdentifier: _panelSemanticsIdentifier,
      options: panelOptions,
      activeIndex: activeIndex,
      menuHeight: menuHeight,
      scrollController: scrollController,
      compact: compact,
      menuStyle: panelStyle,
      optionStyle: optionStyle,
      onOptionPointerDown: _handleOptionPointerDown,
      onOptionPointerEnd: _handleOptionPointerEnd,
      onSelected: onSelected,
    );

    // 裸组件没有官方 Overlay 时保留输入，不挂载候选面板。
    if (Overlay.maybeOf(context) == null) return trigger;
    return ElPortal(
      // 下拉选项复用输入框的键盘与 IME 会话。
      captureFocus: false,
      restoreFocus: false,
      controller: _portal,
      anchor: config.anchor,
      exitDuration: _selectMenuExitDuration,
      overlayBuilder: (_) => ValueListenableBuilder<Widget>(valueListenable: _panel, builder: (_, panel, _) => panel),
      closeOnEscape: !_imeComposing,
      hideWhenUnlinked: true,
      child: trigger,
    );
  }
}

class _ElSelectField extends ElInput {
  const _ElSelectField({
    required super.value,
    required super.onChanged,
    required super.control,
    required super.disabled,
    required super.readOnly,
    super.prefix,
    super.suffix,
    super.placeholder,
    super.focusNode,
    super.onKeyEvent,
    super.keyboardType,
    super.textInputAction,
    super.inputFormatters,
    super.style,
    super.semanticLabel,
    super.caretColor,
    super.autofillHints,
  });

  @override
  bool get formBindable => false;
}
