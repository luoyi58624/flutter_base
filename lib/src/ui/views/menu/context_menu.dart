import 'dart:async' show Completer, Timer, scheduleMicrotask;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/flutter/components/icon/content.dart';

import 'package:flutter_base/src/flutter/views/view/event/event.dart';
import 'package:flutter_base/src/flutter/utils/internal/focus.dart';
import 'package:flutter_base/src/flutter/views/selection/common/selection_chrome_host.dart'
    show SelectionChromeMountHost, SelectionChromeSlot;
import 'package:flutter_base/src/flutter/views/view/view.dart';
import 'package:flutter_base/src/flutter/views/view/semantics/semantics.dart';
import 'package:flutter_base/src/flutter/views/view/style/style.dart';

part 'menu_overlay.dart';

/// 白盒测试识别主菜单面板的稳定 key（[ElContextMenu.open] 包在面板外；
/// 子菜单面板见 [contextMenuSubmenuPanelKey]）。
@visibleForTesting
Key get contextMenuPanelKey => const ValueKey<String>('el-context-menu-panel');

/// 白盒测试识别第 [level] 级子菜单面板的稳定 key（level 从 1 起；主面板见
/// [contextMenuPanelKey]）。
@visibleForTesting
Key contextMenuSubmenuPanelKey(int level) => ValueKey<String>('el-context-menu-panel-$level');

/// 白盒测试识别第 [index] 个菜单条目的稳定 key（index 为该面板 items 列表序，
/// [level] 为子菜单层级，0 = 主面板）。
@visibleForTesting
Key contextMenuItemKey(int index, {int level = 0}) => ValueKey<String>('el-context-menu-item-$level-$index');

/// 白盒测试识别第 [index] 个菜单条目行为面的稳定 key（index / level 口径同
/// [contextMenuItemKey]）。
@visibleForTesting
Key contextMenuItemSurfaceKey(int index, {int level = 0}) =>
    ValueKey<String>('el-context-menu-item-surface-$level-$index');

/// 白盒测试识别第 [index] 个分隔线的稳定 key（index / level 口径同
/// [contextMenuItemKey]）。
@visibleForTesting
Key contextMenuDividerKey(int index, {int level = 0}) => ValueKey<String>('el-context-menu-divider-$level-$index');

/// 上下文菜单条目数据。
///
/// 命名有意避让 `ElMenuItem`（留给 element_plus 未来对齐 Element Plus 的导航组件）。
/// 分隔线用 [ElContextMenuItem.divider]。
class ElContextMenuItem {
  /// 创建普通条目。
  const ElContextMenuItem({
    required this.label,
    this.onSelect,
    this.icon,
    this.enabled = true,
    this.checked,
    this.shortcut,
    this.children,
  }) : isDivider = false;

  /// 创建分隔线条目（其余字段无效）。
  const ElContextMenuItem.divider()
    : label = '',
      onSelect = null,
      icon = null,
      enabled = true,
      checked = null,
      shortcut = null,
      children = null,
      isDivider = true;

  /// 条目文本。
  final String label;

  /// 选中回调（菜单先整链关闭再触发）。含 [children] 的条目点击只展开子菜单，
  /// 不触发本回调。
  final VoidCallback? onSelect;

  /// 图标槽：`IconData` / `Widget` / null，宽容输入运行时分派（见
  /// [ElContextMenu.buildIcon]）。
  final dynamic icon;

  /// 是否可用。false 时灰显且不可点（禁用语义走独立布尔，不用 [onSelect]
  /// 为 null 隐式表达）。
  final bool enabled;

  /// 二态菜单项的受控勾选状态；非 null 时使用 checkbox 菜单项语义。
  final bool? checked;

  /// 快捷键文本：行尾右对齐次要色显示，**纯展示**不绑定按键派发；
  /// 与子菜单箭头互斥占位（[children] 优先）。
  final String? shortcut;

  /// 二级子菜单条目：非空时行尾显示 › 箭头，hover 短延迟（
  /// [ElContextMenu.submenuOpenDelay]）在该行右侧展开子面板；点击子项执行
  /// onSelect 并整链关闭。
  final List<ElContextMenuItem>? children;

  /// 是否为分隔线。
  final bool isDivider;

  /// 是否带子菜单（[children] 非空）。
  bool get hasChildren => children != null && children!.isNotEmpty;
}

/// 上下文菜单打开后首先聚焦的边界项。
enum ContextMenuInitialFocus {
  /// 聚焦首个普通菜单项。
  first,

