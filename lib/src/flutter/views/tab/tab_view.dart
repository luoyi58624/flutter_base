import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, precisionErrorTolerance, setEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../view/event/event.dart';
import '../view/event/dispatcher.dart';
import '../../scroll/physics/bouncing_scroll_physics.dart' show ElBouncingScrollPhysics;
import '../../scroll/scroll_behavior.dart' show elScrollPhysicsFor;
import '../view/render/hit_bounds.dart';
import 'tab_controller.dart';

const Curve _kDefaultTabAnimationCurve = Curves.easeOutCubic;
const double _kSnapPageThreshold = 0.35;

/// 松手甩动翻页的速度阈，对齐 Android 原生分页口径
/// （`androidx.viewpager.widget.ViewPager`）：
///
/// ```java
/// private static final int MIN_FLING_VELOCITY = 400; // dips per second
/// mMinimumVelocity = (int) (MIN_FLING_VELOCITY * density);
/// // determineTargetPage:
/// if (Math.abs(deltaX) > mFlingDistance && Math.abs(velocity) > mMinimumVelocity) {
///     targetPage = velocity > 0 ? currentPage : currentPage + 1;
/// }
/// ```
///
/// Flutter 的逻辑像素等价 Android 的 dip，故常量直接取 400 原值（曾为 700，
/// 比原生严 1.75 倍——轻扫甩不过去的直接原因）。
///
/// Android 的另一半 `MIN_DISTANCE_FOR_FLING = 25` dip 位移阈**不在此重复**：
/// 手势层已经把它做过一遍（drag machine 的 fling 双阈 = 设备 hit slop 位移 +
/// 最小速度，触摸 18 逻辑像素），再叠一道会连 slop 一起重复计费，反而比
/// Android 的"16dip 分页 slop + 25dip 总位移"更严。
const double _kMinFlingPageVelocity = 400.0;

/// settle 弹簧（页单位轴）**默认值**——仅在 physics 合成链上无人覆写
/// `spring` 时生效；全局 behavior 或 widget.physics 点名了弹簧则跟随
/// （见 [_TabViewState._settleSpring]）。临界阻尼（ratio 1.0，零过冲不荡回），mass 0.5 /
/// stiffness 120 → ω=√(120/0.5)≈15.5/s。iOS 风格的时间分布：前段进给快
/// （~200ms 走完 ~80% 行程）、尾段渐近缓出（视觉 ~500ms 基本静止，收敛到
/// ±1px 实测 42 帧 ≈ 670ms），绝无"急停"断感。松手速度延续进初速度，时长
/// 仍由物理涌现；快甩的入射速度会被钳到零过冲上界（见
/// [_TabViewState._settleSimulation]）。
///
/// 历史标定：曾为 k400（~300ms 快停靠，e2d6f41b1），2026-08-02 用户裁决改
/// iOS 风格——300ms 尾段被砍太急，结束要缓慢。也不回官方默认弹簧
/// （k100 / r1.1 过阻尼，慢根 9.1/s 实测 ≈1 秒）：那是整体拖沓，不是
/// "前快尾缓"。
///
/// 也**不复用** [elWebKitRubberBandSpring]（k200）：那是橡皮筋"被拉住又
/// 松开"的回弹口径，与分页"送到目标页"是两种动作，各自标定各自的时长。
/// 越界回弹本身仍走环境物理（见 [_TabViewState._settleSimulation] 的让位
/// 分支），那条路上用的正是 bouncing 自己的弹簧。
final SpringDescription _kTabSettleSpring = SpringDescription.withDampingRatio(mass: 0.5, stiffness: 120.0, ratio: 1.0);

/// 仅负责水平滑动切换视口内容的核心分页容器。
///
/// 性能架构：页面默认全量挂载（[lazy] 可换"首次露出才构建 + [keepState] /
/// [maxCacheCount] LRU 缓存"）、一次布局；position（拖拽跟手 / 切换动画）只走
/// render 层 paint shift（[_RenderTabViewport] 直挂 controller 监听 →
/// markNeedsPaint），每帧零 build 零 layout；每页是独立 repaint boundary
/// （[_RenderTabPage]），位移只更新各页 layer 偏移，页内容零重录——跟手成本
/// 与滚动同量级。命中测试用实时位移换算，切换动画进行中新指针即可命中
/// 移动中的页面、立即接管其内部滚动手势。
///
/// 本体不认识标签栏、路由或业务状态；上层可自行监听 [controller] 和
/// [onIndexChanged]，决定如何把视口状态接到其他组件。
class ElTabView extends StatefulWidget {
  /// 创建水平分页视口。
  const ElTabView({
    super.key,
    required this.children,
    this.controller,
    this.initialIndex = 0,
    this.physics,
    this.dragDevices,
    this.dragStartDistance,
    this.lazy = false,
    this.keepState = true,
    this.maxCacheCount,
    this.viewportFraction = 1.0,
    this.onIndexChanged,
    this.onDragStateChanged,
  }) : assert(initialIndex >= 0),
       assert(maxCacheCount == null || maxCacheCount >= 1),
       assert(viewportFraction > 0.0);

  /// 按下标排列的视口内容。
  final List<Widget> children;

  /// 可选的视口控制器；未传时由本体创建并持有内部控制器。
  final ElTabController? controller;

  /// 未传 [controller] 时的初始页下标。
  final int initialIndex;

  /// 分页使用的滚动物理（个体覆写，优先级高于环境）。
  ///
  /// null 时读环境 `ScrollConfiguration.of(context).getScrollPhysics(context)`
  /// ——与 ElScroll 完全同口径：挂 `ElScrollBehavior` 的应用按 el 平台口径
  /// 拿默认物理（iOS / Linux / Windows bouncing、macOS bouncing-fast、Android /
  /// Fuchsia clamping），想改在子树包一层 `ScrollConfiguration`。
  final ScrollPhysics? physics;

  /// 允许拖拽翻页的设备。null（默认）= 跟随环境
  /// `ScrollConfiguration.of(context).dragDevices`，与 ElScroll
  /// 完全同口径（官方 touch-like 那套：touch / stylus /
  /// trackpad / unknown，**不含 mouse**）。
  ///
  /// 桌面想用鼠标拖着翻页就显式给，例如
  /// `dragDevices: {...PointerDeviceKind.values}`；也可以在全局
  /// `ScrollConfiguration` 的 behavior 里加 mouse，一处生效、滚动与分页一致。
  ///
  /// 触控板（两指横扫）走的是 `PointerPanZoom` 通道而非 down/move/up，本参数
  /// 同样对它生效（判定见 [_TabViewState._handlePanZoomStart]）。
  final Set<PointerDeviceKind>? dragDevices;

  /// 覆写开始拖页所需的设备移动距离。
  final double? dragStartDistance;

  /// 懒加载：页面首次进入可视范围（含拖拽 / 切换动画中的露出、animateTo 的
  /// 目标页）才构建；false（默认）= 挂载时全量构建所有页面。
  final bool lazy;

  /// 懒加载下已构建的页面离开可视范围后是否保留实例（State 不销毁，回来
  /// 免重建）；false = 离开可视范围即销毁，再次进入重建。仅 [lazy] 为 true
  /// 时有意义。
  final bool keepState;

