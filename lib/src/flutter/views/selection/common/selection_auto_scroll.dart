import 'dart:collection' show HashSet;
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../scroll/viewport.dart' show ScrollViewport;

/// 文本选区、编辑器和对象框选共用的边缘滚动参数。
@immutable
class SelectionAutoScrollConfig {
  /// 创建。
  const SelectionAutoScrollConfig({
    required this.beltExtent,
    required this.speedRampExtent,
    required this.maxFrameDelta,
    this.minFrameDelta = 0.0,
  });

  /// 触摸默认：内侧 100 逻辑像素起滚，150 像素加速坡，60Hz 下每帧 4 至 132 像素。
  static const SelectionAutoScrollConfig touch = SelectionAutoScrollConfig(
    beltExtent: 100.0,
    speedRampExtent: 150.0,
    maxFrameDelta: 132.0,
    minFrameDelta: 4.0,
  );

  /// 鼠标默认：内侧 20 逻辑像素起滚，100 像素加速坡，60Hz 下每帧 5 至 1000 像素。
  static const SelectionAutoScrollConfig mouse = SelectionAutoScrollConfig(
    beltExtent: 20.0,
    speedRampExtent: 100.0,
    maxFrameDelta: 1000.0,
    minFrameDelta: 5.0,
  );

  /// 边缘感应带宽度（逻辑像素）：指针进入视口主轴两端 **内侧** 该距离即开始
  /// 自动滚动；越出视口后深度继续累计（继续加速直至封顶）。
  final double beltExtent;

  /// 加速斜坡长度（逻辑像素）：深度达到该值时到满速（曲线为二次 ease-in）。
  final double speedRampExtent;

  /// 满速（逻辑像素 / 帧，60fps 基准）。
  final double maxFrameDelta;

  /// 起步速度（逻辑像素 / 帧，60fps 基准）：刚越过感应带内边界即按此速度
  /// 滚动，曲线在 [minFrameDelta, maxFrameDelta] 区间内加速。默认 0（自定义
  /// 配置向后兼容；touch / mouse 预设有各自下限）。
  final double minFrameDelta;

  @override
  bool operator ==(Object other) {
    return other is SelectionAutoScrollConfig &&
        other.beltExtent == beltExtent &&
        other.speedRampExtent == speedRampExtent &&
        other.maxFrameDelta == maxFrameDelta &&
        other.minFrameDelta == minFrameDelta;
  }

  @override
  int get hashCode => Object.hash(beltExtent, speedRampExtent, maxFrameDelta, minFrameDelta);
}

const double _autoScrollEpsilon = 0.1;

/// 一次 tick 决定的滚动 target：目标 viewport 与本帧 delta。
class SelectionAutoScrollTarget {
  /// 创建。
  const SelectionAutoScrollTarget(this.viewport, this.frameDelta);

  /// 命中 viewport。
  final ScrollViewport viewport;

  /// 本帧滚动 delta（已经过加速）。
  final double frameDelta;
}

// ---- host 接口 --------------------------------------------------------------

/// [SelectionAutoScrollController] 需要 host 提供的窄接口。
///
/// 只暴露必要能力：拖动状态查询、参考 participant、Ticker 工厂、几何失效通知
/// 与 sync 回调（tick 之后 host 决定按 mode/handle 分派 sync focus/block/handle）。
abstract interface class SelectionAutoScrollHost {
  /// 当前 pointer kind；auto-scroll 用它挑鼠标 vs 触摸参数曲线。
  PointerDeviceKind? get activePointerKind;

  /// 当前 pointer state 是否为 dragging。
  bool get isPointerDragging;

  /// 当前是否处于 handle 拖动。
  bool get isHandleDragInProgress;

  /// 参考 participant：拿 focus → anchor → downParticipant 优先级。
  RenderObject? get referenceParticipantForAutoScroll;

  /// 拖动起点 participant（anchor 或 downParticipant）。
  RenderObject? get anchorParticipantForAutoScroll;

  /// selection root 本体（作为 ticker/hit-test 遍历起点与坐标空间）。
  RenderObject get autoScrollRoot;