  /// 聚焦最后一个普通菜单项。
  last,
}

/// 无外观的上下文菜单行为基座。
///
/// [open] 通过 Flutter Overlay 挂载、定位并管理菜单生命周期；
/// Escape、外部点击穿透与短退场淡出由菜单自己处理。面板 / 条目 /
/// 分隔线的外观是 open 钩子（[buildPanel] / [buildItemStyle] /
/// [buildItemContent] / [buildDivider]），子类只换形制。焦点节点、指针激活、
/// 菜单语义、上下/Home/End 循环、左右进退子菜单、Enter/Space 激活、Tab /
/// ESC 关闭、字符前缀定位与关闭后的焦点归还全部由基座接线。快捷键文本与
/// 二级子菜单同样是基座级能力：行尾槽由 [buildTrailing] 渲染，hover 展开 /
/// 兄弟收起 / 整链关闭由基座管理。本包不带形制：
/// Windows / Mac / 品牌形实现在 element_plus，经 `el.globalContextMenus` 注册；
/// 业务侧一般走 `el.showContextMenu` 门面（挂在 `el` 全局单例上）。
abstract class ElContextMenu {
  /// 创建菜单实现。
  const ElContextMenu();

  /// 退场保活时长（关闭后淡出的窗口）。
  Duration get exitDuration => const Duration(milliseconds: 90);

  /// 子菜单 hover 展开延迟：悬停含 children 的行这么久后在行右侧展开子面板
  /// （点击该行则立即展开）。
  Duration get submenuOpenDelay => const Duration(milliseconds: 150);

  /// 在 [position]（全局坐标）弹出菜单。
  ///
  /// [context] 是级联捕获点：菜单内延续此处的 vars / 明暗 / 断点环境。
  /// [rootOverlay] 决定主菜单与后续子菜单共用的弹层选择器。
  /// 返回主面板菜单句柄；子菜单随主面板关闭，缺少 Flutter Overlay 时不弹。
  ElContextMenuHandle? open(
    BuildContext context, {
    required Offset position,
    required List<ElContextMenuItem> items,
    bool rootOverlay = false,
  }) => openWithOptions(context, position: position, items: items, rootOverlay: rootOverlay);

  /// 使用菜单栏等复合组件需要的附加焦点选项弹出菜单。
  ///
  /// [initialFocus] 决定主面板首次获得键盘焦点的位置。
  /// [restoreFocus] 为 true 时整链关闭后尝试归还打开前焦点；菜单栏等拥有
  /// 自己焦点模式的复合组件可关闭此行为并自行接管。
  /// [onNavigatePrevious] 在主面板后退时触发，[onNavigateNext] 在任意层级
  /// 无法进入子菜单时触发，供水平菜单栏切换相邻顶级菜单。
  /// 默认选项与 [open] 等价；单独保留本入口可避免给既有 [open] 覆写者
  /// 增加新的命名参数要求。
  ElContextMenuHandle? openWithOptions(
    BuildContext context, {
    required Offset position,
    required List<ElContextMenuItem> items,
    bool rootOverlay = false,
    ContextMenuInitialFocus initialFocus = ContextMenuInitialFocus.first,
    bool restoreFocus = true,
    VoidCallback? onNavigatePrevious,
    VoidCallback? onNavigateNext,
  }) {
    return _showLayer(
      context,
      position: position,
      items: items,
      chain: _MenuChain(
        rootOverlay,
        restoreFocus,
        onNavigatePrevious: onNavigatePrevious,
        onNavigateNext: onNavigateNext,
      ),
      level: 0,
      focusBoundary: initialFocus == ContextMenuInitialFocus.first ? _MenuFocusBoundary.first : _MenuFocusBoundary.last,
    );
  }

