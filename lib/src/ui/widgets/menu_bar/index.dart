import 'dart:async' show scheduleMicrotask;
import 'dart:ui' show SemanticsRole, TextDecoration;

import 'package:flutter_base/dart.dart' show el;
import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_base/src/ui/utils/internal/focus.dart';

// 焦点已进入其他 scope 时，页面菜单栏不接管该作用域的全局按键。
bool _focusCapturedAbove(FocusNode node) {
  final scope = FocusManager.instance.primaryFocus?.nearestScope;
  return scope != null && !identical(scope, node) && !node.ancestors.contains(scope);
}

/// 菜单栏中的顶级菜单模型。
@immutable
class ElMenuBarItem {
  /// 创建顶级菜单。
  const ElMenuBarItem({
    required this.label,
    required this.items,
    this.accessKey,
    this.disabled = false,
    this.style,
    this.semanticLabel,
  });

  /// 顶级菜单标题。
  final String label;

  /// 下拉面板中的命令、分隔线与子菜单。
  final List<ElContextMenuItem> items;

  /// Alt 单字符助记键；应在同一菜单栏内保持唯一。
  final String? accessKey;

  /// 是否禁用整个顶级菜单。
  final bool disabled;

  /// 合并到该顶级菜单行为面上的附加样式。
  final ElStyle? style;

  /// 辅助技术读取的名称；null 时使用 [label]。
  final String? semanticLabel;
}

/// 宿主决定全局快捷键归属：返回 null 不参与，数值较大者优先。
///
/// [focusedContext] 是当前主焦点上下文，[menuOpen] 表示该菜单栏有已打开的面板。
/// 同优先级取最近交互的菜单栏；跨 Flutter View 的过滤由菜单栏内部负责。
typedef ElMenuBarShortcutPriority = int? Function(BuildContext? focusedContext, bool menuOpen);

/// 可换肤的桌面菜单栏，复用 [ElContextMenu] 的下拉与子菜单行为。
///
/// 主指针按下打开，打开后悬停切换；方向键、Alt / F10、助记键由本组件处理。
/// 焦点捕获由 ElOverlay 管理，Esc 逐级返回，Tab 关闭非空菜单后继续遍历。
/// [style] 与 [itemStyle] 声明外观，不需要额外包装按钮或列表组件。
class ElMenuBar extends StatefulWidget {
  /// 创建菜单栏。
  const ElMenuBar({
    super.key,
    required this.items,
    this.disabled = false,
    this.globalShortcuts = true,
    this.menu,
    this.shortcutPriority,
    this.rootOverlay = false,
    this.style,
    this.itemStyle,
    this.itemStyleBuilder,
    this.semanticLabel = '菜单栏',
  });

  /// 按视觉顺序声明的顶级菜单。
  final List<ElMenuBarItem> items;

  /// 是否禁用整条菜单栏。
  final bool disabled;

  /// 是否在所属活动窗口或 Flutter View 内响应 Alt、F10 与 Alt+助记键。
  final bool globalShortcuts;

  /// 下拉面板外观；null 时使用 el.globalContextMenus 注册的平台菜单。
  final ElContextMenu? menu;

  /// 多窗口等宿主的快捷键归属规则；不传时所有可交互菜单栏使用优先级 0。
  final ElMenuBarShortcutPriority? shortcutPriority;

  /// 下拉面板使用的弹层宿主类型。
  final bool rootOverlay;

  /// 合并到菜单栏根节点上的附加样式。
  final ElStyle? style;

  /// 合并到所有顶级菜单行为面上的公共样式。
  final ElStyle? itemStyle;

  /// 根据菜单是否打开选择普通样式，再叠加 [itemStyle] 与单项样式。
  final ElStyle? Function(BuildContext context, bool open)? itemStyleBuilder;

  /// 辅助技术读取的菜单栏名称。
  final String? semanticLabel;

  @override
  State<ElMenuBar> createState() => _MenuBarState();
}

enum _MenuBarCloseIntent { none, escape, tabForward, tabBackward, selection, pointerToggle, keyboardToggle }

