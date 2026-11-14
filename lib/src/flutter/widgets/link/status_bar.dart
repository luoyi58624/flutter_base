import 'dart:async' show Timer;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../views/view/render/render_view.dart' show ElRenderView;
import '../../views/view/style/style.dart' show ElBorderSide, ElStyle, ElThemeMode, ElTransitionField;
import '../../views/view/view.dart' show ElView;
import 'index.dart' show ElLink;

/// 白盒测试识别链接状态栏面板的稳定 key。
@visibleForTesting
Key get linkStatusBarPanelKey => const ValueKey<String>('el-link-status-bar');

/// 浏览器式链接地址预览条：悬停链接时在视口左下角展示目标地址。
///
/// 视觉与时序**逐常量对齐 Chromium** `chrome/browser/ui/views/status_bubble_views.cc`
/// （StatusBubbleViews / StatusView）：
/// - 时序：悬停 [showDelay] 后以 [showFadeDuration] 线性淡入；离开 [hideDelay]
///   后以 [hideFadeDuration] 线性淡出（`kShowDelay/kHideDelay/kShowFadeDuration/
///   kHideFadeDuration`，纯 opacity LinearAnimation，无位移动画）；
/// - 换址：淡出倒计时内划入另一条链接 → 取消倒计时、**文本立即替换**，不重播
///   进出场（对齐 `SetURL` 在 shown 态直接换字）；
/// - 形状：仅右上角 4px 圆角（`kBubbleCornerRadius`，LTR 左下停靠位其余三角
///   方角）、外圈 1px 黑 12% 描边（`kColorStatusBubbleShadow = black @0x1E`）、
///   文本水平内边距 6（`kShadowThickness + kTextHorizPadding`）；
/// - 宽度：标准态上限视口 1/3（`GetStandardStatusBubbleWidth`），地址被截断时
///   悬停 [expandDelay] 后展开到全宽上限（`kExpandHoverDelayMS = 1600`）；
/// - 颜色：气泡底色 = frame 色、文字 = 非激活 tab 文字色（默认灰阶基线主题：
///   亮 #E3E3E3 / #474747，暗 #1F2020 / #C7C7C7，暗色走 `onDark`）。
///
/// 由链接组件（[ElLink]，非 web）悬停时自动调用 [hoverEnter] / [hoverExit]
/// 接入（web 端是原生 `<a>`，浏览器自带状态栏）；自定义链接组件也可直接调用
/// [hoverEnter] / [hoverExit]。树上无官方 [Overlay] 时静默不展示（debug 首次告警）。
class ElLinkStatusBar {
  ElLinkStatusBar._();

  /// 全局开关。false 时 [hoverEnter] / [hoverExit] 一律 no-op。
  static bool enabled = true;

  /// 悬停多久后开始淡入（Chromium `kShowDelay`；扫过即离不弹）。
  static Duration showDelay = const Duration(milliseconds: 80);

  /// 指针离开链接后多久开始淡出（Chromium `kHideDelay`）；期间再悬停任意
  /// 链接则取消淡出并换址。
  static Duration hideDelay = const Duration(milliseconds: 250);

  /// 淡入时长（Chromium `kShowFadeDuration`，线性）。
  static Duration showFadeDuration = const Duration(milliseconds: 120);

  /// 淡出时长（Chromium `kHideFadeDuration`，线性）。
  static Duration hideFadeDuration = const Duration(milliseconds: 200);

  /// 悬停多久后气泡从 1/3 视口宽展开到全宽上限（Chromium
  /// `StatusBubble::kExpandHoverDelayMS`，长地址被截断时可读全文）。
  static Duration expandDelay = const Duration(milliseconds: 1600);

  /// 展开动画时长（Chromium 展开步进 `kMaxExpansionStepDuration` 上限）。
  static Duration expandDuration = const Duration(milliseconds: 150);

  static Timer? _showTimer;
  static Timer? _hideTimer;
  static _StatusHandle? _entry;
  static final _HrefChannel _href = _HrefChannel();
  static BuildContext? _pendingContext;
  static Uri? _pendingHref;
  static bool _warnedNoHost = false;

  /// 是否处于展示中（open 态；退场动画播完前的关闭态不算）。
  @visibleForTesting
  static bool get isShown => _entry?.isOpen ?? false;