  /// [keepState] 保留实例的数量上限（含可视页计数）：超出按**最久未访问**
  /// 销毁（可视页与当前页绝不销毁）。null = 不限量。仅懒加载 + 保留状态
  /// 时有意义。
  final int? maxCacheCount;

  /// 单页占视口宽度的比例。
  final double viewportFraction;

  /// 落定页发生变化时回调新下标。
  final ValueChanged<int>? onIndexChanged;

  /// 用户拖拽状态发生变化时回调。
  final ValueChanged<bool>? onDragStateChanged;

  @override
  State<ElTabView> createState() => _TabViewState();
}

class _TabViewState extends State<ElTabView> with SingleTickerProviderStateMixin {
  late ElTabController _controller;
  late bool _ownsController;
  late final AnimationController _animationController;
  late final TabAnimationDelegate _animateDelegate = _animateTo;
  late final void Function(int index) _jumpDelegate = _jumpTo;
  double _animationTarget = 0.0;
  double _dragStartPosition = 0.0;
  double _lastDragOffset = 0.0;
  double _lastViewportExtent = 0.0;
  int _lastReportedIndex = 0;
  bool _dragConsumedInGesture = false;

  /// 本手势是否已派发 [ScrollStartNotification]。
  ///
  /// 通知流口径照官方 ScrollPosition（也是 scroll_drag_controller 踩过的坑）：
  /// Start / End 整个手势各一次，越界期间是**纯 Overscroll 序列**——多余的
  /// End 会让官方 StretchingOverscrollIndicator 提前回收再叠加，拉伸棘轮式
  /// 增长不收敛。
  bool _sentScrollStart = false;

  /// 生效的滚动物理，解析链与 ElScroll 单源一致：widget 直参 >
  /// `ScrollConfiguration.of(context).getScrollPhysics(context)`（环境默认）。
  /// 越界拉伸 / 到边硬止 / 回弹弹道全部由它决定，tab 自己不再造物理。
  late ScrollPhysics _physics;

  /// 允许拖拽翻页的设备集合，与 [_physics] 同一条"先读环境、widget 覆写"的链：
  /// 默认取 `ScrollConfiguration.of(context).dragDevices`（官方 touch-like 那套，
  /// **不含 mouse**），与 ElScroll 完全同口径。
  ///
  /// 桌面要鼠标拖页就显式给 [ElTabView.dragDevices]（或全局在 behavior 里加
  /// mouse，一处生效）。曾经这里是 `null 即不过滤`，鼠标能拖是漏出来的——
  /// 既没跟环境对齐，也和滚动容器的口径正好相反（滚动不让鼠标拖、tab 让）。
  late Set<PointerDeviceKind> _dragDevices;
  double _devicePixelRatio = 1.0;