class _MenuBarState extends State<ElMenuBar> {
  final List<FocusNode> _focusNodes = <FocusNode>[];
  final List<GlobalKey> _itemKeys = <GlobalKey>[];
  ElContextMenuHandle? _menuEntry;
  FocusNode? _restoreFocusTo;
  FocusNode? _lastExternalFocus;
  FocusNode? _closingPopupFocus;
  int? _viewId;
  int _itemsRevision = 0;
  int _focusedIndex = 0;
  int? _activeIndex;
  int _interactionSerial = 0;
  bool _menuMode = false;
  bool _showAccessKeys = false;
  bool _selectionMovedFocus = false;
  bool _popupEscapeInFlight = false;
  _MenuBarCloseIntent _closeIntent = _MenuBarCloseIntent.none;

  bool get _ownsOpenMenu => _menuEntry?.isOpen ?? false;

  bool get _canOwnGlobalShortcuts =>
      mounted &&
      widget.globalShortcuts &&
      !widget.disabled &&
      _viewId != null &&
      _firstEnabledIndex() != null &&
      (_ownsOpenMenu
          ? _menuEntry!.hasFocus
          // 更高层弹层（对话框、context menu）持有焦点时，页面内的菜单栏不能抢全局键。
          : _focusNodes.any((node) => node.canRequestFocus && FocusUtil.isVisible(node) && !_focusCapturedAbove(node)));

  @override
  void initState() {
    super.initState();
    _createHandles();
    FocusManager.instance.addListener(_handlePrimaryFocusChanged);
    _MenuBarShortcutDispatcher.instance.register(this);
    _rememberExternalFocus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewId = View.of(context).viewId;
  }