  /// 指针进入一条链接：已展示 → 立即换址；未展示 → 记录待展地址并起
  /// [showDelay] 定时（等待期内换链接只更新待展地址，不重置定时）。
  ///
  /// [context] 是级联捕获点（决定弹层的 host 与明暗环境），传链接自身的
  /// build context。
  static void hoverEnter(BuildContext context, Uri href) {
    if (!enabled) return;
    // host 前置检查：无挂载点连定时器都不起（hostless 宿主零开销，debug 首次告警）。
    if (Overlay.maybeOf(context, rootOverlay: true) == null) {
      assert(() {
        if (!_warnedNoHost) {
          _warnedNoHost = true;
          debugPrint('el_ui: ElLinkStatusBar 找不到官方 Overlay，链接地址预览不展示（请使用 Navigator 或 Overlay 宿主）。');
        }
        return true;
      }());
      return;
    }
    _hideTimer?.cancel();
    _hideTimer = null;
    final entry = _entry;
    if (entry != null && entry.isOpen) {
      _href.value = href;
      return;
    }
    _pendingHref = href;
    _pendingContext = context;
    _showTimer ??= Timer(showDelay, _open);
  }

  /// 指针离开一条链接：已展示且离开的正是当前地址 → 起 [hideDelay] 淡出
  /// 定时；尚未展示 → 取消待展。迟到的旧链接 exit（已换址到别的链接）忽略。
  static void hoverExit(Uri href) {
    if (!enabled) return;
    final entry = _entry;
    if (entry != null && entry.isOpen) {
      if (_href.value != href) return;
      _hideTimer?.cancel();
      _hideTimer = Timer(hideDelay, _close);
      return;
    }
    if (_pendingHref != href) return;
    _showTimer?.cancel();
    _showTimer = null;
    _pendingHref = null;
    _pendingContext = null;
  }

  static void _open() {
    _showTimer = null;
    final context = _pendingContext;
    final href = _pendingHref;
    _pendingContext = null;
    _pendingHref = null;
    if (context == null || href == null || !context.mounted) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _href.value = href;
    final handle = _StatusHandle();
    final themes = InheritedTheme.capture(from: context, to: overlay.context);
    final render = context.findRenderObject();
    final source = render is ElRenderView ? render : context.findAncestorRenderObjectOfType<ElRenderView>();
    handle.entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        bottom: 0,
        child: themes.wrap(_StatusPortal(handle: handle, source: source)),
      ),
    );
    _entry?.remove();
    _entry = handle;
    overlay.insert(handle.entry);
  }

  static void _close() {
    _hideTimer = null;
    _entry?.close();
  }

  /// 立即关闭并清空全部在途状态（定时器 / 待展地址 / 弹层）。测试收尾用，
  /// 业务代码无需调用。
  @visibleForTesting
  static void reset() {
    _showTimer?.cancel();
    _showTimer = null;
    _hideTimer?.cancel();
    _hideTimer = null;
    _pendingContext = null;
    _pendingHref = null;
    _entry?.remove();
    _entry = null;
    _href.value = null;
  }
}

/// 静态 hover API 的挂载句柄；展示和退场分开，退场条始终指针透明。
class _StatusHandle extends ChangeNotifier {
  late final OverlayEntry entry;
  bool isOpen = true;
  bool _removed = false;
  Timer? _exitTimer;

  void close() {
    if (!isOpen || _removed) return;
    isOpen = false;
    notifyListeners();
    _exitTimer = Timer(ElLinkStatusBar.hideFadeDuration, remove);
  }

  void remove() {
    if (_removed) return;
    _removed = true;
    _exitTimer?.cancel();
    entry.remove();
    entry.dispose();
    if (identical(ElLinkStatusBar._entry, this)) ElLinkStatusBar._entry = null;
  }

  void detached() {
    if (!_removed) {
      // Overlay 自己卸载时，句柄仍负责归还 entry 的资源。
      entry.remove();
      entry.dispose();
    }
    _removed = true;
    isOpen = false;
    _exitTimer?.cancel();
    if (identical(ElLinkStatusBar._entry, this)) ElLinkStatusBar._entry = null;
  }
}

class _StatusPortal extends StatefulWidget {
  const _StatusPortal({required this.handle, required this.source});
  final _StatusHandle handle;
  final ElRenderView? source;

  @override
  State<_StatusPortal> createState() => _StatusPortalState();
}

