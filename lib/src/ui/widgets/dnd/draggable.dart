import 'dart:async' show unawaited;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_base/src/ui/cores/view/event/event.dart';
import 'package:flutter_base/src/ui/cores/view/view.dart';
import 'package:flutter_base/src/ui/cores/view/style/style.dart';
import 'drag_session.dart';

/// 数据拖拽源：把 [data] 拖给任意 [接收该类型的] `ElDropTarget<T>`。
///
/// ```dart
/// ElDraggable<String>(
///   data: 'card-1',
///   ghostBuilder: (c) => cardPreview,   // 跟手预览；context 延续主题与文字样式
///   child: card,
/// )
/// ```
///
/// - 手势走 ElEvent drag 全家（桌面即时拖；slop 由事件层统一）；child 若自带
///   drag 回调会与本组件的拖拽驱动竞争，避免叠用。
/// - 默认截取源元素真实画面作为跟手预览；[ghostBuilder] 可完整替换它，
///   [showGhost] 可显式关闭。预览挂 [rootOverlay] 选中的 [Overlay]
///   （官方 OverlayEntry、全程穿透）；无 host 时仅无预览，
///   数据投放不受影响。
/// - 会话期间源元素自动降低到 [draggingOpacity]，但不覆盖任何鼠标光标；
///   结束或取消后恢复。
/// - 单会话：已有拖放会话在途时本源的拖拽不承载数据。
class ElDraggable<T extends Object> extends StatefulWidget {
  /// 创建拖拽源。
  const ElDraggable({
    super.key,
    required this.data,
    required this.child,
    this.ghostBuilder,
    this.showGhost = true,
    this.draggingOpacity = 0.35,
    this.rootOverlay = false,
    this.ghostOffset = const Offset(12, 12),
    this.onDragStarted,
    this.onDragEnded,
  }) : assert(draggingOpacity >= 0 && draggingOpacity <= 1, 'draggingOpacity 必须位于 0..1。');

  /// 载荷（drop 侧按 `ElDropTarget<T>` 泛型匹配）。
  final T data;

  /// 拖拽源内容。
  final Widget child;

  /// 跟手预览构造器；null 时使用源元素的真实画面快照。
  final WidgetBuilder? ghostBuilder;

  /// 是否显示跟手预览；关闭后 [ghostBuilder] 也不会执行。
  final bool showGhost;

  /// 会话期间源元素的透明度，用于保留原位置并表达正在拖动。
  final double draggingOpacity;

  /// ghost 打开时请求的弹层挂载点类型。
  final bool rootOverlay;

  /// 预览相对指针的偏移。
  final Offset ghostOffset;

  /// 会话真正建立时回调（已有会话在途被拒时不触发）。
  final VoidCallback? onDragStarted;

  /// 会话结束回调：accepted = 是否被某个 target 接收。
  final void Function(bool accepted)? onDragEnded;

  @override
  State<ElDraggable<T>> createState() => _DraggableState<T>();
}

class _DraggableState<T extends Object> extends State<ElDraggable<T>> {
  final GlobalKey _snapshotBoundaryKey = GlobalKey(debugLabel: 'el-draggable-snapshot');

  /// 本源发起的会话是否在途（session 单例可能被别的源占用，只清自己的账）。
  bool _sessionMine = false;
  bool _disposing = false;
  bool _feedbackBuildScheduled = false;
  _DragSnapshotController? _snapshot;

  @override
  void deactivate() {
    if (_sessionMine) DndSession.instance.cancel();
    super.deactivate();
  }

  void _refreshFeedback() {
    if (_disposing || !mounted) return;
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      setState(() {});
      return;
    }
    // Render 摘挂可在祖先 build 中同步取消会话，状态立即结清，视觉重建等树稳定。
    if (_feedbackBuildScheduled) return;
    _feedbackBuildScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _feedbackBuildScheduled = false;
      if (!_disposing && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _disposing = true;
    if (_sessionMine) DndSession.instance.cancel();
    _snapshot?.dispose();
    _snapshot = null;
    super.dispose();
  }

  _DragSnapshotController? _ensureSnapshot() {
    if (!widget.showGhost || widget.ghostBuilder != null) return null;
    final existing = _snapshot;
    if (existing != null) return existing;
    final captureRender = _snapshotBoundaryKey.currentContext?.findRenderObject();
    final fallbackRender = context.findRenderObject();
    final render = captureRender is RenderBox && captureRender.attached && captureRender.hasSize
        ? captureRender
        : fallbackRender is RenderBox && fallbackRender.attached && fallbackRender.hasSize
        ? fallbackRender
        : null;
    if (render == null) return null;
    final snapshot = _DragSnapshotController(render.size);
    _snapshot = snapshot;
    if (captureRender is _RenderDragSnapshotBoundary) {
      unawaited(_captureSnapshot(captureRender, snapshot));
    }
    return snapshot;
  }

  Future<void> _captureSnapshot(_RenderDragSnapshotBoundary render, _DragSnapshotController snapshot) async {
    try {
      final image = await render.toImage(pixelRatio: View.of(context).devicePixelRatio);
      snapshot.publish(image);
    } catch (_) {
      // render 正好卸载或拖拽过快时保留即时占位反馈，数据会话不受截图失败影响。
    }
  }

  void _prepareSnapshot(ElEventDetails _) => _ensureSnapshot();

  void _releaseUnusedSnapshot(ElEventDetails _) {
    if (_sessionMine) return;
    final unused = _snapshot;
    _snapshot = null;
    unused?.dispose();
  }