  @override
  void didUpdateWidget(covariant ElMenuBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final popupModelChanged = !_menuBarPopupModelsEqual(oldWidget.items, widget.items);
    if (popupModelChanged) _itemsRevision++;
    if (oldWidget.items.length != widget.items.length) {
      _abandonOpenMenu();
      _disposeHandles();
      _createHandles();
    } else {
      _syncHandleConfiguration();
    }
    final active = _activeIndex;
    if (widget.disabled || (active != null && !_isItemEnabled(active))) {
      _closeFor(_MenuBarCloseIntent.keyboardToggle);
      return;
    }
    if (popupModelChanged && active != null && (_menuEntry?.isOpen ?? false)) {
      final revision = _itemsRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            revision != _itemsRevision ||
            _activeIndex != active ||
            !(_menuEntry?.isOpen ?? false) ||
            !_isItemEnabled(active)) {
          return;
        }
        _openMenu(active, initialFocus: .first);
      });
    }
  }

  @override
  void dispose() {
    _MenuBarShortcutDispatcher.instance.unregister(this);
    FocusManager.instance.removeListener(_handlePrimaryFocusChanged);
    final entry = _menuEntry;
    _menuEntry = null;
    entry?.close();
    _disposeHandles();
    super.dispose();
  }

  void _createHandles() {
    for (var index = 0; index < widget.items.length; index++) {
      _focusNodes.add(FocusNode(debugLabel: 'ElMenuBarItem($index ${widget.items[index].label})'));
      _itemKeys.add(GlobalKey(debugLabel: 'ElMenuBarItem($index)'));
    }
    _focusedIndex = _firstEnabledIndex() ?? 0;
    _syncHandleConfiguration();
  }

  void _disposeHandles() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    _focusNodes.clear();
    _itemKeys.clear();
  }

  void _syncHandleConfiguration() {
    final fallback = _firstEnabledIndex();
    if (fallback != null && (_focusedIndex >= widget.items.length || !_isItemEnabled(_focusedIndex))) {
      _focusedIndex = fallback;
    }
    for (var index = 0; index < _focusNodes.length; index++) {
      final node = _focusNodes[index];
      node
        ..debugLabel = 'ElMenuBarItem($index ${widget.items[index].label})'
        ..canRequestFocus = _isItemEnabled(index)
        ..skipTraversal = index != _focusedIndex;
    }
  }

  bool _isItemEnabled(int index) =>
      index >= 0 && index < widget.items.length && !widget.disabled && !widget.items[index].disabled;

  int? _firstEnabledIndex() {
    for (var index = 0; index < widget.items.length; index++) {
      if (_isItemEnabled(index)) return index;
    }
    return null;
  }

  int? _lastEnabledIndex() {
    for (var index = widget.items.length - 1; index >= 0; index--) {
      if (_isItemEnabled(index)) return index;
    }
    return null;
  }

  int? _nextEnabledIndex(int current, int delta) {
    if (widget.items.isEmpty) return null;
    for (var step = 1; step <= widget.items.length; step++) {
      final index = (current + delta * step) % widget.items.length;
      if (_isItemEnabled(index)) return index;
    }
    return null;
  }

  void _rememberExternalFocus() {
    final current = FocusManager.instance.primaryFocus;
    if (current != null && current.context != null && !_focusNodes.contains(current) && !_menuMode) {
      _lastExternalFocus = current;
    }
  }

  void _handlePrimaryFocusChanged() {
    if (!mounted) return;
    final current = FocusManager.instance.primaryFocus;
    final index = current == null ? -1 : _focusNodes.indexOf(current);
    if (index >= 0) {
      _interactionSerial = _MenuBarShortcutDispatcher.instance.touch(this);
      if (_focusedIndex != index) {
        setState(() {
          _focusedIndex = index;
          _syncHandleConfiguration();
        });
      }
      return;
    }
    _rememberExternalFocus();
  }

  void _preparePointerActivation(int index) {
    _interactionSerial = _MenuBarShortcutDispatcher.instance.touch(this);
    if (_menuMode) return;
    final current = FocusManager.instance.primaryFocus;
    if (current != null && current.context != null && !_focusNodes.contains(current)) {
      _restoreFocusTo = current;
    } else {
      _restoreFocusTo = _lastExternalFocus;
    }
    _focusedIndex = index;
    _syncHandleConfiguration();
  }

  void _captureRestoreFocus() {
    if (_menuMode && _restoreFocusTo != null) return;
    final current = FocusManager.instance.primaryFocus;
    _restoreFocusTo = current != null && current.context != null && !_focusNodes.contains(current)
        ? current
        : _lastExternalFocus;
  }

  void _focusItem(int index, {ElFocusReason reason = .keyboard}) {
    if (!_isItemEnabled(index)) return;
    _focusedIndex = index;
    _syncHandleConfiguration();
    _interactionSerial = _MenuBarShortcutDispatcher.instance.touch(this);
    final node = _focusNodes[index];
    if (!node.canRequestFocus) return;
    FocusUtil.markReason(node, reason);
    node.requestFocus();
    FocusManager.instance.applyFocusChangesIfNeeded();
  }

  void _setAccessKeysVisible(bool value) {
    if (!mounted || _showAccessKeys == value) return;
    setState(() => _showAccessKeys = value);
  }

  void _toggleKeyboardMode() {
    if (!_canOwnGlobalShortcuts) return;
    if (_menuMode) {
      _closeFor(_MenuBarCloseIntent.keyboardToggle);
      return;
    }
    final index = _firstEnabledIndex();
    if (index == null) return;
    _captureRestoreFocus();
    setState(() {
      _menuMode = true;
      _showAccessKeys = true;
      _focusedIndex = index;
      _syncHandleConfiguration();
    });
    _focusItem(index);
  }

  bool _activateAccessKey(String key) {
    if (!mounted || widget.disabled || key.isEmpty) return false;
    final normalized = key.toLowerCase();
    for (var index = 0; index < widget.items.length; index++) {
      final accessKey = widget.items[index].accessKey;
      if (!_isItemEnabled(index) || accessKey == null || accessKey.toLowerCase() != normalized) {
        continue;
      }
      _captureRestoreFocus();
      _showAccessKeys = true;
      _openMenu(index, initialFocus: .first, keyboard: true);
      return true;
    }
    return false;
  }

  void _activateItem(int index, {bool keyboard = false}) {
    if (!_isItemEnabled(index)) return;
    if (_menuEntry != null) {
      if (_activeIndex == index) {
        _closeFor(_MenuBarCloseIntent.pointerToggle);
      } else {
        _openMenu(index, initialFocus: .first, keyboard: keyboard);
      }
      return;
    }
    _captureRestoreFocus();
    _openMenu(index, initialFocus: .first, keyboard: keyboard);
  }

  void _hoverItem(int index) {
    if (!(_menuEntry?.isOpen ?? false) || _activeIndex == index) return;
    _openMenu(index, initialFocus: .first);
  }

  bool _handleItemKey(int index, ElEventDetails event) {
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final open = _menuEntry?.isOpen ?? false;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      final physicalDelta = key == LogicalKeyboardKey.arrowRight ? 1 : -1;
      final delta = direction == TextDirection.ltr ? physicalDelta : -physicalDelta;
      final target = _nextEnabledIndex(index, delta);
      if (target == null) return false;
      _showAccessKeys = true;
      if (open) {
        _openMenu(target, initialFocus: .first, keyboard: true);
      } else {
        setState(() {
          _menuMode = true;
          _showAccessKeys = true;
        });
        _focusItem(target);
      }
      return true;
    }
    if (key == LogicalKeyboardKey.home || key == LogicalKeyboardKey.end) {
      final target = key == LogicalKeyboardKey.home ? _firstEnabledIndex() : _lastEnabledIndex();
      if (target == null) return false;
      if (open) {
        _openMenu(target, initialFocus: .first, keyboard: true);
      } else {
        _focusItem(target);
      }
      return true;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      _showAccessKeys = true;
      _openMenu(index, initialFocus: key == LogicalKeyboardKey.arrowUp ? .last : .first, keyboard: true);
      return true;
    }
    if (key == LogicalKeyboardKey.escape && _menuMode && !open) {
      if (_popupEscapeInFlight) {
        _popupEscapeInFlight = false;
        final closing = _menuEntry;
        if (closing != null) _handleEntryClosed(closing, index);
        return true;
      }
      final closing = _menuEntry;
      if (closing != null) _handleEntryClosed(closing, index);
      _leaveMenuMode(restoreFocus: true);
      return true;
    }
    if (key == LogicalKeyboardKey.tab && _menuMode && !open) {
      setState(() {
        _menuMode = false;
        _showAccessKeys = false;
        _restoreFocusTo = null;
      });
      return false;
    }
    final hasModifier = keyboard.isControlPressed || keyboard.isAltPressed || keyboard.isMetaPressed;
    if (_menuMode && !hasModifier) {
      final character = event.character ?? key?.keyLabel ?? '';
      if (character.length == 1 && _activateAccessKey(character)) return true;
    }
    return false;
  }

  void _switchOpenMenu(int delta) {
    final active = _activeIndex;
    if (active == null || !(_menuEntry?.isOpen ?? false)) return;
    final target = _nextEnabledIndex(active, delta);
    if (target == null) return;
    _openMenu(target, initialFocus: .first, keyboard: true);
  }

  void _openMenu(int index, {required ContextMenuInitialFocus initialFocus, bool keyboard = false}) {
    if (!_isItemEnabled(index)) return;
    if (!_menuMode) _captureRestoreFocus();
    _menuMode = true;
    _closeIntent = _MenuBarCloseIntent.none;
    _selectionMovedFocus = false;
    _closingPopupFocus = null;
    final triggerContext = _itemKeys[index].currentContext;
    final render = triggerContext?.findRenderObject();
    if (triggerContext == null || render is! RenderBox || !render.attached || !render.hasSize) {
      if (mounted) setState(() => _activeIndex = null);
      return;
    }

    final previous = _menuEntry;
    _menuEntry = null;
    previous?.close();
    _focusItem(index, reason: keyboard ? .keyboard : .lifecycle);
    setState(() {
      _activeIndex = index;
      _focusedIndex = index;
      _syncHandleConfiguration();
    });
    final entry = el.showContextMenu(
      triggerContext,
      position: render.localToGlobal(Offset(0, render.size.height)),
      items: _wrapMenuItems(index, widget.items[index].items),
      menu: widget.menu,
      rootOverlay: widget.rootOverlay,
      initialFocus: initialFocus,
      restoreFocus: false,
      onNavigatePrevious: () => _switchOpenMenu(-1),
      onNavigateNext: () => _switchOpenMenu(1),
    );
    _menuEntry = entry;
    if (entry == null) {
      setState(() => _activeIndex = null);
      return;
    }
    var closing = false;
    entry.addListener(() {
      if (entry.isOpen || closing) return;
      closing = true;
      // 等当前按键/命令回调写完关闭意图即交接，焦点不等待退场动画。
      scheduleMicrotask(() => _handleEntryClosed(entry, index));
    });
    // 宿主销毁直接完成 closed，不一定派发逻辑关闭通知。
    entry.closed.then((_) => _handleEntryClosed(entry, index));
  }

  List<ElContextMenuItem> _wrapMenuItems(
    int topIndex,
    List<ElContextMenuItem> items, {
    List<int> path = const <int>[],
  }) => [
    for (var index = 0; index < items.length; index++) _wrapMenuItem(topIndex, items[index], <int>[...path, index]),
  ];

  ElContextMenuItem _wrapMenuItem(int topIndex, ElContextMenuItem item, List<int> path) {
    if (item.isDivider) return const ElContextMenuItem.divider();
    final children = item.children;
    return ElContextMenuItem(
      label: item.label,
      icon: item.icon,
      enabled: item.enabled,
      checked: item.checked,
      shortcut: item.shortcut,
      children: children == null ? null : _wrapMenuItems(topIndex, children, path: path),
      onSelect: item.hasChildren
          ? item.onSelect
          : () {
              final before = FocusManager.instance.primaryFocus;
              _closingPopupFocus = before;
              _closeIntent = _MenuBarCloseIntent.selection;
              _latestMenuItem(topIndex, path)?.onSelect?.call();
              final after = FocusManager.instance.primaryFocus;
              _selectionMovedFocus = !identical(before, after) && after != null && after.context != null;
            },
    );
  }

  ElContextMenuItem? _latestMenuItem(int topIndex, List<int> path) {
    if (topIndex < 0 || topIndex >= widget.items.length) return null;
    var items = widget.items[topIndex].items;
    ElContextMenuItem? result;
    for (final index in path) {
      if (index < 0 || index >= items.length) return null;
      result = items[index];
      items = result.children ?? const <ElContextMenuItem>[];
    }
    return result;
  }

  void _notePopupKey(KeyEvent event) {
    if (_menuEntry == null || event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _popupEscapeInFlight = true;
      _closeIntent = _MenuBarCloseIntent.escape;
    } else if (event.logicalKey == LogicalKeyboardKey.tab) {
      _closeIntent = HardwareKeyboard.instance.isShiftPressed
          ? _MenuBarCloseIntent.tabBackward
          : _MenuBarCloseIntent.tabForward;
    }
  }

  void _handleEntryClosed(ElContextMenuHandle entry, int index) {
    if (!mounted || !identical(_menuEntry, entry)) return;
    final intent = _closeIntent;
    setState(() {
      _menuEntry = null;
      _activeIndex = null;
      _closeIntent = _MenuBarCloseIntent.none;
    });
    switch (intent) {
      case _MenuBarCloseIntent.escape:
        setState(() {
          _menuMode = true;
          _showAccessKeys = true;
        });
        _focusItem(index);
        return;
      case _MenuBarCloseIntent.tabForward:
        _leaveMenuMode(restoreFocus: false);
        _traverseFrom(index, forward: true);
        return;
      case _MenuBarCloseIntent.tabBackward:
        _leaveMenuMode(restoreFocus: false);
        _traverseFrom(index, forward: false);
        return;
      case _MenuBarCloseIntent.selection:
        _leaveMenuMode(restoreFocus: !_selectionMovedFocus);
        return;
      case _MenuBarCloseIntent.keyboardToggle:
        _leaveMenuMode(restoreFocus: true);
        return;
      case _MenuBarCloseIntent.pointerToggle:
      case _MenuBarCloseIntent.none:
        _leaveMenuMode(restoreFocus: false);
        return;
    }
  }

  void _traverseFrom(int index, {required bool forward}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index >= _focusNodes.length) return;
      _focusItem(index);
      if (forward) {
        _focusNodes[index].nextFocus();
      } else {
        _focusNodes[index].previousFocus();
      }
    });
  }

  void _closeFor(_MenuBarCloseIntent intent) {
    final entry = _menuEntry;
    if (entry == null) {
      _leaveMenuMode(restoreFocus: intent == _MenuBarCloseIntent.keyboardToggle);
      return;
    }
    _closingPopupFocus = FocusManager.instance.primaryFocus;
    _closeIntent = intent;
    entry.close();
  }

  void _leaveMenuMode({required bool restoreFocus}) {
    final target = restoreFocus ? _restoreFocusTo : null;
    final focusWhenLeaving = FocusManager.instance.primaryFocus;
    final closingPopupFocus = _closingPopupFocus;
    if (!mounted) return;
    setState(() {
      _menuMode = false;
      _showAccessKeys = false;
      _activeIndex = null;
      _restoreFocusTo = null;
      _selectionMovedFocus = false;
      _closingPopupFocus = null;
    });
    if (target == null || target.context?.mounted != true || !target.canRequestFocus || !FocusUtil.isVisible(target)) {
      return;
    }
    if (_shouldPreserveFocus(focusWhenLeaving, target, closingPopupFocus)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || target.context?.mounted != true || !target.canRequestFocus || !FocusUtil.isVisible(target)) {
        return;
      }
      // 命令可在同一帧末 requestFocus，先提交它的请求再判断是否需要归还。
      FocusManager.instance.applyFocusChangesIfNeeded();
      final current = FocusManager.instance.primaryFocus;
      if (_shouldPreserveFocus(current, target, closingPopupFocus)) return;
      target.requestFocus();
    });
  }

  bool _shouldPreserveFocus(FocusNode? current, FocusNode target, FocusNode? closingPopupFocus) {
    if (current == null ||
        current.context == null ||
        _focusNodes.contains(current) ||
        identical(current, closingPopupFocus)) {
      return false;
    }
    if (identical(current, target)) return true;
    if (current is! FocusScopeNode) return true;
    final currentRoute = ModalRoute.of(current.context!);
    final targetContext = target.context;
    final targetRoute = targetContext == null ? null : ModalRoute.of(targetContext);
    if (!identical(currentRoute, targetRoute) && (currentRoute != null || targetRoute != null)) {
      return true;
    }
    return false;
  }

  void _abandonOpenMenu() {
    final entry = _menuEntry;
    _menuEntry = null;
    entry?.close();
    _activeIndex = null;
    _menuMode = false;
    _showAccessKeys = false;
    _restoreFocusTo = null;
    _closingPopupFocus = null;
  }

  @override
  Widget build(BuildContext context) {
    final showAccessKeys = _showAccessKeys;
    return ElView(
      event: widget.disabled ? ElEvent(disabled: true) : null,
      semantics: ElSemantics(
        container: true,
        explicitChildNodes: true,
        role: widget.items.isEmpty ? null : SemanticsRole.menuBar,
        label: widget.semanticLabel,
      ),
      style: widget.style,
      child: Row(
        crossAxisAlignment: .center,
        children: [
          for (var index = 0; index < widget.items.length; index++)
            _MenuBarButton(
              key: _itemKeys[index],
              surfaceKey: ValueKey<String>('el-menu-bar-item-$index'),
              item: widget.items[index],
              focusNode: _focusNodes[index],
              disabled: !_isItemEnabled(index),
              selected: _activeIndex == index,
              showAccessKey: showAccessKeys,
              inheritedStyle: widget.itemStyle,
              styleBuilder: widget.itemStyleBuilder,
              onPointerDown: () {
                _preparePointerActivation(index);
                _activateItem(index);
              },
              onPointerEnter: () => _hoverItem(index),
              onPressed: (keyboard) => _activateItem(index, keyboard: keyboard),
              onKeyDown: (event) => _handleItemKey(index, event),
            ),
        ],
      ),
    );
  }
}

