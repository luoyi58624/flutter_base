import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'ghost_follower.dart';

/// drop target 的会话侧绑定（[ElDropTarget] state 经 MetaData 挂进命中路径）。
///
/// 命中机制对齐 Flutter DragTarget：target 在内容外包
/// `MetaData(behavior: translucent)`，拖拽指针 hitTest 路径**由深到浅**扫到的
/// 首个类型匹配 binding 即当前目标——嵌套最深优先、被上层内容遮挡时不误中。
class DropTargetBinding {
  /// 创建绑定。
  DropTargetBinding({
    required this.matches,
    required this.onEnter,
    required this.onLeave,
    required this.onMove,
    required this.onDrop,
  });

  /// 载荷类型是否归本 target 管（泛型 `data is T` 判定；canAccept 语义在
  /// target 侧另行体现为 candidate.accepted / 拒收 drop）。
  final bool Function(Object? data) matches;

  /// 拖拽进入本 target。
  final void Function(Object? data) onEnter;

  /// 拖拽离开本 target（含会话取消 / drop 后清理）。
  final void Function(Object? data) onLeave;

  /// 拖拽在本 target 上移动。
  final void Function(Object? data, Offset globalPosition) onMove;

  /// 松手投放（target 侧自行判定 accepted 后派发业务回调）。返回是否接收
  /// （false = canAccept 拒收，源侧 onDragEnded(false)）。
  final bool Function(Object? data, Offset globalPosition) onDrop;
}

/// 全局拖放会话（单例）：一次拖拽的载荷持有、ghost 预览层、目标命中与
/// enter / leave / move / drop 派发。
///
/// 单会话语义：同一时刻只有一次数据拖拽（第二个 [start] 在会话进行中是
/// no-op 并返回 false）；手势层（ElEvent drag driver）本就按 pointer 独占，
/// 常规交互不会撞。
class DndSession {
  DndSession._();

  /// 进程单例。
  static final DndSession instance = DndSession._();

  bool _active = false;
  bool _terminalCallbacksActive = false;

  /// 当前是否有进行中的拖放会话。
  bool get isActive => _active;

  Object? _data;

  /// 当前载荷（无会话时 null）。
  Object? get data => _active ? _data : null;

  DropTargetBinding? _hovered;
  void Function(bool accepted)? _onEnded;
  int _viewId = 0;
  OverlayEntry? _ghostEntry;

  /// ghost 跟手位置通知（global 坐标 + ghostOffset 已加）。ghost 层监听。
  final ValueNotifier<Offset> ghostPosition = ValueNotifier<Offset>(Offset.zero);

  Offset _ghostOffset = Offset.zero;