  /// 懒加载簿记：已构建页面集合，插入序即访问新旧序（最旧在前）；可视命中
  /// 刷新到队尾。仅 [ElTabView.lazy] 为 true 时参与 build 决策。
  final Set<int> _loadedPages = <int>{};

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? ElTabController(length: widget.children.length, initialIndex: widget.initialIndex);
    _ownsController = widget.controller == null;
    _controller
      ..setLength(widget.children.length)
      ..attach(animateTo: _animateDelegate, jumpTo: _jumpDelegate);
    _controller.addListener(_onControllerChangedForLazy);
    _lastReportedIndex = _controller.index;
    if (widget.lazy) _syncLazyPages(notify: false);
    // unbounded：controller.value 直接承载页单位 position（弹簧/补间共用）。
    _animationController = AnimationController.unbounded(vsync: this)
      ..addListener(_handleAnimationTick)
      ..addStatusListener(_handleAnimationStatus);
    _scheduleLazyPrefetch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolvePhysics();
    _resolveDragDevices();
    _devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
  }

  void _resolveDragDevices() {
    _dragDevices = widget.dragDevices ?? ScrollConfiguration.of(context).dragDevices;
  }

  /// 与 `ElScroll` 同一条解析链（替换语义，非
  /// applyTo 合成）：widget 直参 > 环境默认（官方 `ScrollConfiguration` 通道，
  /// 挂 `ElScrollBehavior` 即 el 平台口径）；头部的官方 bouncing 统一升级成
  /// [ElBouncingScrollPhysics] 拿动量修正。tab 无刷新器，链上没有 refresher 一环。
  ///
  /// 只在 [didChangeDependencies] / [didUpdateWidget] 调用——两条路径都有
  /// context，查 inherited 安全。
  void _resolvePhysics() {
    // 与 ElScroll 同口径：直读而非 [ScrollConfiguration.of]——后者的兜底会让
    // 「没人包 ScrollConfiguration」和「祖先就是官方基类」不可区分，el 平台口径
    // 就永远轮不到。
    final base =
        widget.physics ??
        context.dependOnInheritedWidgetOfExactType<ScrollConfiguration>()?.behavior.getScrollPhysics(context) ??
        elScrollPhysicsFor(defaultTargetPlatform);
    _physics = ElBouncingScrollPhysics.upgrade(base);
  }

  @override
  void didUpdateWidget(covariant ElTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.physics != oldWidget.physics) _resolvePhysics();
    if (!setEquals(widget.dragDevices, oldWidget.dragDevices)) _resolveDragDevices();
    if (!identical(oldWidget.controller, widget.controller)) {
      _controller.removeListener(_onControllerChangedForLazy);
      _controller.detach(animateTo: _animateDelegate, jumpTo: _jumpDelegate);
      if (_ownsController) {
        _controller.dispose();
      }
      _controller =
          widget.controller ?? ElTabController(length: widget.children.length, initialIndex: widget.initialIndex);
      _ownsController = widget.controller == null;
      _lastReportedIndex = _controller.index;
      _controller.attach(animateTo: _animateDelegate, jumpTo: _jumpDelegate);
      _controller.addListener(_onControllerChangedForLazy);
    }
    _controller.setLength(widget.children.length);
    if (widget.lazy != oldWidget.lazy) {
      _loadedPages.clear();
      if (widget.lazy) _syncLazyPages(notify: false);
    } else if (widget.lazy) {
      // children 收缩剪掉越界项；keepState / maxCacheCount 变化即刻生效。
      _loadedPages.removeWhere((i) => i >= widget.children.length);
      _syncLazyPages(notify: false);
    }
    _maybeReportIndexChanged();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChangedForLazy);
    _controller.detach(animateTo: _animateDelegate, jumpTo: _jumpDelegate);
    _animationController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  // --- 懒加载（lazy=true） ---------------------------------------------------

  void _onControllerChangedForLazy() {
    if (!mounted) return;
    _scheduleSettleGuard();
    if (!widget.lazy) return;
    _syncLazyPages(notify: true);
  }

  bool _settleGuardScheduled = false;

  /// 复位不变量守卫：**idle 时 position 必须停在整页上**。
  ///
  /// 既不在拖拽、也没有动画在跑，而 position 停在页与页之间——这是"没人会
  /// 再推它一把"的死状态，补一次停靠。
  ///
  /// 存在意义是兜住**未知的 dragEnd 丢失路径**：手势竞技场里后代随时能截断
  /// 冒泡（stopPropagation / 结构替换 / 多指抬手顺序），漏掉一次 dragEnd 就
  /// 永久卡在半页。与其逐条堵漏，不如把"idle ⇒ 停在整页"做成硬不变量。
  void _scheduleSettleGuard() {
    if (_settleGuardScheduled || !_isStrandedMidPage()) return;
    _settleGuardScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settleGuardScheduled = false;
      if (!mounted || !_isStrandedMidPage()) return;
      unawaited(_animateTo(_controller.position.round()));
    });
    // postFrame 回调本身不调度帧：卡死态往往正是"没有下一帧"，必须显式催一帧
    // 否则守卫永远不执行。
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _isStrandedMidPage() {
    if (_controller.isDragging || _animationController.isAnimating) return false;
    final position = _controller.position;
    return (position - position.roundToDouble()).abs() >= precisionErrorTolerance;
  }

  /// 可视命中即挂载（每页仅首次露出触发一次 setState，非逐帧），随后按
  /// keepState / maxCacheCount 收缩缓存。
  void _syncLazyPages({required bool notify}) {
    final visible = _visiblePages();
    var changed = false;
    for (final i in visible) {
      final hit = _loadedPages.remove(i);
      _loadedPages.add(i); // 命中只刷新访问序；未命中即新挂载。
      if (!hit) changed = true;
    }
    if (!widget.keepState) {
      final leave = _loadedPages.where((i) => !visible.contains(i)).toList();
      if (leave.isNotEmpty) {
        _loadedPages.removeAll(leave);
        changed = true;
      }
    } else {
      final max = widget.maxCacheCount;
      if (max != null && _loadedPages.length > max) {
        // 迭代序即访问序（最旧在前）：跳过可视页，淘汰最久未访问的溢出项。
        final evicted = _loadedPages.where((i) => !visible.contains(i)).take(_loadedPages.length - max).toList();
        if (evicted.isNotEmpty) {
          _loadedPages.removeAll(evicted);
          changed = true;
        }
      }
    }
    if (changed && notify) setState(() {});
  }

  bool _lazyPrefetchScheduled = false;

  /// 空闲预热：settle 后把相邻页（index ± 1）在空闲帧逐页预挂载——首次
  /// 拖拽 / 切换到邻页时内容已就绪，消除"首次露出整页构建"的单帧尖刺
  /// （实测掉到 ~70fps 的根因）。每帧最多挂一页摊开成本；手势 / 动画期间
  /// 不抢帧；不挤占 [ElTabView.maxCacheCount] 预算（预热到上限即停，绝不
  /// 为预热淘汰已缓存页）。
  void _scheduleLazyPrefetch() {
    // keepState=false 是"最小驻留"意图：预挂的邻页下一个手势 tick 就会被
    // 收缩逻辑销毁，纯属挂载/销毁空转，不预热。
    if (!widget.lazy || !widget.keepState || _lazyPrefetchScheduled) return;
    _lazyPrefetchScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lazyPrefetchScheduled = false;
      if (!mounted || !widget.lazy) return;
      if (_controller.isDragging || _controller.isAnimating) return;
      final target = _nextPrefetchPage();
      if (target == null) return;
      setState(() => _loadedPages.add(target));
      // setState 已调度下一帧，链式继续直到邻页齐活。
      _scheduleLazyPrefetch();
    });
  }

  int? _nextPrefetchPage() {
    final n = widget.children.length;
    final index = _clampIndex(_controller.index);
    final max = widget.maxCacheCount;
    for (final i in <int>[index + 1, index - 1]) {
      if (i < 0 || i >= n) continue;
      if (_loadedPages.contains(i)) continue;
      if (max != null && _loadedPages.length >= max) return null;
      return i;
    }
    return null;
  }

  /// 当前可视页集合（页单位几何：页 i 可见 ⇔ i − position ∈ (−1−q, 1+q)，
  /// q 为 viewportFraction < 1 时视口两侧露边的页单位宽度）。恒含当前
  /// index——animateTo 一声令下目标页立即挂载，动画到达前内容已就绪。
  Set<int> _visiblePages() {
    final n = widget.children.length;
    if (n == 0) return const <int>{};
    final q = (1 / widget.viewportFraction - 1) / 2;
    final p = _controller.position;
    const eps = 0.001;
    final first = math.max(0, (p - 1 - q + eps).ceil());
    final last = math.min(n - 1, (p + 1 + q - eps).floor());
    return <int>{for (var i = first; i <= last; i++) i, _clampIndex(_controller.index)};
  }

  /// [velocityPixels] 为松手时的滚动偏移轴像素速度，只在默认物理档生效；
  /// 显式给了 duration / curve 则按调用方点名的节奏走补间。
  Future<void> _animateTo(int index, {Duration? duration, Curve? curve, double velocityPixels = 0}) {
    final target = _clampIndex(index).toDouble();
    if ((_controller.position - target).abs() < precisionErrorTolerance &&
        velocityPixels.abs() < precisionErrorTolerance) {
      _settleAt(target.round());
      return Future<void>.value();
    }
    // 页宽未知（首帧前 animateTo）：没有换算尺就没有物理，直接停靠。
    if (_pageExtent <= precisionErrorTolerance) {
      _settleAt(target.round());
      return Future<void>.value();
    }
    _animationController
      ..stop()
      ..value = _controller.position;
    _animationTarget = target;
    _controller.setAnimating(true);
    _controller.setIndexFromPosition(target.round());
    final TickerFuture ticker;
    if (duration != null || curve != null) {
      ticker = _animationController.animateTo(
        target,
        duration: duration ?? _durationForDistance((target - _controller.position).abs()),
        curve: curve ?? _kDefaultTabAnimationCurve,
      );
    } else {
      ticker = _animationController.animateWith(_settleSimulation(target, velocityPixels));
    }
    // 自然完成才停靠；接管 / jumpTo / 新动画替换 / 边界兜底各自管理终态。
    ticker.whenComplete(() {
      if (!mounted || _animationController.isAnimating) return;
      _settleAt(_animationTarget.round());
    });
    // 返回值不能直用 TickerFuture：`stop()`（canceled: true）打断后其主 Future
    // 永不 resolve，`await controller.animateTo(...)` 会永久挂起。对齐官方
    // PageController 被打断也 complete 的口径——取消路径同样 resolve。
    final completer = Completer<void>();
    ticker.whenCompleteOrCancel(() {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  /// 松手停靠的模拟：结构照官方 [PageScrollPhysics.createBallisticSimulation]
  /// ——已在界外且速度不指回界内时**让位给环境物理的弹道**（bouncing 走
  /// 橡皮筋回弹、clamping 直接归边），其余情况用 settle 弹簧精确落到目标页。
  /// 越界回弹因此拿到的是官方 iOS 曲线，而不是 tab 自己糊的补间。
  Simulation _settleSimulation(double targetPage, double velocityPixels) {
    final extent = _pageExtent;
    final metrics = _metrics(extent);
    if ((velocityPixels <= 0.0 && metrics.pixels <= metrics.minScrollExtent) ||
        (velocityPixels >= 0.0 && metrics.pixels >= metrics.maxScrollExtent)) {
      final ballistic = _physics.createBallisticSimulation(metrics, velocityPixels);
      if (ballistic != null) return _PageUnitSimulation(ballistic, extent);
    }
    final spring = _settleSpring;
    // 临界阻尼的零过冲上界：|v0| ≤ ω·|Δx|。快甩的入射速度超界会让轨迹越过
    // 目标页再荡回（弹簧越软上界越低，k120 下 ~3000px/s 的甩速就能穿页）；
    // 钳到上界后位置轨迹退化为纯指数逼近——最快的单调进给，肉眼无断感，
    // 保住"分页停靠绝不越过目标页"的契约。只钳指向目标的分量，背向速度
    // 不会穿页，原样交给弹簧。上界按临界阻尼推导：跟随的自定义弹簧若过
    // 阻尼则此界更保守（仍不穿页）；欠阻尼本来就要荡回，尊重调用方点名。
    final targetPixels = targetPage * extent;
    final rel = metrics.pixels - targetPixels;
    final omega = math.sqrt(spring.stiffness / spring.mass);
    var clampedVelocity = velocityPixels;
    if (rel > 0) {
      clampedVelocity = math.max(clampedVelocity, -omega * rel);
    } else if (rel < 0) {
      clampedVelocity = math.min(clampedVelocity, -omega * rel);
    }
    return _PageUnitSimulation(
      ScrollSpringSimulation(
        spring,
        metrics.pixels,
        targetPixels,
        clampedVelocity,
        tolerance: _physics.toleranceFor(metrics),
      ),
      extent,
    );
  }

  /// settle 弹簧的取值策略（官方 `ScrollPhysics.spring` 委托语义，跟随全局）：
  /// 1. 合成链上任何一层覆写了 `spring`——widget.physics 或全局 behavior 的
  ///    自定义物理，含 `BouncingScrollPhysics(decelerationRate: fast)`——
  ///    跟随链上第一处覆写；
  /// 2. 无人覆写：官方 getter 恒回落到同一个 `_kDefaultSpring` 单例（k100 /
  ///    r1.1 过阻尼，慢根 9.1/s，全页 ≈1 秒，对分页停靠是整体拖沓）→ 用
  ///    tab 自己的 iOS 风格缓出弹簧 [_kTabSettleSpring]。
  ///
  /// 单例判定用 `identical`：官方默认是 `static final`，未覆写的链无论多深
  /// 都返回同一实例；任何真覆写（哪怕参数恰好相同）都是新实例，视为点名。
  SpringDescription get _settleSpring {
    final resolved = _physics.spring;
    return identical(resolved, const ScrollPhysics().spring) ? _kTabSettleSpring : resolved;
  }

  void _jumpTo(int index) {
    _animationController.stop();
    _controller.setAnimating(false);
    _settleAt(_clampIndex(index));
  }

  void _handleAnimationTick() {
    final value = _animationController.value;
    final extent = _pageExtent;
    if (extent > precisionErrorTolerance) {
      final metrics = _metrics(extent);
      final pixels = value * extent;
      // 与官方 `ScrollPosition.setPixels` 同构的边界兜底：模拟交出的位置先过一遍
      // 环境物理的 [ScrollPhysics.applyBoundaryConditions]——clamping 把越界量
      // 吃掉（硬止），bouncing 恒返回 0（橡皮筋照常出界）。
      //
      // **这道兜底省不得**：物理交出的弹道本来就允许越界，边界是靠下游 setPixels
      // 拦住的；ElTabView 自己扮演 ScrollPosition，不做就没人做——
      //   · el 的 clamping 物理（`ElClampingScrollPhysics`）贴边 + 外向速度
      //     直接给一条一路向外的摩擦曲线（v=1000 飞一屏、v=8000 飞八屏）；
      //   · 官方 [ClampingScrollPhysics] 此时返回 null，落回 settle 弹簧，而弹簧
      //     同样带外向速度起步，照样把 position 推出界。
      // 实测漏网峰值 position 6.68 / −4.68（见 el_tab_view_boundary_test）。
      if ((pixels - metrics.pixels).abs() > precisionErrorTolerance) {
        final overscroll = _physics.applyBoundaryConditions(metrics, pixels);
        if (overscroll != 0.0) {
          // 边界吃掉了这一步的位移：这条弹道已经没有意义，停下并停靠到边界页
          // ——对齐官方 `BallisticScrollActivity` 收到非零 overscroll 即 goIdle。
          // 冲击速度要在 stop() 前取。
          final impactVelocity = _animationController.velocity * extent;
          _controller.setPosition((pixels - overscroll) / extent);
          _animationController.stop();
          // 撞界冲击喂 indicator（stretch 走 absorbImpact），随后按官方弹道
          // 撞界即收尾的口径补 ScrollEnd。
          _dispatchOverscroll(overscroll, velocity: impactVelocity);
          _dispatchScrollEnd();
          _settleAt(_controller.position.round());
          return;
        }
      }
    }
    _controller.setPosition(value);
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
      _controller.setAnimating(false);
    }
  }

  void _handleDragStart(ElEventDetails event) {
    if (!_canDrag) return;
    // **这里绝不停 settle 动画、也不置 dragging**：起手只说明 tab 是这条手势
    // 的候选者之一，内层滚动（横向滚动带 / 嵌套横滑）完全可能把位移全吃掉。
    //
    // 曾经在此无条件 `stop()`：一旦后续 dragEnd 没投递回 tab（后代
    // stopPropagation 截断冒泡等），动画既停了又没人重启 → 永久钉在半页不
    // 归位（用户实测：动画中去滚内容即复现）。接管改到**真正消费到位移**
    // 那一刻（[_takeOverDrag]）。
    _dragConsumedInGesture = false;
    _dragStartPosition = _controller.position;
    _lastDragOffset = 0.0;
    _handleDragUpdate(event);
  }

  /// 首次真正消费位移 = tab 抢下了这条手势：此刻才停 settle 动画、置
  /// dragging，并以**当刻**位置（动画跑到哪算哪）为拖拽基准，接管无缝。
  void _takeOverDrag() {
    if (_dragConsumedInGesture) return;
    _dragConsumedInGesture = true;
    _animationController.stop();
    _controller.setAnimating(false);
    _dragStartPosition = _controller.position;
    _setDragging(true);
    // 手势归 tab 了，页内容此刻起不再吃指针：tap 的取消阈值远小于翻页所需
    // 位移，不屏蔽的话抬手会误触页内卡片。
    _setPagesIgnorePointer(true);
  }

  void _handleDragUpdate(ElEventDetails event) {
    if (!_canDrag) return;
    final extent = _pageExtent;
    if (extent <= precisionErrorTolerance) return;
    final currentDragOffset = event.dragOffset.dx;
    final cumulativeDelta = currentDragOffset - _lastDragOffset;
    final primaryDelta = cumulativeDelta.abs() > precisionErrorTolerance
        ? cumulativeDelta
        : event.remainingPrimaryDelta(Axis.horizontal);
    if (primaryDelta.abs() <= precisionErrorTolerance) {
      if (_dragConsumedInGesture) {
        _consumeHorizontal(event);
      }
      return;
    }

    final consumedPixels = _applyHorizontalDelta(primaryDelta, extent, event: event);

    if (consumedPixels.abs() > precisionErrorTolerance || _dragConsumedInGesture) {
      _lastDragOffset = currentDragOffset;
    }

    if (_dragConsumedInGesture) {
      _consumeHorizontal(event);
    }
  }

  /// 把一段水平位移交给**环境物理**并写进 position，返回实际被消费的像素量
  /// （0 = 物理拒绝，例如 clamping 已经到边）。手指拖拽与触控板 pan 共用这一条。
  ///
  /// 与官方 `ScrollPosition.applyUserOffset` + `setPixels` 逐步同构：
  ///   pixels -= physics.applyPhysicsToUserOffset(metrics, delta)   ← bouncing 越界摩擦（橡皮筋）
  ///   pixels -= physics.applyBoundaryConditions(metrics, newPixels) ← clamping 归边（硬止）
  /// 越界要不要拉伸、拉伸多沉，全由环境物理说话；tab 不自带线性系数。
  ///
  /// 被边界吃掉的量按官方 `setPixels → didOverscrollBy` 的口径报
  /// [OverscrollNotification]，喂正上方 [ScrollBehavior.buildOverscrollIndicator]
  /// 出的 stretch / glow——clamping 环境（Android / 桌面默认）贴边继续外拉
  /// 曾经是静默黑洞：位移被吃、无通知、无视效。
  double _applyHorizontalDelta(double primaryDelta, double extent, {ElEventDetails? event}) {
    final metrics = _metrics(extent);
    final resisted = _physics.applyPhysicsToUserOffset(metrics, primaryDelta);
    var newPixels = metrics.pixels - resisted;
    final overscroll = _physics.applyBoundaryConditions(metrics, newPixels);
    newPixels -= overscroll;
    final consumedPixels = metrics.pixels - newPixels;
    if (consumedPixels.abs() <= precisionErrorTolerance) {
      if (overscroll.abs() <= precisionErrorTolerance) return 0.0;
      // 贴边继续外拉：位移全被边界物理吃掉。三态裁决照 scroll_drag_controller：
      // 有外层拖拽消费者且本手势尚未接管 → 让渡（嵌套 tab / 外层横滑接管）；
      // 自己是顶层 → 接管手势（停动画、屏蔽页内命中、按帧记账）并报越界。
      if (event != null && event.hasAncestorDragConsumer && !_dragConsumedInGesture) return 0.0;
      event?.eagerGesture(cancelSelfTap: true);
      _takeOverDrag();
      _ensureScrollStart();
      _dispatchOverscroll(overscroll, event: event);
      return 0.0;
    }
    // 先接管（停动画 + 以当刻位置为基准），再写入本次位移。
    event?.eagerGesture(cancelSelfTap: true);
    _takeOverDrag();
    _ensureScrollStart();
    final adjusted = newPixels / extent;
    _controller.setPosition(adjusted);
    _controller.setIndexFromPosition(adjusted.round());
    // 官方 setPixels 同款顺序：先 Update（拖回界内时 indicator 借此回收），
    // 跨界帧再补报被吃掉的越界量。
    _dispatchScrollUpdate(-consumedPixels);
    if (overscroll.abs() > precisionErrorTolerance) _dispatchOverscroll(overscroll, event: event);
    return consumedPixels;
  }

  /// 页宽（viewportFraction 折算后），也是 [_metrics] 的页单位 ↔ 像素换算尺。
  double get _pageExtent => _lastViewportExtent * widget.viewportFraction;

  /// 把页单位轴投影成物理要的像素轴 metrics：一页 = 一个 viewport，
  /// max = (页数 − 1) × 页宽。物理里所有绝对常数（摩擦系数、tolerance、
  /// 弹道速度阈）都是像素标定的，必须在像素轴上喂。
  ScrollMetrics _metrics(double extent) {
    return FixedScrollMetrics(
      minScrollExtent: 0.0,
      maxScrollExtent: math.max(0, widget.children.length - 1) * extent,
      pixels: _controller.position * extent,
      viewportDimension: extent,
      axisDirection: AxisDirection.right,
      devicePixelRatio: _devicePixelRatio,
    );
  }

  // --- 滚动通知流（喂环境 overscroll indicator） -----------------------------

  /// 通知派发锚点元素：夹在 indicator 与 viewport 之间（见 build）。
  final GlobalKey _notificationAnchorKey = GlobalKey();

  /// 通知派发锚点：indicator 恰在其正上方，tab 自家通知到达时 depth 恒 0
  /// （官方 stretch / glow 只认 depth==0）。**不能直接从 viewport 元素派发**
  /// ——[_TabViewportElement] 混入 [ViewportElementMixin] 后自带 depth+1，
  /// 自家通知会被 indicator 当页内通知忽略；页内滚动的通知则正是靠这次
  /// +1 与 tab 自家通知区分开，不会误拉本层。
  BuildContext? get _notificationContext => _notificationAnchorKey.currentContext;

  /// 手势内首次真实位移 / 越界时派发一次 ScrollStart（见 [_sentScrollStart]
  /// 的 Start/End 各一次口径）。
  void _ensureScrollStart() {
    if (_sentScrollStart) return;
    final context = _notificationContext;
    final extent = _pageExtent;
    if (context == null || extent <= precisionErrorTolerance) return;
    _sentScrollStart = true;
    ScrollStartNotification(metrics: _metrics(extent), context: context).dispatch(context);
  }

  /// 位移应用后的 ScrollUpdate：官方口径下 indicator 收到界内滚动即启动
  /// 回收，拖回界内时拉伸不冻结。
  void _dispatchScrollUpdate(double scrollDeltaPixels) {
    final context = _notificationContext;
    final extent = _pageExtent;
    if (context == null || extent <= precisionErrorTolerance) return;
    ScrollUpdateNotification(
      metrics: _metrics(extent),
      context: context,
      scrollDelta: scrollDeltaPixels,
    ).dispatch(context);
  }

  /// 越界量报告：拖拽帧 velocity 0（indicator 走 pull），弹道撞界帧带冲击
  /// 速度（indicator 走 absorbImpact）。符号与官方一致：负 = 前边界，
  /// 正 = 后边界。[event] 提供指位供 glow 定位（stretch 不需要）。
  void _dispatchOverscroll(double overscrollPixels, {double velocity = 0.0, ElEventDetails? event}) {
    final context = _notificationContext;
    final extent = _pageExtent;
    if (context == null || extent <= precisionErrorTolerance) return;
    OverscrollNotification(
      metrics: _metrics(extent),
      context: context,
      overscroll: overscrollPixels,
      velocity: velocity,
      dragDetails: event == null ? null : DragUpdateDetails(globalPosition: event.globalPosition),
    ).dispatch(context);
  }

  /// 仅当本手势派发过 Start 才补 End——手势归内层滚动时 tab 不得插入
  /// 多余的 End（会打断内层 indicator 的状态机）。
  void _dispatchScrollEndIfStarted() {
    if (!_sentScrollStart) return;
    _dispatchScrollEnd();
  }

  /// 无条件 ScrollEnd：弹道撞界（absorbImpact）后按官方
  /// `BallisticScrollActivity` 撞界即收尾的口径补发；未拉伸时 indicator
  /// 收到它是 no-op。
  void _dispatchScrollEnd() {
    _sentScrollStart = false;
    final context = _notificationContext;
    final extent = _pageExtent;
    if (context == null || extent <= precisionErrorTolerance) return;
    ScrollEndNotification(metrics: _metrics(extent), context: context).dispatch(context);
  }

  void _handleDragEnd(ElEventDetails event) {
    // 松手即恢复页内容命中——含"甩出去"那一下：settle 动画还在跑时点内容
    // 就该点得到（曾按惯性速度逐帧重估，被用户裁决简化为拖拽边界开关）。
    _setPagesIgnorePointer(false);
    _dispatchScrollEndIfStarted();
    if (!_canDrag) {
      _setDragging(false);
      return;
    }
    // 一点位移都没消费 = 这条手势归别人（内层滚动吃满）。此时**必须什么都
    // 不做**：既不能拿内层滚动的甩动速度去算目标页（会被劫持翻页），也不能
    // 打断可能仍在跑的 settle 动画。
    if (!_dragConsumedInGesture) {
      _setDragging(false);
      return;
    }
    // 手势像素速度 → 滚动偏移轴（position 与手指位移反向）。像素口径直送
    // settle：起步与手势动量连续，不从零起跳。
    final pixelVelocity = event.primaryVelocity ?? event.velocity.pixelsPerSecond.dx;
    final target = _targetPageForRelease(pixelVelocity);
    _setDragging(false);
    unawaited(_animateTo(target, velocityPixels: -pixelVelocity));
  }

  // --- 触控板两指横扫（PointerPanZoom 通道） ---------------------------------
  //
  // 触控板不走 drag machine：系统发的是 PointerPanZoom* 而不是 down/move/up，
  // 所以 dispatcher 的 dragDevices 过滤也管不到它，得自己判一次。口径照
  // `scroll_drag_controller` 的既有触控板路径（pan 增量 + 自持 VelocityTracker），
  // 不另发明一套。

  Offset _trackpadLastPan = Offset.zero;
  VelocityTracker? _trackpadVelocity;
  bool _trackpadActive = false;

  void _handlePanZoomStart(ElEventDetails event) {
    if (!_canDrag || !_dragDevices.contains(PointerDeviceKind.trackpad)) return;
    _trackpadActive = true;
    _trackpadLastPan = Offset.zero;
    _trackpadVelocity = VelocityTracker.withKind(PointerDeviceKind.trackpad);
    // 与 [_handleDragStart] 同理：起手只是候选者，真正消费到位移才接管。
    _dragConsumedInGesture = false;
    _dragStartPosition = _controller.position;
  }

  void _handlePanZoomUpdate(ElEventDetails event) {
    if (!_trackpadActive) return;
    final original = event.originalEvent;
    if (original is! PointerPanZoomUpdateEvent) return;
    final extent = _pageExtent;
    if (extent <= precisionErrorTolerance) return;

    final pan = original.pan;
    final panDelta = pan - _trackpadLastPan;
    _trackpadLastPan = pan;
    _trackpadVelocity?.addPosition(original.timeStamp, pan);

    // 原始 pan 增量优先，但内层已消费掉的部分要让出去：与滚动侧
    // `_trackpadPrimaryPanDelta` 同一套裁决——增量为 0 用剩余量，剩余量为 0 用
    // 增量，两者反向时信剩余量（内层吃了，别硬抢）。
    final remaining = event.remainingPrimaryDelta(Axis.horizontal);
    final primaryDelta = switch ((panDelta.dx, remaining)) {
      (final d, _) when d.abs() <= precisionErrorTolerance => remaining,
      (final d, final r) when r.abs() <= precisionErrorTolerance => d,
      (final d, final r) when d.sign != r.sign => r,
      (final d, _) => d,
    };
    if (primaryDelta.abs() <= precisionErrorTolerance) {
      if (_dragConsumedInGesture) _consumeHorizontal(event);
      return;
    }

    _applyHorizontalDelta(primaryDelta, extent, event: event);
    if (_dragConsumedInGesture) _consumeHorizontal(event);
  }

  void _handlePanZoomEnd(ElEventDetails event) {
    if (!_trackpadActive) return;
    _trackpadActive = false;
    _setPagesIgnorePointer(false);
    _dispatchScrollEndIfStarted();
    final pixelVelocity = _trackpadVelocity?.getVelocity().pixelsPerSecond.dx ?? 0.0;
    _trackpadVelocity = null;
    _trackpadLastPan = Offset.zero;
    // 同 [_handleDragEnd]：没消费过就没接管过，不许拿别人的速度翻页、也不许
    // 打断在跑的 settle。
    if (!_dragConsumedInGesture) {
      _setDragging(false);
      return;
    }
    final target = _targetPageForRelease(pixelVelocity);
    _setDragging(false);
    unawaited(_animateTo(target, velocityPixels: -pixelVelocity));
  }

  void _handleDragCancel(ElEventDetails event) {
    _setPagesIgnorePointer(false);
    _dispatchScrollEndIfStarted();
    _setDragging(false);
    // 同 [_handleDragEnd]：没消费过就没接管过，不许打断在跑的 settle。
    if (!_dragConsumedInGesture) return;
    unawaited(_animateTo(_controller.index));
  }

  int _targetPageForRelease(double velocity) {
    final position = _controller.position;
    final current = _clampIndex(_dragStartPosition.round());
    final delta = position - current;
    // 甩动优先（Android determineTargetPage 口径）：过速度阈就按甩动方向翻
    // 一页，**与已拖出的比例无关**——轻扫只挪了几像素也照样过页。位置阈只是
    // 慢拖松手的兜底。
    if (velocity.abs() >= _kMinFlingPageVelocity) {
      return _clampIndex(velocity < 0 ? current + 1 : current - 1);
    }
    if (delta.abs() >= _kSnapPageThreshold) {
      return _clampIndex(delta > 0 ? current + 1 : current - 1);
    }
    return _clampIndex(position.round());
  }

  void _consumeHorizontal(ElEventDetails event) {
    event.consumePrimaryDelta(Axis.horizontal, event.remainingPrimaryDelta(Axis.horizontal));
  }

  void _setDragging(bool value) {
    if (_controller.isDragging == value) return;
    _controller.setDragging(value);
    widget.onDragStateChanged?.call(value);
  }

  void _settleAt(int index) {
    final target = _clampIndex(index);
    _controller.setAnimating(false);
    _controller.setPosition(target.toDouble());
    _controller.setIndexFromPosition(target);
    _controller.settleAt(target);
    _maybeReportIndexChanged();
    // 停靠后空闲预热新邻页。
    _scheduleLazyPrefetch();
  }

  void _maybeReportIndexChanged() {
    final index = _controller.index;
    if (_lastReportedIndex == index) return;
    _lastReportedIndex = index;
    widget.onIndexChanged?.call(index);
  }

  int _clampIndex(int index) {
    if (widget.children.isEmpty) return 0;
    return index.clamp(0, widget.children.length - 1);
  }

  bool get _canDrag => widget.children.length > 1;

  /// 拖拽期屏蔽页内容命中的开关落点（见 [_RenderTabViewport.ignorePointer]）。
  final GlobalKey _viewportKey = GlobalKey();

  void _setPagesIgnorePointer(bool value) {
    final render = _viewportKey.currentContext?.findRenderObject();
    if (render is _RenderTabViewport) render.ignorePointer = value;
  }

  Duration _durationForDistance(double pages) {
    final millis = (160 + pages.clamp(0.0, 1.0) * 140).round();
    return Duration(milliseconds: millis);
  }

  @override
  Widget build(BuildContext context) {
    final Widget viewport = _TabViewport(
      key: _viewportKey,
      controller: _controller,
      viewportFraction: widget.viewportFraction,
      onViewportWidth: _onViewportWidth,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _TabPage(
            key: ValueKey<Object>(widget.children[i].key ?? i),
            // 懒加载未挂载页留空壳占位（RenderProxyBox 空子按 tight 约束
            // 占位），base offset 的页序几何恒稳定。
            child: !widget.lazy || _loadedPages.contains(i) ? widget.children[i] : null,
          ),
      ],
    );
    return _TabEventSurface(
      event: ElEvent(
        dragStartDistance: widget.dragStartDistance ?? MediaQuery.maybeGestureSettingsOf(context)?.touchSlop,
        dragDevices: _dragDevices,
        onHorizontalDragStart: _handleDragStart,
        onHorizontalDragUpdate: _handleDragUpdate,
        onHorizontalDragEnd: _handleDragEnd,
        onHorizontalDragCancel: _handleDragCancel,
        onPointerPanZoomStart: _handlePanZoomStart,
        onPointerPanZoomUpdate: _handlePanZoomUpdate,
        onPointerPanZoomEnd: _handlePanZoomEnd,
      ),
      // 越界视效交环境 ScrollConfiguration 收口（与 ElScroll 同源）：
      // Android M3 出 stretch、旧主题出 glow、iOS / 桌面不建 indicator
      // （iOS 的越界视效由 bouncing 物理本身承担）。indicator 的
      // NotificationListener 直接罩住 viewport，收到的 tab 通知 depth 恒 0。
      child: ScrollConfiguration.of(context).buildOverscrollIndicator(
        context,
        // KeyedSubtree 只当通知派发锚点（无 render、无行为），见
        // [_notificationContext] 的 depth 口径。
        KeyedSubtree(key: _notificationAnchorKey, child: viewport),
        ScrollableDetails(direction: AxisDirection.right, physics: _physics),
      ),
    );
  }

  /// 布局期写入（render 回报，替代 LayoutBuilder）：仅手势换算读取，不触发
  /// rebuild。
  void _onViewportWidth(double width) => _lastViewportExtent = width;
}