  /// 创建 Ticker。
  Ticker createAutoScrollTicker(TickerCallback onTick);

  /// tick 结束（或滚动 offset 变化后）执行选区端点 sync。
  ///
  /// host 内部按 handle → block → focus 优先级分派。
  void syncSelectionAfterScrollDelta();

  /// 让 participant 几何缓存失效（滚动后 bounds 陈旧）。
  void invalidateParticipantGeometry();

  /// 当前选区是否走移动档 auto-scroll 参数曲线。
  bool get selectionUsesMobileAutoScroll;

  /// 是否为 touch/stylus 一类 pointer（handle 拖动等）。
  bool isTouchSelectionPointer(PointerDeviceKind kind);

  /// 生效的边缘自动滚动配置（touch / mouse 各一套，widget 参数可覆盖默认）。
  SelectionAutoScrollConfig autoScrollConfigFor({required bool touch});
}

// ---- controller -------------------------------------------------------------

/// 拖动到边缘的自动滚动控制器。
///
/// 主 file 只需三条协作路径：
///   - 拖动 move / handle move 时喂位置：`updateForDrag(globalPosition)`
///   - 停止 / 清理：`stop()` / `clearDragViewports()`
///   - dispose：`dispose()`
class SelectionAutoScrollController {
  /// 创建。
  SelectionAutoScrollController(this._host);

  final SelectionAutoScrollHost _host;

  /// 上次拖动的全局坐标（供 tick 复用；handle sync 也读这个）。
  Offset? lastDragGlobalPosition;

  /// pointer signal dispatch 时最近命中 viewport（wheel 场景）。
  ScrollViewport? lastDragHitViewport;

  /// 用于加速命中的候选 viewport 列表缓存。
  List<ScrollViewport>? candidatesCache;

  /// 当前监听 offset 变化的 viewport 集（用于滚动同步 focus）。
  final HashSet<ScrollViewport> dragScrollViewports = HashSet<ScrollViewport>.identity();

  /// 正在应用自动滚动 delta 的标记；防止 offset listener 回环触发。
  bool applyingSelectionAutoScroll = false;

  Ticker? _ticker;
  Duration? _lastAutoScrollTick;

  /// 拖动 move 时喂位置（同时更新 hit viewport 缓存 + 启动 ticker）。
  ///
  /// [activateAutoScroll] 为 false 时只记录位置 + 维护 viewport 缓存/监听集
  /// （滚动同步 focus、wheel 分派仍依赖这些），**不**启动边缘自动滚动 ticker
  /// ——触摸 body 拖选（长按/双击词选）禁用自动滚动（用户裁决 2026-07-13：
  /// 在边缘长按立即滚动体验差），仅 handle 拖动与鼠标拖选激活。
  void updateForDrag(Offset globalPosition, {bool activateAutoScroll = true}) {
    lastDragGlobalPosition = globalPosition;
    final hitViewport = _lastDragHitViewportFor(globalPosition);
    if (!identical(lastDragHitViewport, hitViewport)) {
      lastDragHitViewport = hitViewport;
      syncDragScrollViewports();
    }
    if (candidatesCache == null) syncDragScrollViewports();
    if (!activateAutoScroll) {
      stop();
      return;
    }
    final target = _autoScrollTargetFor(globalPosition);
    if (target == null) {
      stop();
      return;
    }

    final ticker = _ticker ??= _host.createAutoScrollTicker(_handleAutoScrollTick);
    if (!ticker.isActive) {
      _lastAutoScrollTick = Duration.zero;
      ticker.start();
    }
  }