class _MenuBarButton extends StatefulWidget {
  const _MenuBarButton({
    super.key,
    required this.surfaceKey,
    required this.item,
    required this.focusNode,
    required this.disabled,
    required this.selected,
    required this.showAccessKey,
    required this.inheritedStyle,
    required this.styleBuilder,
    required this.onPointerDown,
    required this.onPointerEnter,
    required this.onPressed,
    required this.onKeyDown,
  });

  final Key surfaceKey;
  final ElMenuBarItem item;
  final FocusNode focusNode;
  final bool disabled;
  final bool selected;
  final bool showAccessKey;
  final ElStyle? inheritedStyle;
  final ElStyle? Function(BuildContext context, bool open)? styleBuilder;
  final VoidCallback onPointerDown;
  final VoidCallback onPointerEnter;
  final void Function(bool keyboard) onPressed;
  final bool Function(ElEventDetails event) onKeyDown;

  @override
  State<_MenuBarButton> createState() => _MenuBarButtonState();
}

class _MenuBarButtonState extends State<_MenuBarButton> {
  bool _spaceArmed = false;

  ElStyle _buildStyle(BuildContext context) => const ElStyle(alignment: .center)
      .merge(widget.styleBuilder?.call(context, widget.selected))
      .merge(_resolveMenuBarStyle(context, widget.inheritedStyle))
      .merge(_resolveMenuBarStyle(context, widget.item.style));