/// 像素轴模拟 → 页单位轴适配器。
///
/// 物理（[ScrollSpringSimulation] / [BouncingScrollSimulation]）的常数全是
/// 像素标定的，必须在像素轴构造；而 [ElTabController.position] 与
/// [AnimationController] 恒为页单位（页宽随旋转变化时页单位轴不失真，render
/// 层也只认页单位）。位置 / 速度按页宽缩放，收敛判定 [isDone] 直通内层——
/// tolerance 仍在像素轴上比较，不会因页宽放大而提前 / 延后收敛。
class _PageUnitSimulation extends Simulation {
  _PageUnitSimulation(this._inner, this._extent) : assert(_extent > 0);

  final Simulation _inner;
  final double _extent;

  @override
  double x(double time) => _inner.x(time) / _extent;

  @override
  double dx(double time) => _inner.dx(time) / _extent;

  @override
  bool isDone(double time) => _inner.isDone(time);
}

/// 分页视口 widget：children 全量下沉到 [_RenderTabViewport]。
class _TabViewport extends MultiChildRenderObjectWidget {
  const _TabViewport({
    super.key,
    required this.controller,
    required this.viewportFraction,
    required this.onViewportWidth,
    required super.children,
  });

  final ElTabController controller;
  final double viewportFraction;
  final ValueChanged<double> onViewportWidth;