  /// 同步 drag scroll viewport listeners 集合。
  ///
  /// 让 auto-scroll 候选 + 命中 viewport 都注册 offset listener，滚动时通过
  /// [_handleDragScrollOffsetChanged] 同步 focus。
  void syncDragScrollViewports() {
    if (!_host.isPointerDragging && !_host.isHandleDragInProgress) return;
    final autoScrollCandidates = _collectAutoScrollViewportCandidates();
    final next = HashSet<ScrollViewport>.identity()..addAll(autoScrollCandidates);
    final hitViewport = _lastDragHitViewportFor(lastDragGlobalPosition);
    if (hitViewport != null) next.add(hitViewport);
    for (final viewport in dragScrollViewports.toList(growable: false)) {
      if (next.contains(viewport)) continue;
      viewport.scrollOffsetListenable.removeListener(_handleDragScrollOffsetChanged);
      dragScrollViewports.remove(viewport);
    }
    for (final viewport in next) {
      if (dragScrollViewports.add(viewport)) {
        viewport.scrollOffsetListenable.addListener(_handleDragScrollOffsetChanged);
      }
    }
    candidatesCache = autoScrollCandidates;
  }

  /// 清空 drag scroll viewport listeners 集合（拖动结束 / clear selection 时调）。
  void clearDragScrollViewports() {
    for (final viewport in dragScrollViewports) {
      viewport.scrollOffsetListenable.removeListener(_handleDragScrollOffsetChanged);
    }
    dragScrollViewports.clear();
    lastDragHitViewport = null;
    candidatesCache = null;
  }

  /// pointer signal 分派到当前命中 viewport（wheel scroll）。
  /// 返回是否成功分派。
  bool dispatchPointerSignalToDragViewport(PointerSignalEvent event) {
    final viewport = _lastDragHitViewportFor(event.position);
    if (viewport == null || !viewport.dispatchSelectionPointerSignal(event)) return false;
    lastDragGlobalPosition = event.position;
    lastDragHitViewport = viewport;
    syncDragScrollViewports();
    return true;
  }

  /// 停止 ticker（tick 内检测到无需继续滚动时也会调）。
  void stop() {
    _ticker?.stop();
    _lastAutoScrollTick = null;
  }

