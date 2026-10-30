part of 'view_element.dart';

/// 会发起「键盘导航」的按键：遍历键 + F10（菜单栏键盘模式）。
///
/// 只认这些键，才符合 CSS `:focus-visible`：Tab / Shift+Tab / 方向键 / Home /
/// End / PageUp / PageDown / F10 换焦点亮焦点环；Enter、Escape、空格和普通
/// 字母键只做激活/取消/输入，不自行开启焦点指示。
/// [LogicalKeyboardKey] 没有原始相等语义（`==` 按 keyId），因此不能用 const 集合。
final Set<LogicalKeyboardKey> _kNavigationKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.tab,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.home,
  LogicalKeyboardKey.end,
  LogicalKeyboardKey.pageUp,
  LogicalKeyboardKey.pageDown,
  LogicalKeyboardKey.f10,
};

/// 当前是否处于「导航键仍按下」的换焦过程中（= 本次焦点变化来自键盘导航）。
///
/// 这是焦点指示的输入模态来源，替代「看全局 [FocusManager.highlightMode]」的
/// 旧口径：Flutter 的 `_HighlightModeManager.handlePointerEvent` 只把
/// touch/stylus/invertedStylus 判为触摸形态，mouse/trackpad 什么都不做；而
/// windows/linux/macos 的初始形态就是 `traditional`。桌面鼠标按下因此永远保持
/// traditional，绝不等于「键盘交互」。
///
/// 只读 [HardwareKeyboard] 的按下集合，不安装全局 handler，因此没有注册/注销
/// 生命周期问题，也不会在 build 里留下监听泄漏。按键派发期间的 `requestFocus`
/// 在 key up 之前落地（FocusManager 用 microtask 合并更新），所以该判定在
/// 键盘换焦的同一帧内成立。
///
/// Alt / Meta 组合不算导航：Alt+方向键、Cmd+方向键是历史/空间导航或组合键，
/// 不应把焦点环点亮。
bool get _keyboardNavigationInFlight {
  final keyboard = HardwareKeyboard.instance;
  if (keyboard.isAltPressed || keyboard.isMetaPressed) return false;
  for (final key in keyboard.logicalKeysPressed) {
    if (_kNavigationKeys.contains(key)) return true;
  }
  return false;
}

/// 本次**新获得**的焦点是否应点亮焦点指示（CSS `:focus-visible` 口径）。
///
/// - [ElFocusReason.keyboard]：组件显式声明本次换焦来自键盘导航；
/// - [ElFocusReason.programmatic]：仅当导航键仍在按下（F10 打开菜单、组件在
///   方向键回调里 requestFocus）；autofocus、窗口恢复、普通文字输入不点亮；
/// - [ElFocusReason.pointer] / [ElFocusReason.lifecycle]：不点亮。
///
/// 该判定只决定 `focusVisible` 这一位；[ElFocusReason] 本身照旧同步给渲染层，
/// 焦点事件与 onFocus / onFocusWithin 语义与本判定无关。
bool _focusVisibleForReason(ElFocusReason reason) => switch (reason) {
  ElFocusReason.keyboard => true,
  ElFocusReason.programmatic => _keyboardNavigationInFlight,
  ElFocusReason.pointer => false,
  ElFocusReason.lifecycle => false,
};

/// 取不到 [View.viewId] 时的兜底桶：登记在这里的视图，任何 View 的指针按下都收环。
///
/// 单个 [FlutterView] 的 viewId 恒为 0，与浏览器「一个 document 一个
/// `:focus-visible`」同构；多 View（多窗口/多 embedding）各自收自己的环。
const int _globalFocusRingViewId = -1;

/// 正在显示焦点环的视图，按 [View.viewId] 分桶。
///
/// 指针按下（同一 View 内任意位置）都要让它们立刻收环：焦点环属于「上一次键盘
/// 导航」的产物，指针一落地就过期。用「无 View（单个 View 时就是全局）」一条
/// 全局路由 + 按 viewId 分桶，而不是每个 ElView 各挂一个 handler，避免监听泄漏
/// 和 O(n) 重复分发。
final Map<int, Set<VoidCallback>> _ringOwners = <int, Set<VoidCallback>>{};
int _ringOwnerCount = 0;

/// 视图点亮焦点环时登记；同一回调重复登记无副作用（幂等）。
void _registerFocusRingOwner(VoidCallback retract, {required int viewId}) {
  final owners = _ringOwners.putIfAbsent(viewId, () => <VoidCallback>{});
  if (!owners.add(retract)) return;
  if (_ringOwnerCount++ == 0) {
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handleGlobalPointer);
  }
}

/// 视图收环/卸载时注销；最后一个持有者离开即移除全局路由。
void _unregisterFocusRingOwner(VoidCallback retract, {required int viewId}) {
  final owners = _ringOwners[viewId];
  if (owners == null || !owners.remove(retract)) return;
  if (owners.isEmpty) _ringOwners.remove(viewId);
  if (--_ringOwnerCount <= 0) {
    _ringOwnerCount = 0;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handleGlobalPointer);
  }
}

// 多 FlutterView 各自收自己的环；单 View 场景下 viewId 恒为 0，等价于全局。
void _handleGlobalPointer(PointerEvent event) {
  if (event is! PointerDownEvent) return;
  _retractRingOwners(event.viewId);
  if (event.viewId != _globalFocusRingViewId) _retractRingOwners(_globalFocusRingViewId);
}

void _retractRingOwners(int viewId) {
  final owners = _ringOwners[viewId];
  if (owners == null) return;
  // 拷贝一份：收环过程中回调会自己注销，直接遍历会并发修改。
  for (final retract in owners.toList(growable: false)) {
    retract();
  }
}