  void _onStart(ElEventDetails e) {
    e.eagerGesture(cancelSelfTap: true);
    final snapshot = _ensureSnapshot();
    final customGhost = widget.ghostBuilder;
    final WidgetBuilder? ghostBuilder = !widget.showGhost
        ? null
        : customGhost ?? (snapshot == null ? null : (_) => _DefaultDragGhost(snapshot: snapshot));
    final started = DndSession.instance.start(
      data: widget.data,
      context: context,
      globalPosition: e.globalPosition,
      ghostBuilder: ghostBuilder,
      rootOverlay: widget.rootOverlay,
      ghostOffset: widget.ghostOffset,
      onEnded: (accepted) {
        _sessionMine = false;
        final completedSnapshot = _snapshot;
        _snapshot = null;
        _refreshFeedback();
        widget.onDragEnded?.call(accepted);
        SchedulerBinding.instance.addPostFrameCallback((_) => completedSnapshot?.dispose());
      },
    );
    if (started) {
      _sessionMine = true;
      if (mounted) setState(() {});
      widget.onDragStarted?.call();
      if (_sessionMine) DndSession.instance.update(e.globalPosition);
    } else {
      final unusedSnapshot = _snapshot;
      _snapshot = null;
      unusedSnapshot?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElView(
      style: ElStyle(
        opacity: _sessionMine ? widget.draggingOpacity : 1.0,
        transitions: const [.field(.opacity, Duration(milliseconds: 100), Curves.easeOutCubic)],
      ),
      event: ElEvent(
        onPointerUp: _releaseUnusedSnapshot,
        onPointerCancel: _releaseUnusedSnapshot,
        onDragDown: _prepareSnapshot,
        onDragStart: _onStart,
        onDragUpdate: (e) {
          if (_sessionMine) DndSession.instance.update(e.globalPosition);
        },
        onDragEnd: (e) {
          if (_sessionMine) DndSession.instance.end(e.globalPosition);
        },
        onDragCancel: (e) {
          if (_sessionMine) DndSession.instance.cancel();
        },
      ),
      child: widget.showGhost && widget.ghostBuilder == null
          ? _DragSnapshotBoundary(key: _snapshotBoundaryKey, child: widget.child)
          : widget.child,
    );
  }
}

class _DragSnapshotController extends ChangeNotifier {
  _DragSnapshotController(this.size);

  final Size size;
  ui.Image? image;
  bool _disposed = false;

  void publish(ui.Image next) {
    if (_disposed) {
      next.dispose();
      return;
    }
    image?.dispose();
    image = next;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    image?.dispose();
    image = null;
    super.dispose();
  }
}

class _DefaultDragGhost extends StatefulWidget {
  const _DefaultDragGhost({required this.snapshot});

  final _DragSnapshotController snapshot;

  @override
  State<_DefaultDragGhost> createState() => _DefaultDragGhostState();
}

class _DefaultDragGhostState extends State<_DefaultDragGhost> {
  @override
  void initState() {
    super.initState();
    widget.snapshot.addListener(_handleSnapshotChanged);
  }

  @override
  void didUpdateWidget(covariant _DefaultDragGhost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.snapshot, widget.snapshot)) return;
    oldWidget.snapshot.removeListener(_handleSnapshotChanged);
    widget.snapshot.addListener(_handleSnapshotChanged);
  }

  @override
  void dispose() {
    widget.snapshot.removeListener(_handleSnapshotChanged);
    super.dispose();
  }

  void _handleSnapshotChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    return ElView(
      style: ElStyle(
        width: snapshot.size.width,
        height: snapshot.size.height,
        opacity: 0.94,
        bgColor: snapshot.image == null ? const Color(0x22ffffff) : null,
        border: snapshot.image == null ? .all(color: const Color(0x44808080)) : null,
        borderRadius: .all(Radius.circular(3)),
        boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 10, offset: Offset(0, 4))],
        transform: .scale(1.015),
        starting: const ElStyle(opacity: 0.0, transform: .scale(0.98)),
        transitions: const [
          .field(.opacity, Duration(milliseconds: 90), Curves.easeOutCubic),
          .field(.transform, Duration(milliseconds: 90), Curves.easeOutCubic),
        ],
      ),
      child: snapshot.image == null ? null : _DragSnapshotImage(image: snapshot.image!),
    );
  }
}

class _DragSnapshotBoundary extends SingleChildRenderObjectWidget {
  const _DragSnapshotBoundary({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderDragSnapshotBoundary();
}

class _RenderDragSnapshotBoundary extends RenderRepaintBoundary {}

class _DragSnapshotImage extends LeafRenderObjectWidget {
  const _DragSnapshotImage({required this.image});

  final ui.Image image;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderDragSnapshotImage(image);

  @override
  void updateRenderObject(BuildContext context, _RenderDragSnapshotImage renderObject) {
    renderObject.image = image;
  }
}

class _RenderDragSnapshotImage extends RenderBox {
  _RenderDragSnapshotImage(this._image);

  ui.Image _image;

  set image(ui.Image value) {
    if (identical(_image, value)) return;
    _image = value;
    markNeedsPaint();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.smallest;

  @override
  void performLayout() => size = constraints.smallest;

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.drawImageRect(
      _image,
      Rect.fromLTWH(0, 0, _image.width.toDouble(), _image.height.toDouble()),
      offset & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}