  /// 单级菜单面板弹层（open 骨架本体；level 0 = 主面板，≥1 = 子菜单，
  /// [opener] 为展开子面板的行 State，供 hover 意图判「本行子面板已开」）。
  ElContextMenuHandle? _showLayer(
    BuildContext context, {
    required Offset position,
    required List<ElContextMenuItem> items,
    required _MenuChain chain,
    required int level,
    _MenuItemHostState? opener,
    _MenuFocusBoundary? focusBoundary,
  }) {
    final host = Overlay.maybeOf(context, rootOverlay: chain.rootOverlay);
    if (host == null) {
      assert(() {
        debugPrint('el_ui: el.showContextMenu 找不到 Flutter Overlay，本次不弹菜单。');
        return true;
      }());
      return null;
    }
    final entry = ElContextMenuHandle._(
      source: context,
      overlay: host,
      chain: chain,
      level: level,
      position: position,
      anchor: opener?.context,
      restoreFocus: level > 0 || chain.restoreFocus,
      exitDuration: exitDuration,
      builder: (context, exiting) {
        final children = <Widget>[
          for (var i = 0; i < items.length; i++)
            items[i].isDivider
                ? KeyedSubtree(
                    key: contextMenuDividerKey(i, level: level),
                    child: ElView(semantics: ElSemantics(exclude: true), child: buildDivider(context)),
                  )
                : _MenuItemHost(
                    key: contextMenuItemKey(i, level: level),
                    menu: this,
                    item: items[i],
                    chain: chain,
                    level: level,
                    index: i,
                  ),
        ];
        return ElView(
          semantics: exiting ? ElSemantics(exclude: true) : null,
          style: ElStyle(
            opacity: exiting ? 0.0 : null,
            pointerEvents: exiting ? .none : null,
            starting: const ElStyle(opacity: 0.0),
            transition: const [.field(.opacity, Duration(milliseconds: 90), Curves.easeOutCubic)],
          ),
          child: KeyedSubtree(
            key: level == 0 ? contextMenuPanelKey : contextMenuSubmenuPanelKey(level),
            child: ElView(
              semantics: ElSemantics(
                container: true,
                explicitChildNodes: true,
                // 空面板仍捕获焦点；menu 角色要求至少一个真实菜单项。
                role: items.any((item) => !item.isDivider) ? SemanticsRole.menu : null,
              ),
              child: buildPanel(context, children),
            ),
          ),
        );
      },
    );
    chain.register(level, entry, opener: opener, focusBoundary: focusBoundary);
    entry._mount();
    return entry;
  }

  /// 构建面板外壳（背景 / 圆角 / 边框 / 阴影 / 内边距），[children] 是已按
  /// items 序构建好的条目与分隔线。子菜单面板复用同一钩子（同菜单样式）。
  Widget buildPanel(BuildContext context, List<Widget> children);

  /// 构建条目行为面的外观样式。
  ///
  /// 基座会把样式挂到自带焦点、事件与语义的 [ElView] 上，因此子类只声明
  /// hover / focus / tap / disabled 等外观；[item.enabled] 为 false 时由子类直接
  /// 返回灰显后的样式，基座仍保留其焦点可达性但禁止激活。
  ElStyle? buildItemStyle(BuildContext context, ElContextMenuItem item) => null;

  /// 构建条目内部的纯展示内容。
  ///
  /// 不得在返回树中重复挂按钮、焦点或点击行为；行尾的 shortcut / 子菜单箭头
  /// 用 [buildTrailing] 取槽后放进右对齐位。
  Widget buildItemContent(BuildContext context, ElContextMenuItem item) => ElView(child: item.label);

  /// 构建分隔线。
  Widget buildDivider(BuildContext context);

  /// 字体图标统一继承 iconSize / iconColor，自定义 Widget 原样托管。
  Widget? buildIcon(BuildContext context, dynamic icon, {double size = 16.0}) {
    if (icon is IconData) {
      return ElView(
        style: ElStyle(iconSize: size),
        child: icon,
      );
    }
    if (icon is Widget) return buildIconContent(icon, size: size);
    return null;
  }

  /// 行尾槽分派：[ElContextMenuItem.children] 非空渲染 › 子菜单箭头（优先），
  /// 否则渲染 [ElContextMenuItem.shortcut] 快捷键文本；两者皆无返回 null。
  ///
  /// 箭头继承图标色，快捷键继承文字色；返回值放进各自行尾右对齐槽。
  Widget? buildTrailing(BuildContext context, ElContextMenuItem item, {double size = 12.0}) {
    if (item.hasChildren) {
      return ElView(
        style: ElStyle(iconSize: size + 3, opacity: 0.75),
        child: const IconData(0x203a, matchTextDirection: true),
      );
    }
    final shortcut = item.shortcut;
    if (shortcut == null || shortcut.isEmpty) return null;
    return ElView(
      style: ElStyle(fontSize: size, opacity: 0.6),
      child: shortcut,
    );
  }
}