  void _consume(ElEventDetails event) {
    event.preventDefault();
    event.stopPropagation();
  }

  void _handleKeyDown(ElEventDetails event) {
    if (widget.onKeyDown(event)) {
      _spaceArmed = false;
      _consume(event);
      return;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      widget.onPressed(true);
      _consume(event);
    } else if (key == LogicalKeyboardKey.space) {
      _spaceArmed = true;
      _consume(event);
    } else if (key == LogicalKeyboardKey.escape) {
      _spaceArmed = false;
    }
  }

  void _handleKeyUp(ElEventDetails event) {
    if (event.logicalKey != LogicalKeyboardKey.space || !_spaceArmed) return;
    _spaceArmed = false;
    widget.onPressed(true);
    _consume(event);
  }

  @override
  Widget build(BuildContext context) {
    return ElView(
      key: widget.surfaceKey,

      style: _buildStyle(context),
      event: ElEvent(
        disabled: widget.disabled,
        onPointerDown: (event) {
          if (event.buttons != kPrimaryButton) return;
          widget.onPointerDown();
          event.preventDefault();
          event.stopPropagation();
        },
        onPointerEnter: (_) => widget.onPointerEnter(),
        onKeyDown: _handleKeyDown,
        onKeyUp: _handleKeyUp,
      ),
      focusNode: widget.disabled ? null : widget.focusNode,
      semantics: ElSemantics(
        container: true,
        mergeDescendants: true,
        role: SemanticsRole.menuItem,
        label: widget.item.semanticLabel ?? widget.item.label,
        enabled: !widget.disabled,
        expanded: widget.selected,
        onTap: widget.disabled ? null : () => widget.onPressed(false),
      ),
      child: _MenuBarLabel(
        label: widget.item.label,
        accessKey: widget.item.accessKey,
        showAccessKey: widget.showAccessKey,
      ),
    );
  }
}