  /// 发起会话（[ElDraggable] 的 onDragStart）。返回 false = 已有会话在途，
  /// 本次拖拽不承载数据。
  ///
  /// [context]：ghost 的 host 定位点 + 级联捕获点（ghost 内容延续触发处
  /// token / 明暗）。[ghostBuilder] null 或树上无 host 时无 ghost，纯数据拖放
  /// 照常工作。[rootOverlay] 选择 ghost 的 host；ghost 始终指针透明且
  /// 不创建选区窗口。
  bool start({
    required Object? data,
    required BuildContext context,
    required Offset globalPosition,
    WidgetBuilder? ghostBuilder,
    bool rootOverlay = false,
    Offset ghostOffset = Offset.zero,
    void Function(bool accepted)? onEnded,
  }) {
    if (_active || _terminalCallbacksActive) return false;
    _active = true;
    _data = data;
    _onEnded = onEnded;
    _ghostOffset = ghostOffset;
    _viewId = View.of(context).viewId;
    ghostPosition.value = globalPosition + ghostOffset;
    if (ghostBuilder != null) {
      final overlay = Overlay.maybeOf(context, rootOverlay: rootOverlay);
      assert(() {
        if (overlay == null) {
          debugPrint('el_ui: ElDraggable 声明了 ghostBuilder 但树上无 Overlay，本次拖拽无预览（数据投放不受影响）。');
        }
        return true;
      }());
      if (overlay != null) {
        final themes = InheritedTheme.capture(from: context, to: overlay.context);
        final entry = OverlayEntry(
          builder: (c) => Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: themes.wrap(
                    GhostFollower(
                      source: context,
                      child: Builder(builder: ghostBuilder),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        _ghostEntry = entry;
        overlay.insert(entry);
      }
    }
    return true;
  }

  /// 指针移动（[ElDraggable] 的 onDragUpdate）。
  void update(Offset globalPosition) {
    if (!_active) return;
    ghostPosition.value = globalPosition + _ghostOffset;
    _dispatchHit(globalPosition);
  }

  /// 松手投放（[ElDraggable] 的 onDragEnd）。
  void end(Offset globalPosition) {
    if (!_active) return;
    _dispatchHit(globalPosition);
    if (!_active) return;
    final data = _data;
    final hovered = _hovered;
    final onEnded = _onEnded;
    _teardown();
    var accepted = false;
    _terminalCallbacksActive = true;
    try {
      try {
        if (hovered != null) accepted = hovered.onDrop(data, globalPosition);
      } finally {
        hovered?.onLeave(data);
      }
    } finally {
      _terminalCallbacksActive = false;
      onEnded?.call(accepted);
    }
  }

  /// 会话取消（手势 cancel / 源卸载）。
  void cancel() {
    if (!_active) return;
    final data = _data;
    final hovered = _hovered;
    final onEnded = _onEnded;
    _teardown();
    _terminalCallbacksActive = true;
    try {
      hovered?.onLeave(data);
    } finally {
      _terminalCallbacksActive = false;
      onEnded?.call(false);
    }
  }

  void _teardown() {
    final ghost = _ghostEntry;
    _ghostEntry = null;
    _active = false;
    _data = null;
    _hovered = null;
    _onEnded = null;
    _autoScrollViewport = null;
    _stopAutoScroll();
    ghost?.remove();
    ghost?.dispose();
  }

  // --- 边缘自动滚动 ---------------------------------------------------------

  /// 边缘带宽度（指针距滚动视口主轴边缘小于该值时开始自动滚）。
  static const double _autoScrollEdgeBand = 48.0;

  /// 满速（px/s，指针贴边时）；速度按深入比例平方渐升（对齐选区自动滚的
  /// 曲线加速手感）。
  static const double _autoScrollMaxSpeed = 800.0;

  RenderViewportBase? _autoScrollViewport;
  Offset _lastGlobalPosition = Offset.zero;
  Ticker? _autoScrollTicker;
  Duration _lastAutoScrollTick = Duration.zero;

  void _syncAutoScroll(HitTestResult result, Offset globalPosition) {
    _lastGlobalPosition = globalPosition;
    RenderViewportBase? viewport;
    for (final entry in result.path) {
      final target = entry.target;
      if (target is! RenderObject) continue;
      viewport = _scrollViewportOf(target);
      if (viewport != null) break;
    }
    _autoScrollViewport = viewport;
    // 只在指针落进边缘带时起表：带外/无视口不空转（拖住不动时不逼帧）。
    if (viewport == null || _edgeRatio(viewport) == 0) {
      _stopAutoScroll();
      return;
    }
    _autoScrollTicker ??= Ticker(_autoScrollTick);
    if (!_autoScrollTicker!.isActive) {
      _lastAutoScrollTick = Duration.zero;
      _autoScrollTicker!.start();
    }
  }

  /// 命中目标所在的纵向滚动视口；横向自动滚暂无真实场景。
  ///
  /// 官方视口自身不参与命中，指针落在内容上时沿父链查找；落在空白处时最深命中是
  /// 直接包住视口的代理节点（如 ElScrollView 的指针监听层），需要检查它的子节点。
  static RenderViewportBase? _scrollViewportOf(RenderObject target) {
    RenderObject? node = target is RenderProxyBox ? target.child : null;
    if (node is! RenderViewportBase) node = target;
    while (node != null) {
      if (node is RenderViewportBase && node.axis == Axis.vertical && node.offset is ScrollPosition) return node;
      node = node.parent;
    }
    return null;
  }

  /// 指针在 [viewport] 主轴边缘带内的深入比例（-1..1，负 = 顶边带；0 = 带外）。
  double _edgeRatio(RenderViewportBase viewport) {
    if (!viewport.attached || !viewport.hasSize) return 0;
    final rect = MatrixUtils.transformRect(viewport.getTransformTo(null), Offset.zero & viewport.size);
    final y = _lastGlobalPosition.dy;
    if (y < rect.top + _autoScrollEdgeBand) {
      return -(1 - ((y - rect.top) / _autoScrollEdgeBand)).clamp(0.0, 1.0);
    }
    if (y > rect.bottom - _autoScrollEdgeBand) {
      return (1 - ((rect.bottom - y) / _autoScrollEdgeBand)).clamp(0.0, 1.0);
    }
    return 0;
  }

  void _stopAutoScroll() {
    _autoScrollTicker?.stop();
    _lastAutoScrollTick = Duration.zero;
  }

  /// 每帧：指针在视口主轴（垂直）边缘带内 → 按深入比例平方施加滚动增量，
  /// 直接驱动官方视口的 [ScrollPosition] 并钳制在正文范围内。
  void _autoScrollTick(Duration elapsed) {
    final viewport = _autoScrollViewport;
    if (!_active || viewport == null || !viewport.attached || !viewport.hasSize) {
      _stopAutoScroll();
      return;
    }
    final dt = _lastAutoScrollTick == Duration.zero ? Duration.zero : elapsed - _lastAutoScrollTick;
    _lastAutoScrollTick = elapsed;
    if (dt == Duration.zero) return;

    final ratio = _edgeRatio(viewport);
    if (ratio == 0) {
      _stopAutoScroll();
      return;
    }
    final delta = _autoScrollMaxSpeed * ratio * ratio.abs() * dt.inMicroseconds / 1e6;
    if (delta.abs() < 0.01) return;
    if (_applyAutoScroll(viewport, delta) == 0) {
      // 滚到头：停表（指针再动会经 update → sync 重新起表）。
      _stopAutoScroll();
      return;
    }
    // 滚动改变了 target 与指针的相对位置：立即重派发命中（enter/leave 跟手）。
    _dispatchHit(_lastGlobalPosition);
  }

  /// 按屏幕方向的增量滚动 [viewport]，返回实际移动的像素。
  double _applyAutoScroll(RenderViewportBase viewport, double delta) {
    final position = viewport.offset as ScrollPosition;
    if (!position.hasPixels || !position.hasContentDimensions) return 0;
    final pixelDelta = axisDirectionIsReversed(viewport.axisDirection) ? -delta : delta;
    final target = (position.pixels + pixelDelta).clamp(position.minScrollExtent, position.maxScrollExtent);
    final applied = target - position.pixels;
    if (applied != 0) position.jumpTo(target);
    return applied;
  }

  /// 命中派发：hitTest 路径由深到浅找首个类型匹配的 target 标记，翻转时
  /// leave → enter，停留时 move。ghost 层声明 `pointerEvents: none`，不挡命中。
  void _dispatchHit(Offset globalPosition) {
    try {
      final result = HitTestResult();
      RendererBinding.instance.hitTestInView(result, globalPosition, _viewId);
      DropTargetBinding? hit;
      for (final entry in result.path) {
        final target = entry.target;
        if (target is RenderMetaData) {
          final meta = target.metaData;
          if (meta is DropTargetBinding && meta.matches(_data)) {
            hit = meta;
            break;
          }
        }
      }
      if (!identical(hit, _hovered)) {
        final previous = _hovered;
        _hovered = null;
        previous?.onLeave(_data);
        if (!_active) return;
        _hovered = hit;
        hit?.onEnter(_data);
        if (!_active || !identical(_hovered, hit)) return;
      }
      hit?.onMove(_data, globalPosition);
      if (!_active) return;
      _syncAutoScroll(result, globalPosition);
    } catch (_) {
      cancel();
      rethrow;
    }
  }
}