/// 一次菜单会话的弹层链：`_entries[0]` 主面板，之后每级一个子面板。
///
/// 注册时级联截断（开新子面板先收起同级旧面板）；entry 经任何来路关闭
/// （ESC LIFO / 外点击 / 手动 close）后同步收起剩余深层，链上不残留
/// 孤儿子面板。
enum _MenuFocusBoundary { first, last }

class _MenuChain {
  _MenuChain(this.rootOverlay, this.restoreFocus, {this.onNavigatePrevious, this.onNavigateNext});

  /// 主菜单与所有子菜单共用的弹层选择器。
  final bool rootOverlay;
  final bool restoreFocus;

  /// 主面板请求切换到前一个同级顶层菜单时调用。
  final VoidCallback? onNavigatePrevious;

  /// 主面板请求切换到后一个同级顶层菜单时调用。
  final VoidCallback? onNavigateNext;
  final List<ElContextMenuHandle> _entries = <ElContextMenuHandle>[];
  final List<_MenuItemHostState?> _openers = <_MenuItemHostState?>[];
  final Map<int, List<_MenuItemHostState>> _items = <int, List<_MenuItemHostState>>{};
  final Map<int, String> _typeahead = <int, String>{};
  final Map<int, Timer> _typeaheadTimers = <int, Timer>{};

  /// [level] 级面板的开启者；无该级 / 已关闭返回 null。
  _MenuItemHostState? openerAt(int level) {
    if (level >= _entries.length) return null;
    return _entries[level].isOpen ? _openers[level] : null;
  }

  /// 注册 [level] 级面板（先收起原 ≥ level 的旧面板）；entry 关闭后级联收
  /// 更深层并把焦点交回父条目或菜单打开前的目标。
  void register(int level, ElContextMenuHandle entry, {_MenuItemHostState? opener, _MenuFocusBoundary? focusBoundary}) {
    closeFrom(level);
    _entries.add(entry);
    _openers.add(opener);
    opener?._setExpanded(true);
    if (focusBoundary != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!entry.isOpen) return;
        entry._captureFocus();
        focusEdge(level, focusBoundary, reason: ElFocusReason.lifecycle);
      });
    }
    void release() {
      if (entry.isShowing) return;
      final index = _entries.indexOf(entry);
      if (index < 0) return;
      closeFrom(index);
    }

    entry.addListener(release);
    // 宿主直接销毁不经过逻辑关闭通知，也必须释放字符定位计时器。
    entry.closed.then((_) => release());
  }

  void registerItem(_MenuItemHostState item) {
    final items = _items.putIfAbsent(item.widget.level, () => <_MenuItemHostState>[]);
    items.add(item);
    items.sort((a, b) => a.widget.index.compareTo(b.widget.index));
  }

  void unregisterItem(_MenuItemHostState item) {
    final items = _items[item.widget.level];
    items?.remove(item);
    if (items?.isEmpty ?? false) _items.remove(item.widget.level);
  }

  void noteFocus(_MenuItemHostState item) {
    if (!identical(openerAt(item.widget.level + 1), item)) closeFrom(item.widget.level + 1);
  }

  void focusItem(_MenuItemHostState item, ElFocusReason reason) {
    if (!item.mounted || item._focusNode.context == null || !item._focusNode.canRequestFocus) return;
    noteFocus(item);
    FocusUtil.markReason(item._focusNode, reason);
    item._focusNode.requestFocus();
  }

  void focusEdge(int level, _MenuFocusBoundary boundary, {ElFocusReason reason = ElFocusReason.keyboard}) {
    final items = _items[level];
    if (items == null || items.isEmpty) return;
    focusItem(boundary == _MenuFocusBoundary.first ? items.first : items.last, reason);
  }

  void move(_MenuItemHostState current, int delta) {
    final items = _items[current.widget.level];
    if (items == null || items.isEmpty) return;
    final currentIndex = items.indexOf(current);
    final nextIndex = currentIndex < 0 ? 0 : (currentIndex + delta) % items.length;
    focusItem(items[nextIndex], ElFocusReason.keyboard);
  }

  bool navigatePrevious() {
    final callback = onNavigatePrevious;
    if (callback == null) return false;
    callback();
    return true;
  }

  bool navigateNext() {
    final callback = onNavigateNext;
    if (callback == null) return false;
    callback();
    return true;
  }

  bool focusByCharacter(_MenuItemHostState current, String character) {
    final items = _items[current.widget.level];
    if (items == null || items.isEmpty) return false;
    final level = current.widget.level;
    _typeaheadTimers.remove(level)?.cancel();
    var query = '${_typeahead[level] ?? ''}${character.toLowerCase()}';
    var target = _findByPrefix(items, current, query);
    if (target == null && query.length > character.length) {
      query = character.toLowerCase();
      target = _findByPrefix(items, current, query);
    }
    _typeahead[level] = query;
    _typeaheadTimers[level] = Timer(const Duration(milliseconds: 700), () {
      _typeahead.remove(level);
      _typeaheadTimers.remove(level);
    });
    if (target == null) return false;
    focusItem(target, ElFocusReason.keyboard);
    return true;
  }

  _MenuItemHostState? _findByPrefix(List<_MenuItemHostState> items, _MenuItemHostState current, String query) {
    final start = items.indexOf(current);
    for (var step = 1; step <= items.length; step++) {
      final item = items[(start + step) % items.length];
      if (item.widget.item.label.toLowerCase().startsWith(query)) return item;
    }
    return null;
  }

  /// 关闭并摘除 ≥ [level] 的全部面板（深层先关）。
  void closeFrom(int level) {
    while (_entries.length > level) {
      final opener = _openers.removeLast();
      opener?._setExpanded(false);
      _entries.removeLast().close();
    }
    for (final key in _typeahead.keys.where((key) => key >= level).toList()) {
      _typeahead.remove(key);
      _typeaheadTimers.remove(key)?.cancel();
    }
  }

  void closeCurrentAndFocusParent(int level) {
    if (level <= 0 || level >= _entries.length) return;
    final opener = _openers[level];
    closeFrom(level);
    opener?._requestFocus(ElFocusReason.keyboard);
  }

  /// 整链关闭，菜单句柄在逻辑关闭时归还焦点。
  void closeAll() {
    closeFrom(0);
  }
}