class _MenuBarLabel extends StatelessWidget {
  const _MenuBarLabel({required this.label, required this.accessKey, required this.showAccessKey});

  final String label;
  final String? accessKey;
  final bool showAccessKey;

  @override
  Widget build(BuildContext context) {
    final key = accessKey;
    if (!showAccessKey || key == null) return ElView(child: label);
    final index = label.toLowerCase().indexOf(key.toLowerCase());
    if (index < 0) return ElView(child: label);
    return ElView(
      child: [
        if (index > 0) label.substring(0, index),
        ElView(
          style: const ElStyle(decoration: TextDecoration.underline),
          child: label.substring(index, index + key.length),
        ),
        if (index + key.length < label.length) label.substring(index + key.length),
      ],
    );
  }
}

class _MenuBarShortcutDispatcher {
  _MenuBarShortcutDispatcher._();

  static final _MenuBarShortcutDispatcher instance = _MenuBarShortcutDispatcher._();

  final List<_MenuBarState> _owners = <_MenuBarState>[];
  _MenuBarState? _altOwner;
  bool _altAlone = false;
  bool _installed = false;
  int _serial = 0;

  void register(_MenuBarState owner) {
    if (_owners.contains(owner)) return;
    _owners.add(owner);
    if (_installed) return;
    _installed = true;
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  void unregister(_MenuBarState owner) {
    _owners.remove(owner);
    if (identical(_altOwner, owner)) {
      _altOwner = null;
      _altAlone = false;
    }
    if (_owners.isNotEmpty || !_installed) return;
    _installed = false;
    HardwareKeyboard.instance.removeHandler(_handleKey);
  }

  int touch(_MenuBarState owner) {
    if (!_owners.contains(owner)) return owner._interactionSerial;
    return ++_serial;
  }

  bool _handleKey(KeyEvent event) {
    final key = event.logicalKey;
    if (_isAltKey(key)) return _handleAlt(event);
    if (event is KeyUpEvent && key == LogicalKeyboardKey.escape) {
      for (final owner in _owners) {
        owner._popupEscapeInFlight = false;
      }
    }
    if (event is! KeyDownEvent) return false;

    final popupOwner = _resolveOwner(requireOpenMenu: true);
    if (popupOwner != null && (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.tab)) {
      popupOwner._notePopupKey(event);
    }

    if (key == LogicalKeyboardKey.escape && popupOwner == null) {
      final owner = _resolveOwner();
      if (owner != null && owner._menuMode && !owner._ownsOpenMenu) {
        owner._leaveMenuMode(restoreFocus: true);
        return true;
      }
    }

    final keyboard = HardwareKeyboard.instance;
    if (key == LogicalKeyboardKey.f10 &&
        !keyboard.isShiftPressed &&
        !keyboard.isControlPressed &&
        !keyboard.isAltPressed &&
        !keyboard.isMetaPressed) {
      final owner = _resolveOwner();
      owner?._toggleKeyboardMode();
      return owner != null;
    }

    final altOwner = _altOwner;
    if (altOwner == null) return false;
    _altAlone = false;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) {
      final label = event.character ?? key.keyLabel;
      if (label.length == 1 && altOwner._activateAccessKey(label)) {
        return true;
      }
    }
    altOwner._setAccessKeysVisible(altOwner._menuMode);
    return false;
  }