  @override
  MultiChildRenderObjectElement createElement() => _TabViewportElement(this);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderTabViewport(
      controller: controller,
      viewportFraction: viewportFraction,
      onViewportWidth: onViewportWidth,
    );
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderTabViewport renderObject) {
    renderObject
      ..controller = controller
      ..viewportFraction = viewportFraction
      ..onViewportWidth = onViewportWidth;
  }
}

/// 分页视口元素：与滚动模块的 viewport 元素同款混入——官方通知在 Element
/// 树的 NotificationListener 链上传递，[ViewportElementMixin] 让跨越本
/// viewport 的 [ScrollNotification] depth+1，页内滚动的通知因此不会以
/// depth 0 冒到 tab 的 overscroll indicator 上造成误拉伸。
class _TabViewportElement extends MultiChildRenderObjectElement with NotifiableElementMixin, ViewportElementMixin {
  _TabViewportElement(_TabViewport super.widget);
}

class _TabPageParentData extends ContainerBoxParentData<RenderBox> {}

/// 分页视口 render：页面一次布局（base offset = 页序 × 页宽），position
/// （拖拽 / 切换动画）只作用于 paint 期的整体水平位移——controller 直挂
/// 监听 → markNeedsPaint，每帧零 build 零 layout。命中测试与
/// [applyPaintTransform] 用同一实时位移换算，动画进行中新指针即可命中
/// 移动中的页面。
final class _RenderTabViewport extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TabPageParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TabPageParentData>
    implements RenderAbstractViewport {
  _RenderTabViewport({required this._controller, required this._viewportFraction, required this._onViewportWidth});

  ElTabController _controller;
  double _viewportFraction;
  ValueChanged<double> _onViewportWidth;

  /// 上次 paint 消费的 position：controller 的 index / dragging 等与几何
  /// 无关的通知据此去重，不白排 paint。
  double _paintedPosition = 0.0;

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  set controller(ElTabController value) {
    if (identical(_controller, value)) return;
    if (attached) _controller.removeListener(_onControllerTick);
    _controller = value;
    if (attached) value.addListener(_onControllerTick);
    markNeedsPaint();
  }

  set viewportFraction(double value) {
    if (_viewportFraction == value) return;
    _viewportFraction = value;
    markNeedsLayout();
  }

  set onViewportWidth(ValueChanged<double> value) => _onViewportWidth = value;

  void _onControllerTick() {
    if (_controller.position == _paintedPosition) return;
    markNeedsPaint();
    // 页位移改变语义几何（applyPaintTransform 口径），对齐官方 viewport
    // 滚动时 paint + semantics 双标脏。
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.addListener(_onControllerTick);
  }

  @override
  void detach() {
    _controller.removeListener(_onControllerTick);
    super.detach();
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TabPageParentData) child.parentData = _TabPageParentData();
  }

  double get _pageWidth => size.width * _viewportFraction;

  /// position 对应的整体水平位移（叠加在各页 base offset 之上）。
  double get _shiftX => -_controller.position * _pageWidth;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    size = constraints.biggest;
    final pageWidth = _pageWidth;
    final inset = (size.width - pageWidth) / 2;
    final childConstraints = BoxConstraints.tight(Size(pageWidth, size.height));
    var index = 0;
    var child = firstChild;
    while (child != null) {
      child.layout(childConstraints);
      final parentData = child.parentData! as _TabPageParentData;
      parentData.offset = Offset(inset + index * pageWidth, 0);
      index++;
      child = parentData.nextSibling;
    }
    _onViewportWidth(size.width);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _paintedPosition = _controller.position;
    if (childCount == 0 || size.isEmpty) return;
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      _paintPagesCallback,
      oldLayer: _clipLayer.layer,
    );
  }

  late final PaintingContextCallback _paintPagesCallback = _paintPages;

  void _paintPages(PaintingContext context, Offset offset) {
    final shift = _shiftX;
    var child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as _TabPageParentData;
      final dx = parentData.offset.dx + shift;
      // 可见性剔除：滑出视口的页不参与本帧合成。页是 repaint boundary，
      // 剔除 / 恢复只是页 layer 的摘挂，不触发页内容重录。
      if (dx < size.width && dx + child.size.width > 0) {
        context.paintChild(child, Offset(offset.dx + dx, offset.dy + parentData.offset.dy));
      }
      child = parentData.nextSibling;
    }
  }

  /// 拖拽期间屏蔽页内容命中（与滚动容器的 `ignorePointer` 同口径）：横向
  /// 划动足以翻页，但 tap 只要求位移不超 slop，不屏蔽的话手指抬起时页内的
  /// 卡片会被误选中。开在 [_TabViewState._takeOverDrag]（真正消费位移那
  /// 一刻），关在 drag end / cancel。
  bool get ignorePointer => _ignorePointer;
  bool _ignorePointer = false;
  set ignorePointer(bool value) {
    if (_ignorePointer == value) return;
    _ignorePointer = value;
    // 命中不参与绘制/布局，只需让下一次命中测试读到新值。
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_ignorePointer) return false;
    final shift = Offset(_shiftX, 0);
    var child = lastChild;
    while (child != null) {
      final page = child;
      final parentData = page.parentData! as _TabPageParentData;
      final hit = result.addWithPaintOffset(
        offset: parentData.offset + shift,
        position: position,
        hitTest: (result, transformed) => page.hitTest(result, position: transformed),
      );
      if (hit) return true;
      child = parentData.previousSibling;
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final parentData = child.parentData! as _TabPageParentData;
    transform.translateByDouble(parentData.offset.dx + _shiftX, parentData.offset.dy, 0.0, 1.0);
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => Offset.zero & size;

  /// 实现 [RenderAbstractViewport] 的首要目的：官方
  /// `ViewportNotificationMixin` 按它给冒泡中的 [ScrollNotification] 递增
  /// depth——页内滚动的通知跨越本 viewport 后 depth ≥ 1，tab 自己的
  /// overscroll indicator（只认 depth==0）不会被页内横向滚动误拉。
  ///
  /// 语义本身也如实：返回把 [target] 所在页对准视口所需的滚动偏移
  /// （像素轴，页 i 贴左缘 = base offset；alignment 在贴左缘 / 贴右缘之间
  /// 插值）。单水平轴，[axis] 忽略；target 不在子树时返回当前偏移。
  @override
  RevealedOffset getOffsetToReveal(RenderObject target, double alignment, {Rect? rect, Axis? axis}) {
    RenderObject node = target;
    while (node.parent != null && !identical(node.parent, this)) {
      node = node.parent!;
    }
    final currentPixels = _controller.position * _pageWidth;
    if (!identical(node.parent, this) || node is! RenderBox) {
      return RevealedOffset(offset: currentPixels, rect: rect ?? target.paintBounds);
    }
    final parentData = node.parentData! as _TabPageParentData;
    final leadingPixels = parentData.offset.dx;
    final trailingPixels = parentData.offset.dx + _pageWidth - size.width;
    final targetPixels = leadingPixels + (trailingPixels - leadingPixels) * alignment;
    final bounds = MatrixUtils.transformRect(target.getTransformTo(node), rect ?? target.paintBounds);
    return RevealedOffset(
      offset: targetPixels,
      rect: bounds.shift(Offset(parentData.offset.dx - targetPixels, parentData.offset.dy)),
    );
  }
}