/// 菜单条目行的基座级行为壳：hover 意图（展开子菜单 / 收起兄弟子菜单）+
/// activate 语义分派（叶子整链关、父行开子面板）。
///
/// 外壳是 `minWidth: '100%'` 的 ElView：把面板列的可用宽度传导给 buildItem
/// 产物（ElView 恒宽松约束，不抬 min 则窄行 hover 高亮铺不满行宽）。
class _MenuItemHost extends StatefulWidget {
  const _MenuItemHost({
    super.key,
    required this.menu,
    required this.item,
    required this.chain,
    required this.level,
    required this.index,
  });

  /// 所属菜单实现（外观钩子来源）。
  final ElContextMenu menu;

  /// 条目数据。
  final ElContextMenuItem item;

  /// 会话弹层链。
  final _MenuChain chain;

  /// 本行所在面板层级（0 = 主面板）。
  final int level;

  /// 本行在原 items 列表中的序号。
  final int index;

  @override
  State<_MenuItemHost> createState() => _MenuItemHostState();
}

class _MenuItemHostState extends State<_MenuItemHost> {
  Timer? _hoverTimer;
  late final FocusNode _focusNode;
  bool _expanded = false;

  /// 子面板层级 = 本行层级 + 1。
  int get _submenuLevel => widget.level + 1;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      debugLabel: 'ElContextMenuItem(${widget.level}:${widget.index} ${widget.item.label})',
      skipTraversal: true,
    )..addListener(_handleFocusChange);
    widget.chain.registerItem(this);
  }

  @override
  void didUpdateWidget(covariant _MenuItemHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.chain, widget.chain) || oldWidget.level != widget.level) {
      oldWidget.chain.unregisterItem(this);
      widget.chain.registerItem(this);
    }
    _focusNode.debugLabel = 'ElContextMenuItem(${widget.level}:${widget.index} ${widget.item.label})';
  }

  void _handleFocusChange() {
    if (_focusNode.hasPrimaryFocus) widget.chain.noteFocus(this);
  }

  void _setExpanded(bool value) {
    if (!mounted || _expanded == value) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      _expanded = value;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() => _expanded = value);
    }
  }

  void _requestFocus(ElFocusReason reason) => widget.chain.focusItem(this, reason);

  void _handleEnter() {
    final chain = widget.chain;
    // 本行已开的子面板保持（从子面板移回父行不闪断）。
    if (identical(chain.openerAt(_submenuLevel), this)) return;
    // 移到其他行：收起兄弟行开的子面板（及更深层）。
    chain.closeFrom(_submenuLevel);
    _requestFocus(ElFocusReason.pointer);
    if (!widget.item.hasChildren || !widget.item.enabled) return;
    _hoverTimer?.cancel();
    _hoverTimer = Timer(widget.menu.submenuOpenDelay, () => _openSubmenu());
  }

  void _handleExit() {
    _hoverTimer?.cancel();
    _hoverTimer = null;
  }

  /// 在行右侧展开子面板：rightStart 贴行（行全局矩形右上角），越界翻转后置。
  void _openSubmenu({_MenuFocusBoundary? focusBoundary}) {
    _hoverTimer = null;
    if (!mounted || !widget.item.enabled || !widget.item.hasChildren) return;
    if (identical(widget.chain.openerAt(_submenuLevel), this)) {
      if (focusBoundary != null) widget.chain.focusEdge(_submenuLevel, focusBoundary);
      return;
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final topRight = box.localToGlobal(Offset(box.size.width, 0));
    widget.menu._showLayer(
      context,
      position: topRight,
      items: widget.item.children!,
      chain: widget.chain,
      level: _submenuLevel,
      opener: this,
      focusBoundary: focusBoundary,
    );
  }

  /// activate 语义分派：父行立即展开子菜单；叶子整链关闭后触发 onSelect。
  void _activate() {
    if (!widget.item.enabled) return;
    if (widget.item.hasChildren) {
      _hoverTimer?.cancel();
      _hoverTimer = null;
      _openSubmenu(focusBoundary: _MenuFocusBoundary.first);
      return;
    }
    widget.chain.closeAll();
    widget.item.onSelect?.call();
  }

  void _handleKeyDown(ElEventDetails event) {
    final key = event.logicalKey;
    var handled = true;
    if (key == LogicalKeyboardKey.arrowDown) {
      widget.chain.move(this, 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      widget.chain.move(this, -1);
    } else if (key == LogicalKeyboardKey.home) {
      widget.chain.focusEdge(widget.level, _MenuFocusBoundary.first);
    } else if (key == LogicalKeyboardKey.end) {
      widget.chain.focusEdge(widget.level, _MenuFocusBoundary.last);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      _activate();
    } else if (key == LogicalKeyboardKey.tab) {
      widget.chain.closeAll();
    } else {
      final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
      final openKey = direction == TextDirection.ltr ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft;
      final closeKey = direction == TextDirection.ltr ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight;
      if (key == openKey) {
        if (widget.item.enabled && widget.item.hasChildren) {
          _openSubmenu(focusBoundary: _MenuFocusBoundary.first);
        } else {
          handled = widget.chain.navigateNext();
        }
      } else if (key == closeKey && widget.level > 0) {
        widget.chain.closeCurrentAndFocusParent(widget.level);
      } else if (key == closeKey && widget.level == 0) {
        handled = widget.chain.navigatePrevious();
      } else if (key == LogicalKeyboardKey.escape) {
        // Escape 交给菜单层的 FocusScope，每个按键仅关闭当前最深面板。
        handled = false;
      } else {
        final character = event.character;
        final hasModifier =
            HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isAltPressed ||
            HardwareKeyboard.instance.isMetaPressed;
        handled =
            !hasModifier &&
            character != null &&
            character.trim().isNotEmpty &&
            character.runes.length == 1 &&
            widget.chain.focusByCharacter(this, character);
      }
    }
    if (!handled) return;
    event.preventDefault();
    event.stopPropagation();
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    widget.chain.unregisterItem(this);
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ElView(
      style: const ElStyle(minWidth: '100%', userSelect: .none),
      event: ElEvent(onPointerEnter: (_) => _handleEnter(), onPointerExit: (_) => _handleExit()),
      child: ElView(
        key: contextMenuItemSurfaceKey(widget.index, level: widget.level),
        style: widget.menu.buildItemStyle(context, widget.item),
        event: ElEvent(onTap: widget.item.enabled ? (_) => _activate() : null, onKeyDown: _handleKeyDown),
        focusNode: _focusNode,
        semantics: ElSemantics(
          container: true,
          mergeDescendants: true,
          role: widget.item.checked == null ? SemanticsRole.menuItem : SemanticsRole.menuItemCheckbox,
          label: widget.item.label,
          enabled: widget.item.enabled,
          checked: widget.item.checked,
          expanded: widget.item.hasChildren ? _expanded : null,
          onTap: widget.item.enabled ? _activate : null,
        ),
        child: ElView(semantics: ElSemantics(exclude: true), child: widget.menu.buildItemContent(context, widget.item)),
      ),
    );
  }
}