  bool _handleAlt(KeyEvent event) {
    if (event is KeyDownEvent) {
      final keyboard = HardwareKeyboard.instance;
      if (keyboard.isControlPressed || keyboard.isMetaPressed) return false;
      final owner = _resolveOwner();
      if (owner == null) return false;
      _altOwner = owner;
      _altAlone = true;
      owner._setAccessKeysVisible(true);
      return false;
    }
    if (event is! KeyUpEvent) return false;
    final owner = _altOwner;
    final activate = _altAlone;
    _altOwner = null;
    _altAlone = false;
    if (owner == null || !owner.mounted) return false;
    if (activate) {
      owner._toggleKeyboardMode();
      return true;
    }
    owner._setAccessKeysVisible(owner._menuMode);
    return false;
  }

  _MenuBarState? _resolveOwner({bool requireOpenMenu = false}) {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final focusedViewId = focusContext == null ? null : View.maybeOf(focusContext)?.viewId;
    final priorities = <_MenuBarState, int>{};
    final candidates = _owners.where((owner) {
      // 已打开菜单的 Esc / Tab 与是否注册全局快捷键无关。
      if (requireOpenMenu) {
        if (!owner.mounted || !owner._ownsOpenMenu || !owner._menuEntry!.hasFocus) return false;
      } else if (!owner._canOwnGlobalShortcuts) {
        return false;
      }
      if (focusedViewId != null && owner._viewId != focusedViewId) return false;
      final rule = owner.widget.shortcutPriority;
      final priority = rule == null ? 0 : rule(focusContext, owner._ownsOpenMenu);
      if (priority == null) return false;
      priorities[owner] = priority;
      return true;
    }).toList();
    if (candidates.isEmpty) return null;
    if (focusContext == null && candidates.map((owner) => owner._viewId).toSet().length > 1) {
      return null;
    }
    candidates.sort((a, b) {
      final priority = priorities[a]!.compareTo(priorities[b]!);
      return priority != 0 ? priority : a._interactionSerial.compareTo(b._interactionSerial);
    });
    return candidates.last;
  }
}