  /// selection root dispose 时的清理。
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    _lastAutoScrollTick = null;
  }

  /// detach 时的清理（比 dispose 温和：只 stop，不 dispose ticker）。
  void detach() {
    _ticker?.stop();
    _lastAutoScrollTick = null;
  }

  /// viewport 滚动 offset 回调。
  ///
  /// 进入时先做一层"几何失效"，然后触发 sync（分派逻辑在 host）。
  void _handleDragScrollOffsetChanged() {
    if (applyingSelectionAutoScroll) return;
    // 任意 participant 滚动后 participant geometry 缓存立刻陈旧——子路径里
    // 大多数已经会 invalidate，这里入口再保一道，避免后续任何路径漏调时落到
    // 陈旧 bounds 上做命中。
    _host.invalidateParticipantGeometry();
    if (!_host.isHandleDragInProgress && !_host.isPointerDragging) return;
    _host.syncSelectionAfterScrollDelta();
  }

  void _handleAutoScrollTick(Duration elapsed) {
    final lastTick = _lastAutoScrollTick;
    _lastAutoScrollTick = elapsed;
    if (lastTick == null) return;

    final globalPosition = lastDragGlobalPosition;
    final pointerDragging = _host.isPointerDragging;
    final handleDragging = _host.isHandleDragInProgress;
    if ((!pointerDragging && !handleDragging) || globalPosition == null) {
      stop();
      return;
    }

    final target = _autoScrollTargetFor(globalPosition);
    if (target == null) {
      stop();
      return;
    }

    final seconds = (elapsed - lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    if (seconds <= 0.0) return;

    final double applied;
    applyingSelectionAutoScroll = true;
    try {
      applied = target.viewport.applySelectionAutoScrollDelta(
        target.frameDelta * seconds * SelectionAutoScrollMath.frameRate,
      );
    } finally {
      applyingSelectionAutoScroll = false;
    }
    if (applied.abs() <= _autoScrollEpsilon) {
      stop();
      return;
    }
    _host.syncSelectionAfterScrollDelta();
  }

  SelectionAutoScrollTarget? _autoScrollTargetFor(Offset globalPosition) {
    for (final viewport in _autoScrollViewportCandidates()) {
      if (!viewport.attached || !viewport.hasSize) continue;
      final frameDelta = _autoScrollFrameDeltaFor(viewport, globalPosition);
      if (frameDelta.abs() <= _autoScrollEpsilon) continue;
      if (!_canAutoScroll(viewport, frameDelta)) continue;
      return SelectionAutoScrollTarget(viewport, frameDelta);
    }
    return null;
  }

  List<ScrollViewport> _autoScrollViewportCandidates() {
    final cached = candidatesCache;
    if (cached != null) return cached;
    return _collectAutoScrollViewportCandidates();
  }

  List<ScrollViewport> _collectAutoScrollViewportCandidates() {
    final reference = _host.referenceParticipantForAutoScroll;
    final result = scrollAncestorsOf(reference);
    final origin = _host.anchorParticipantForAutoScroll;

    if (reference != null && origin != null && !identical(reference, origin)) {
      final originAncestors = HashSet<ScrollViewport>.identity()..addAll(scrollAncestorsOf(origin));
      result.removeWhere((viewport) => !originAncestors.contains(viewport));
    }

    if (result.isNotEmpty) return result;
    final fallback = scrollAncestorsOf(origin);
    if (fallback.isNotEmpty) return fallback;
    return scrollAncestorsOf(_host.autoScrollRoot.parent);
  }

  /// 沿父链收集所有 [ScrollViewport] ancestor。
  static List<ScrollViewport> scrollAncestorsOf(RenderObject? node) {
    final result = <ScrollViewport>[];
    final seen = HashSet<ScrollViewport>.identity();
    var current = node;
    while (current != null) {
      if (current is ScrollViewport && seen.add(current)) {
        result.add(current);
      }
      current = current.parent;
    }
    return result;
  }

  /// **T1c** — 拖动命中 viewport 探测（每 move 调用，热路径）。
  ///
  /// 优化两级：
  /// 1. **快路径**：上次命中的 [lastDragHitViewport] 仍 attached/hasSize 且点仍在其
  ///    局部 bounds 内 → 直接复用，跳过父链收集。稳态一整条拖动几乎全走这里。
  /// 2. **父链候选**：miss 时不再从 root 下行递归整棵子树；沿 host 的参考 /
  ///    锚点 participant 父链（[scrollAncestorsOf]）收集候选，取**最深**
  ///    （列表头，因为 scrollAncestorsOf 从近到远排序）包含该点的 viewport。
  ///    语义等价：选区拖动关心的 viewport 必然是拖动参考 participant 的祖先。
  /// 3. **兜底**：父链两参考都拿不到时保留一次全树遍历（极端场景，如 orderedParticipants
  ///    为空且 downParticipant 未记录）。
  ScrollViewport? _lastDragHitViewportFor(Offset? globalPosition) {
    if (globalPosition == null) return null;

    // 快路径：上次命中仍然可用。
    final last = lastDragHitViewport;
    if (last != null && last.attached && last.hasSize) {
      try {
        final local = last.globalToLocal(globalPosition);
        if ((Offset.zero & last.size).contains(local)) return last;
      } catch (_) {
        // fall through 到父链收集
      }
    }

    // 沿参考 / 锚点 participant 父链收集候选（选区拖动关心的 viewport 必为祖先）。
    final reference = _host.referenceParticipantForAutoScroll;
    final anchor = _host.anchorParticipantForAutoScroll;
    for (final viewport in scrollAncestorsOf(reference)) {
      if (_viewportContainsGlobalPoint(viewport, globalPosition)) return viewport;
    }
    if (anchor != null && !identical(anchor, reference)) {
      for (final viewport in scrollAncestorsOf(anchor)) {
        if (_viewportContainsGlobalPoint(viewport, globalPosition)) return viewport;
      }
    }

    // 兜底：父链两个参考都拿不到（极端场景）时保留旧的全树下行遍历。
    if (reference == null && anchor == null) {
      ScrollViewport? best;
      void visit(RenderObject node) {
        if (node is ScrollViewport && node.attached && node.hasSize) {
          try {
            final local = node.globalToLocal(globalPosition);
            if (node.contentViewportRect.contains(local)) best = node;
          } catch (_) {
            return;
          }
        }
        node.visitChildren(visit);
      }

      visit(_host.autoScrollRoot);
      return best;
    }
    return null;
  }

  static bool _viewportContainsGlobalPoint(ScrollViewport viewport, Offset globalPosition) {
    if (!viewport.attached || !viewport.hasSize) return false;
    try {
      final local = viewport.globalToLocal(globalPosition);
      return viewport.contentViewportRect.contains(local);
    } catch (_) {
      return false;
    }
  }

  double _autoScrollFrameDeltaFor(ScrollViewport viewport, Offset globalPosition) {
    final Offset local;
    try {
      local = viewport.globalToLocal(globalPosition);
    } catch (_) {
      return 0.0;
    }

    final bounds = viewport.contentViewportRect;
    final mainExtent = viewport.axis == Axis.vertical ? bounds.height : bounds.width;
    final crossExtent = viewport.axis == Axis.vertical ? bounds.width : bounds.height;
    if (mainExtent <= 0.0 || crossExtent <= 0.0) return 0.0;

    final main = viewport.axis == Axis.vertical ? local.dy - bounds.top : local.dx - bounds.left;
    final config = _autoScrollConfig;

    final depth = SelectionAutoScrollMath.edgeDepth(main, 0.0, mainExtent, config.beltExtent);
    return _scrollPositionFrameDeltaFor(
      viewport,
      SelectionAutoScrollMath.frameDelta(depth, config, epsilon: _autoScrollEpsilon),
    );
  }

  SelectionAutoScrollConfig get _autoScrollConfig =>
      _host.autoScrollConfigFor(touch: _host.selectionUsesMobileAutoScroll);

  double _scrollPositionFrameDeltaFor(ScrollViewport viewport, double visualFrameDelta) {
    return axisDirectionIsReversed(viewport.axisDirection) ? -visualFrameDelta : visualFrameDelta;
  }

  bool _canAutoScroll(ScrollViewport viewport, double frameDelta) {
    final position = viewport.position;
    if (!position.hasPixels || !position.hasContentDimensions) return false;
    if (frameDelta > 0.0) return position.pixels < position.maxScrollExtent - _autoScrollEpsilon;
    if (frameDelta < 0.0) return position.pixels > position.minScrollExtent + _autoScrollEpsilon;
    return false;
  }
}