/// 页面壳 widget：只为给每页挂一个 repaint boundary render；child 为 null
/// 时是懒加载占位壳（保持页序几何，不构建内容）。
class _TabPage extends SingleChildRenderObjectWidget {
  const _TabPage({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTabPage();
}

/// 页级 repaint boundary：页位移只更新本页 layer 偏移，页内容零重录——
/// 跟手 / 切换动画期间每帧成本收敛到合成器挪 layer。
final class _RenderTabPage extends RenderProxyBox {
  @override
  bool get isRepaintBoundary => true;
}

class _TabEventSurface extends SingleChildRenderObjectWidget {
  const _TabEventSurface({required this.event, required super.child});

  final ElEvent event;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTabEventSurface(event: event);

  @override
  void updateRenderObject(BuildContext context, covariant _RenderTabEventSurface renderObject) {
    renderObject.event = event;
  }
}

class _RenderTabEventSurface extends RenderProxyBox with ElOverflowHitBounds {
  _RenderTabEventSurface({required ElEvent event}) {
    _dispatcher = EventDispatcher(this);
    _dispatcher.event = event;
  }

  late EventDispatcher _dispatcher;

  set event(ElEvent value) {
    _dispatcher.event = value;
  }

  // --- 溢出命中边界协议（ElOverflowHitBounds） --------------------------------

  @override
  Rect get selfHitRect => Offset.zero & size;

  @override
  bool get clipsHitBounds => false;

  @override
  void visitHitBoundsChildren(void Function(RenderBox child, Offset offset) visitor) {
    final c = child;
    if (c != null) visitor(c, Offset.zero);
  }

  @override
  void performLayout() {
    markHitBoundsDirty();
    super.performLayout();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) {
      // 溢出命中：只转发给溢出的子树，事件面自身语义不出盒。
      if (!hitBoundsContains(position)) return false;
      return hitTestChildren(result, position: position);
    }
    final hitChild = hitTestChildren(result, position: position);
    result.add(BoxHitTestEntry(this, position));
    return hitChild || _dispatcher.hitTestSelf(position);
  }

  @override
  bool hitTestSelf(Offset position) => _dispatcher.hitTestSelf(position);

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    _dispatcher.handleEvent(event, entry);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _dispatcher.attach();
  }

  @override
  void detach() {
    _dispatcher.detach(preserveEvent: true);
    super.detach();
  }

  @override
  void dispose() {
    _dispatcher.dispose();
    super.dispose();
  }
}