bool _menuBarPopupModelsEqual(List<ElMenuBarItem> previous, List<ElMenuBarItem> current) {
  if (previous.length != current.length) return false;
  for (var index = 0; index < previous.length; index++) {
    if (!_contextMenuItemsVisualEqual(previous[index].items, current[index].items)) {
      return false;
    }
  }
  return true;
}

bool _contextMenuItemsVisualEqual(List<ElContextMenuItem> previous, List<ElContextMenuItem> current) {
  if (previous.length != current.length) return false;
  for (var index = 0; index < previous.length; index++) {
    final a = previous[index];
    final b = current[index];
    if (a.isDivider != b.isDivider ||
        a.label != b.label ||
        a.icon != b.icon ||
        a.enabled != b.enabled ||
        a.checked != b.checked ||
        a.shortcut != b.shortcut) {
      return false;
    }
    if (!_contextMenuItemsVisualEqual(
      a.children ?? const <ElContextMenuItem>[],
      b.children ?? const <ElContextMenuItem>[],
    )) {
      return false;
    }
  }
  return true;
}

bool _isAltKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.alt || key == LogicalKeyboardKey.altLeft || key == LogicalKeyboardKey.altRight;

ElStyle? _resolveMenuBarStyle(BuildContext context, ElStyle? style) => style;