/// 文档、编辑器和对象框选共用的滚动数学，不依赖参与者、RenderObject 或 ticker。
abstract final class SelectionAutoScrollMath {
  /// 配置中的每帧距离以 60Hz 为基准，宿主按实际帧间隔换算。
  static const double frameRate = 60.0;

  /// 指针越过边缘感应带的有符号深度；起边为负，末边为正，中间为零。
  static double edgeDepth(double point, double start, double end, double beltExtent) {
    final extent = math.max(end - start, 0.0);
    final belt = math.min(beltExtent, extent / 2.0);
    if (belt <= 0.0) return 0.0;
    final local = point - start;
    final double selectionPoint;
    if (local < belt) {
      selectionPoint = local - belt;
    } else if (local > extent - belt) {
      selectionPoint = local + belt;
    } else {
      return 0.0;
    }
    if (selectionPoint < 0.0) return selectionPoint;
    // 沿用长度为 1 的端点矩形，末边与起边保持原有命中合同。
    final revealEnd = selectionPoint + 1.0;
    return revealEnd > extent ? revealEnd - extent : 0.0;
  }

  /// 将深度映射为有起步下限的二次加速距离；epsilon 由宿主的边界容差决定。
  static double frameDelta(double depth, SelectionAutoScrollConfig config, {double epsilon = 0.0}) {
    final magnitude = depth.abs();
    if (magnitude <= epsilon) return 0.0;
    final t = (magnitude / math.max(config.speedRampExtent, 1.0)).clamp(0.0, 1.0);
    final min = math.min(config.minFrameDelta, config.maxFrameDelta);
    return depth.sign * (min + (config.maxFrameDelta - min) * t * t);
  }
}