class _StatusPortalState extends State<_StatusPortal> {
  Listenable? _themeChanges;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    _themeChanges = widget.source?.ensureCascadeBridgeChanges();
    _themeChanges?.addListener(_themeChanged);
  }

  void _themeChanged() {
    if (!mounted || _pending) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      _pending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pending = false;
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _themeChanges?.removeListener(_themeChanged);
    widget.handle.detached();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.handle,
    // 浮层条目已贴在根 Overlay 左下角，状态条直接在这里展示，退场条始终指针透明。
    builder: (_, _) => IgnorePointer(
      child: _LinkStatusBarView(exiting: !widget.handle.isOpen, themeMode: widget.source?.effectiveThemeMode),
    ),
  );
}

/// 当前展示地址的推送通道：[ElLinkStatusBar] 写入，面板 State 监听读取。
/// 值相等不通知（幂等闸门，防换址稳态下的无谓重建）。
class _HrefChannel extends ChangeNotifier {
  Uri? _value;

  /// 当前地址；null 表示无展示内容。
  Uri? get value => _value;

  set value(Uri? next) {
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }
}

/// 状态栏面板：State 监听 [_HrefChannel] 原地换址（不经弹层重建，进场动画
/// 不重播）；退场由宿主通知淡出；悬停 [ElLinkStatusBar.expandDelay]
/// 后从 1/3 视口宽展开到全宽（换址重置展开态与定时，对齐 Chromium）。
class _LinkStatusBarView extends StatefulWidget {
  const _LinkStatusBarView({required this.exiting, this.themeMode});

  final bool exiting;
  final ElThemeMode? themeMode;

  @override
  State<_LinkStatusBarView> createState() => _LinkStatusBarViewState();
}

class _LinkStatusBarViewState extends State<_LinkStatusBarView> {
  Timer? _expandTimer;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    ElLinkStatusBar._href.addListener(_onHrefChanged);
    _armExpandTimer();
  }

  @override
  void dispose() {
    _expandTimer?.cancel();
    ElLinkStatusBar._href.removeListener(_onHrefChanged);
    super.dispose();
  }

  void _armExpandTimer() {
    _expandTimer?.cancel();
    _expandTimer = Timer(ElLinkStatusBar.expandDelay, () {
      _expandTimer = null;
      if (mounted) setState(() => _expanded = true);
    });
  }

  /// 换址：原地换字 + 回到未展开态并重新计时（Chromium `SetURL` 重置展开）。
  void _onHrefChanged() {
    if (!mounted) return;
    setState(() => _expanded = false);
    _armExpandTimer();
  }

  @override
  Widget build(BuildContext context) {
    final exiting = widget.exiting;
    return ElView(
      key: linkStatusBarPanelKey,
      themeMode: widget.themeMode,
      style: ElStyle(
        // 标准态上限视口 1/3（GetStandardStatusBubbleWidth = width / 3），
        // 悬停 expandDelay 后展开到全宽上限读长地址。
        maxWidth: _expanded ? '100%' : '33%',
        padding: .symmetric(horizontal: 6, vertical: 3),
        backgroundColor: const Color(0xffe3e3e3),
        color: const Color(0xff474747),
        fontSize: 12,
        maxLines: 1,
        textOverflow: .ellipsis,
        // Chromium 是包一圈的 1px 描边（kColorStatusBubbleShadow），停靠角
        // 的左/下边贴窗缘被裁掉——等效只画上、右两边；亮暗共用同一描边色。
        border: const .only(
          borderTop: ElBorderSide(borderColor: Color(0x1e000000)),
          borderRight: ElBorderSide(borderColor: Color(0x1e000000)),
        ),
        borderRadius: const .only(topRight: .circular(4)),
        pointerEvents: .none,
        opacity: exiting ? 0.0 : null,
        starting: const ElStyle(opacity: 0.0),
        // Chromium 是 LinearAnimation：纯 opacity 线性淡入/淡出，无位移；
        // 淡入 120ms、淡出 200ms 时长不同，按相位切换 duration。
        transition: [
          .field(
            ElTransitionField.opacity,
            exiting ? ElLinkStatusBar.hideFadeDuration : ElLinkStatusBar.showFadeDuration,
            Curves.linear,
          ),
          .field(ElTransitionField.maxWidth, ElLinkStatusBar.expandDuration, Curves.linear),
        ],
        onDark: const ElStyle(backgroundColor: Color(0xff1f2020), color: Color(0xffc7c7c7)),
      ),
      child: ElLinkStatusBar._href.value?.toString() ?? '',
    );
  }
}
