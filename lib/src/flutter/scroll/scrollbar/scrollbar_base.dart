import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'
    show
        GestureBinding,
        HitTestResult,
        PointerCancelEvent,
        PointerDeviceKind,
        PointerDownEvent,
        PointerEnterEvent,
        PointerEvent,
        PointerExitEvent,
        PointerHoverEvent,
        PointerMoveEvent,
        PointerRemovedEvent,
        PointerSignalEvent,
        PointerUpEvent,
        VelocityTracker,
        kPrimaryButton,
        kTouchSlop;
import 'package:flutter/rendering.dart'
    show
        BoxHitTestEntry,
        BoxHitTestResult,
        ContainerBoxParentData,
        ContainerRenderObjectMixin,
        LayerHandle,
        PipelineOwner,
        RenderBox,
        RenderBoxContainerDefaultsMixin,
        RenderObject,
        RenderObjectWithChildMixin,
        RenderObjectVisitor,
        RenderProxyBox,
        TransformLayer;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart';

import '../../views/layout/stack/stack_view.dart' show ElPositioned;
import '../../views/view/event/dispatcher.dart' show DragPointerLock;
import '../../views/view/event/event.dart';
import '../../views/view/render/hit_bounds.dart';
import '../../views/view/semantics/semantics.dart';
import '../../views/view/style/style.dart';
import '../../views/view/view.dart';

/// 单轴滚动条读取的指标及发送给宿主的交互命令。
abstract class ElScrollbarAxisDetails {
  /// 当前指标所属的轴。
  Axis get axis;

  /// position 使用的轴方向。
  AxisDirection get axisDirection;

  /// 可滚动像素的下界。
  double get minScrollExtent;

  /// 可滚动像素的上界。
  double get maxScrollExtent;

  /// 当前真实滚动像素。
  double get pixels;

  /// 当前轴的正文视口长度。
  double get viewportExtent;

  /// position 是否处于滚动活动中。
  bool get isScrolling;

  /// 当前轴是否存在可滚动范围。
  bool get isScrollable;

  /// 视觉首尾是否与像素增长方向相反。
  bool get isReversed;

  /// 当前像素在滚动范围内的逻辑分数。
  double get fraction;

  /// 按轴反转后的滑块视觉分数。
  double get visualFraction;

  /// 是否还能向视觉首端滚动。
  bool get canScrollLeading;

  /// 是否还能向视觉尾端滚动。
  bool get canScrollTrailing;

  /// 将像素转换为逻辑分数。
  double fractionForPixels(double pixels);

  /// 将逻辑分数转换为像素。
  double pixelsForFraction(double fraction);

  /// 按方向滚动一个行步长。
  void scrollByLine({required bool forward});

  /// 按方向滚动一个页步长。
  void scrollByPage({required bool forward});

  /// 在当前像素基础上滚动指定增量。
  void scrollByPixels(double delta);

  /// 跳转到指定像素。
  void jumpToPixels(double pixels);

  /// 使用指定动画滚动到目标像素。
  Future<void> animateToPixels(double pixels, {required Duration duration, Curve curve = Curves.easeOut});

  /// 跳转到指定逻辑分数。
  void jumpToFraction(double fraction);

  /// 开始滑块拖拽并接管当前滚动活动。
  void beginThumbDrag();

  /// 更新拖拽目标的视觉分数。
  void updateThumbDrag(double fraction);

  /// 释放滑块及其持有的交互资源。
  void endThumbDrag();

  /// 取消当前滑块交互。
  void cancelInteraction();
}

/// [ElScrollbar] 使用的宿主状态与交互入口。
abstract class ElScrollbarDetails implements Listenable {
  /// 读取指定轴的指标；该轴未启用时为 null。
  ElScrollbarAxisDetails? operator [](Axis axis);

  /// 把指针信号送回所属视口的平滑滚动、嵌套协商和选区输入管线。
  bool dispatchPointerSignal(PointerSignalEvent event);
}

/// 滚动条的平台外观与交互策略，条带及 corner 由视口直接挂载。
abstract class ElScrollbar {
  /// 创建可覆写平台策略的滚动条。
  const ElScrollbar();

  /// 返回滚动条在宿主边缘的官方方向。
  ScrollbarOrientation resolveOrientation(BuildContext context, Axis axis) {
    return axis == Axis.vertical ? ScrollbarOrientation.right : ScrollbarOrientation.bottom;
  }

  /// 为占位式滚动条预留的交叉轴长度。
  double resolveInsetExtent(BuildContext context, Axis axis) => 0.0;

  /// 返回滚动条视觉动画参数。
  AnimationStyle resolveAnimationStyle(BuildContext context) {
    return const AnimationStyle(duration: Duration(milliseconds: 160), curve: Curves.easeOut);
  }

  /// 是否始终显示条带。
  bool resolveAlwaysVisible(BuildContext context, ElScrollbarAxisDetails axis) => false;

  /// 是否允许滑块拖拽与轨道交互。
  bool resolveInteractive(BuildContext context, ElScrollbarAxisDetails axis) => true;

  /// 点击轨道时是否滚动到对应位置。
  bool resolveTrackTapJumps(BuildContext context, ElScrollbarAxisDetails axis) => true;

  /// 是否将整根轨道作为悬停区域。
  bool resolveHoverOnEntireTrack(BuildContext context, ElScrollbarAxisDetails axis) => true;

  /// 按住滑块时是否触发触觉反馈。
  bool resolveHapticOnThumbPress(BuildContext context, ElScrollbarAxisDetails axis) => false;

  /// 滑块是否沿交叉轴居中。
  bool resolveCenterThumb(BuildContext context, ElScrollbarAxisDetails axis) => false;

  /// 按悬停与拖拽状态解析滑块厚度。
  double resolveThumbThickness(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool hovered,
    required bool dragging,
  });

  /// 返回各交互状态需要的最大滑块厚度。
  double resolveMaximumThumbThickness(BuildContext context, ElScrollbarAxisDetails axis) {
    return math.max(
      resolveThumbThickness(context, axis, hovered: false, dragging: false),
      math.max(
        resolveThumbThickness(context, axis, hovered: true, dragging: false),
        resolveThumbThickness(context, axis, hovered: true, dragging: true),
      ),
    );
  }

  /// 返回条带的实际交互宽度。
  double resolveInteractiveThickness(BuildContext context, ElScrollbarAxisDetails axis) {
    return resolveMaximumThumbThickness(context, axis);
  }

  /// 正常滚动范围内的最小滑块长度。
  double resolveMinThumbExtent(BuildContext context, ElScrollbarAxisDetails axis) => 18.0;

  /// 越界压缩时的最小滑块长度；null 沿用普通最小值。
  double? resolveMinOverscrollThumbExtent(BuildContext context, ElScrollbarAxisDetails axis) => null;

  /// 悬浮条带距视口交叉轴边缘的间距。
  double resolveEdgeMargin(BuildContext context, ElScrollbarAxisDetails axis) => 0.0;

  /// 条带主轴两端的常规间距。
  double resolveMainAxisMargin(BuildContext context, ElScrollbarAxisDetails axis) => 0.0;

  /// 条带主轴**首端**的额外缩进（横条 = 左端、纵条 = 顶端），叠加在
  /// [resolveMainAxisMargin] 之上；默认 0。视口边缘带被 fixed 成员（如代码
  /// 预览的行号列、表格左冻结列）占据时，用它把条带起点推到固定带之后，
  /// 轨道与拖拽映射按缩短后的条带自适应。
  double resolveMainAxisLeadingInset(BuildContext context, ElScrollbarAxisDetails axis) => 0.0;

  /// 停止交互后等待多久开始淡出。
  Duration resolveFadeDelay(BuildContext context, ElScrollbarAxisDetails axis) {
    return const Duration(milliseconds: 1000);
  }

  /// 条带淡入淡出的时长。
  Duration resolveFadeDuration(BuildContext context, ElScrollbarAxisDetails axis) {
    return resolveAnimationStyle(context).duration ?? const Duration(milliseconds: 160);
  }

  /// 进入滑块按住状态所需的持续时间。
  Duration resolvePressDuration(BuildContext context, ElScrollbarAxisDetails axis) => Duration.zero;

  /// 主轴首端按钮长度；零表示不创建按钮。
  double resolveLeadingButtonExtent(BuildContext context, ElScrollbarAxisDetails axis) => 0.0;

  /// 主轴尾端按钮长度；零表示不创建按钮。
  double resolveTrailingButtonExtent(BuildContext context, ElScrollbarAxisDetails axis) => 0.0;

  /// 端点已无法继续滚动时，首尾按钮是否仍保留点击与按压反馈。
  bool resolveButtonInteractiveAtBoundary(BuildContext context, ElScrollbarAxisDetails axis, {required bool forward}) =>
      false;

  /// 按钮单次滚动动画的时长。
  Duration resolveButtonAnimateDuration(BuildContext context, ElScrollbarAxisDetails axis) {
    return const Duration(milliseconds: 150);
  }

  /// 长按按钮后首次重复滚动的等待时间。
  Duration resolveButtonRepeatDelay(BuildContext context, ElScrollbarAxisDetails axis) {
    return const Duration(milliseconds: 400);
  }

  /// 长按按钮的重复滚动间隔。
  Duration resolveButtonRepeatInterval(BuildContext context, ElScrollbarAxisDetails axis) {
    return const Duration(milliseconds: 50);
  }

  /// 返回按钮单次滚动的有符号像素增量。
  double resolveButtonLineDelta(BuildContext context, ElScrollbarAxisDetails axis, {required bool forward}) {
    final direction = (forward ? 1.0 : -1.0) * (axis.isReversed ? -1.0 : 1.0);
    return (axis.viewportExtent * 0.1).clamp(16.0, 48.0) * direction;
  }

  /// 返回首尾按钮的无障碍说明。
  String resolveButtonSemanticsLabel(BuildContext context, ElScrollbarAxisDetails axis, {required bool forward}) {
    if (axis.axis == Axis.vertical) return forward ? 'Scroll down' : 'Scroll up';
    return forward ? 'Scroll right' : 'Scroll left';
  }

  /// 返回内部轴条带的稳定键。
  Key resolveAxisKey(Axis axis) => ValueKey<String>('el-scrollbar-strip-${axis.name}');

  /// 构建整根条带的背景；null 表示透明。
  Widget? buildAxisBackground(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool visible,
    required bool hovered,
    required bool dragging,
  }) => null;

  /// 构建滑块下方的轨道外观。
  Widget? buildTrack(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool visible,
    required bool hovered,
    required bool dragging,
  }) => null;

  /// 构建当前交互状态下的滑块外观。
  Widget buildThumb(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool visible,
    required bool hovered,
    required bool dragging,
  });

  /// 构建主轴首端按钮外观。
  Widget? buildLeadingButton(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool enabled,
    required bool pressed,
  }) => null;

  /// 构建主轴尾端按钮外观。
  Widget? buildTrailingButton(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool enabled,
    required bool pressed,
  }) => null;

  /// 构建两轴条带相交处的角块。
  Widget? buildCorner(BuildContext context, ElScrollbarDetails details) => null;

  /// 滑块开始拖拽时通知平台策略。
  void onThumbDragStart(ElScrollbarAxisDetails axis) {}

  /// 滑块结束拖拽时通知平台策略。
  void onThumbDragEnd(ElScrollbarAxisDetails axis) {}

  /// 首尾按钮进入按住状态时通知平台策略。
  void onButtonPressStart(ElScrollbarAxisDetails axis, {required bool forward}) {}

  /// 首尾按钮结束按住状态时通知平台策略。
  void onButtonPressEnd(ElScrollbarAxisDetails axis, {required bool forward}) {}

  /// 判断是否为桌面交互平台。
  bool isDesktopPlatform(TargetPlatform platform) {
    return platform == TargetPlatform.windows || platform == TargetPlatform.macOS || platform == TargetPlatform.linux;
  }

  bool _isLeading(Axis axis, ScrollbarOrientation orientation) {
    assert(
      axis == Axis.vertical
          ? orientation == ScrollbarOrientation.left || orientation == ScrollbarOrientation.right
          : orientation == ScrollbarOrientation.top || orientation == ScrollbarOrientation.bottom,
      '$orientation does not match $axis',
    );
    return orientation == ScrollbarOrientation.left || orientation == ScrollbarOrientation.top;
  }

  /// 视口内层序：条带与业务成员共享同一视口 stacking context，不再跨层提升。
  int get zIndex => 10;

  /// 构建直接挂入滚动视口的轴条带和 corner，不包裹正文。
  List<Widget> buildChildren(BuildContext context, ElScrollbarDetails details) {
    final verticalInsetExtent = resolveInsetExtent(context, Axis.vertical);
    final horizontalInsetExtent = resolveInsetExtent(context, Axis.horizontal);
    final vertical = details[Axis.vertical];
    final horizontal = details[Axis.horizontal];
    final verticalInset = verticalInsetExtent > 0.0;
    final horizontalInset = horizontalInsetExtent > 0.0;
    final children = <Widget>[];

    double verticalCrossExtent = 0.0;
    double horizontalCrossExtent = 0.0;
    if (vertical != null) {
      verticalCrossExtent = verticalInset
          ? verticalInsetExtent
          : math.max(resolveMaximumThumbThickness(context, vertical), resolveInteractiveThickness(context, vertical));
    }
    if (horizontal != null) {
      horizontalCrossExtent = horizontalInset
          ? horizontalInsetExtent
          : math.max(
              resolveMaximumThumbThickness(context, horizontal),
              resolveInteractiveThickness(context, horizontal),
            );
    }

    if (vertical != null) {
      final orientation = resolveOrientation(context, Axis.vertical);
      final leading = _isLeading(Axis.vertical, orientation);
      final edgeMargin = verticalInset ? 0.0 : resolveEdgeMargin(context, vertical);
      final mainMargin = resolveMainAxisMargin(context, vertical);
      final cornerInset = horizontal != null
          ? horizontalCrossExtent +
                (!horizontalInset
                    ? resolveEdgeMargin(context, horizontal) + resolveMainAxisMargin(context, horizontal)
                    : 0.0)
          : mainMargin;
      children.add(
        ElPositioned(
          zIndex: zIndex,
          key: resolveAxisKey(Axis.vertical),
          left: leading ? edgeMargin : null,
          right: leading ? null : edgeMargin,
          top: mainMargin + resolveMainAxisLeadingInset(context, vertical),
          bottom: cornerInset,
          width: verticalCrossExtent,
          child: _ScrollbarScrollableGate(
            active: vertical.isScrollable,
            child: _ScrollbarAxis(scrollbar: this, details: details, axis: vertical),
          ),
        ),
      );
    }

    if (horizontal != null) {
      final orientation = resolveOrientation(context, Axis.horizontal);
      final leading = _isLeading(Axis.horizontal, orientation);
      final edgeMargin = horizontalInset ? 0.0 : resolveEdgeMargin(context, horizontal);
      final mainMargin = resolveMainAxisMargin(context, horizontal);
      final cornerInset = vertical != null
          ? verticalCrossExtent +
                (!verticalInset ? resolveEdgeMargin(context, vertical) + resolveMainAxisMargin(context, vertical) : 0.0)
          : mainMargin;
      children.add(
        ElPositioned(
          zIndex: zIndex,
          key: resolveAxisKey(Axis.horizontal),
          left: mainMargin + resolveMainAxisLeadingInset(context, horizontal),
          right: cornerInset,
          top: leading ? edgeMargin : null,
          bottom: leading ? null : edgeMargin,
          height: horizontalCrossExtent,
          child: _ScrollbarScrollableGate(
            active: horizontal.isScrollable,
            child: _ScrollbarAxis(scrollbar: this, details: details, axis: horizontal),
          ),
        ),
      );
    }

    if (vertical != null && horizontal != null) {
      final corner = buildCorner(context, details);
      if (corner != null) {
        final verticalLeading = _isLeading(Axis.vertical, resolveOrientation(context, Axis.vertical));
        final horizontalLeading = _isLeading(Axis.horizontal, resolveOrientation(context, Axis.horizontal));
        children.add(
          ElPositioned(
            zIndex: zIndex,
            left: verticalLeading ? 0.0 : null,
            right: verticalLeading ? null : 0.0,
            top: horizontalLeading ? 0.0 : null,
            bottom: horizontalLeading ? null : 0.0,
            width: verticalCrossExtent,
            height: horizontalCrossExtent,
            child: _ScrollbarScrollableGate(
              active: vertical.isScrollable && horizontal.isScrollable,
              child: _ScrollbarPassiveRegion(details: details, child: corner),
            ),
          ),
        );
      }
    }

    return children;
  }
}

/// Explicitly disables scrollbar chrome.
class ElNoScrollBar extends ElScrollbar {
  const ElNoScrollBar();

  @override
  List<Widget> buildChildren(BuildContext context, ElScrollbarDetails details) => const [];

  @override
  double resolveThumbThickness(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool hovered,
    required bool dragging,
  }) {
    return 0.0;
  }

  @override
  Widget buildThumb(
    BuildContext context,
    ElScrollbarAxisDetails axis, {
    required bool visible,
    required bool hovered,
    required bool dragging,
  }) => const SizedBox.shrink();
}

class _ScrollbarScrollableGate extends SingleChildRenderObjectWidget {
  const _ScrollbarScrollableGate({required this.active, required super.child});

  final bool active;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderScrollbarScrollableGate(active);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderScrollbarScrollableGate renderObject) {
    renderObject.active = active;
  }
}

class _RenderScrollbarScrollableGate extends RenderProxyBox with ElOverflowHitBounds implements OverflowHitTestHost {
  _RenderScrollbarScrollableGate(this._active);

  // 内部官方布局的深层命中只归条带管理；正文换窗不应重算这些代理。
  late final OverflowHitProxyRegistry _overflow = OverflowHitProxyRegistry(this);

  @override
  Rect get selfHitRect => Offset.zero & size;

  @override
  bool get clipsHitBounds => true;

  @override
  void visitHitBoundsChildren(void Function(RenderBox child, Offset offset) visitor) {
    final target = child;
    if (target != null) visitor(target, Offset.zero);
  }

  @override
  void registerOverflowHitTestProxy(RenderBox candidate) => _overflow.register(candidate);

  @override
  void unregisterOverflowHitTestProxy(RenderBox candidate) => _overflow.unregister(candidate);

  @override
  void markOverflowHitTestProxyDirty(RenderBox candidate) => _overflow.markDirty(candidate);

  @override
  void visitOverflowHitTestProxyBounds(void Function(Rect bounds) visitor) => _overflow.visitBounds(visitor);

  // 条带直接挂到滚动视口后独立重绘，正文平移不重画整根轨道。
  @override
  bool get isRepaintBoundary => true;

  bool _active;
  set active(bool value) {
    if (_active == value) return;
    _active = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_active) return;
    _overflow.syncForPaint();
    super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    return _active && super.hitTest(result, position: position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (super.hitTestChildren(result, position: position)) return true;
    final target = child;
    // thumb 自带重绘边界，官方 Transform 可能未重画条带；实际读代理时再校验。
    _overflow.syncForPaint();
    return target != null && _overflow.hitTestForChild(result, position: position, directChild: target);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_active) super.visitChildrenForSemantics(visitor);
  }
}

class _ScrollbarPassiveRegion extends StatelessWidget {
  const _ScrollbarPassiveRegion({required this.details, required this.child});

  final ElScrollbarDetails details;
  final Widget child;

  void _stop(ElEventDetails callback) => callback.stopPropagation();

  void _handleSignal(ElEventDetails callback) {
    final event = callback.originalEvent;
    if (event is PointerSignalEvent && details.dispatchPointerSignal(event)) {
      callback.stopPropagation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElView(
      event: ElEvent(
        onTapDown: _stop,
        onDragDown: _stop,
        onSecondaryTapDown: _stop,
        onTertiaryTapDown: _stop,
        onForwardTapDown: _stop,
        onBackTapDown: _stop,
        onPointerMove: _stop,
        onPointerUp: _stop,
        onPointerCancel: _stop,
        onPointerEnter: _stop,
        onPointerHover: _stop,
        onPointerExit: _stop,
        onPointerSignal: _handleSignal,
      ),
      child: child,
    );
  }
}

class _ScrollbarAxis extends StatefulWidget {
  const _ScrollbarAxis({required this.scrollbar, required this.details, required this.axis});

  final ElScrollbar scrollbar;
  final ElScrollbarDetails details;
  final ElScrollbarAxisDetails axis;

  @override
  State<_ScrollbarAxis> createState() => _ScrollbarAxisState();
}

class _ScrollbarAxisState extends State<_ScrollbarAxis> {
  final GlobalKey _trackKey = GlobalKey();
  Timer? _hideTimer;
  Timer? _pressGateTimer;
  Timer? _pressHapticTimer;
  bool _shown = false;
  bool _hovering = false;
  bool _dragging = false;
  double _dragThumbOffset = 0.0;
  int? _dragPointer;
  RenderObject? _pointerLockOwner;
  int? _pendingPointer;
  Offset? _pendingLocal;
  Offset? _pendingDownPosition;
  PointerDeviceKind? _pendingKind;
  VelocityTracker? _dragVelocityTracker;
  double? _dragStartMain;
  bool _dragMovedSinceStart = false;
  _AxisThumbGeometry? _lastGeometry;
  _AxisThumbGeometry? _dragGeometry;
  double? _lastPixels;

  @override
  void initState() {
    super.initState();
    _shown = widget.scrollbar.resolveAlwaysVisible(context, widget.axis);
    widget.details.addListener(_syncScrollVisibility);
    _syncScrollVisibility();
  }

  @override
  void didUpdateWidget(covariant _ScrollbarAxis oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.details, widget.details)) {
      oldWidget.details.removeListener(_syncScrollVisibility);
      widget.details.addListener(_syncScrollVisibility);
    }
    if (!widget.scrollbar.resolveInteractive(context, widget.axis) && _dragging) {
      _dragging = false;
      _teardownDragSession();
    }
    if (widget.scrollbar.resolveAlwaysVisible(context, widget.axis)) {
      _hideTimer?.cancel();
      _shown = true;
    }
    _syncScrollVisibility();
  }

  @override
  void dispose() {
    widget.details.removeListener(_syncScrollVisibility);
    if (_dragging) {
      _dragging = false;
      _teardownDragSession();
    }
    _releasePointerLock();
    _hideTimer?.cancel();
    _pressGateTimer?.cancel();
    _pressHapticTimer?.cancel();
    super.dispose();
  }

  void _syncScrollVisibility() {
    if (!mounted) return;
    if (widget.scrollbar.resolveAlwaysVisible(context, widget.axis)) {
      _hideTimer?.cancel();
      if (!_shown) setState(() => _shown = true);
      return;
    }
    final moved = _lastPixels != null && (widget.axis.pixels - _lastPixels!).abs() > precisionErrorTolerance;
    _lastPixels = widget.axis.pixels;
    if (widget.axis.isScrolling || moved) {
      _show();
      if (!widget.axis.isScrolling && !_hovering && !_dragging) _scheduleHide();
    } else if (!_hovering && !_dragging) {
      _scheduleHide();
    }
  }

  void _show() {
    _hideTimer?.cancel();
    if (_shown || !mounted) return;
    setState(() => _shown = true);
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_shown || _hovering || _dragging || widget.scrollbar.resolveAlwaysVisible(context, widget.axis)) {
      return;
    }
    _hideTimer = Timer(widget.scrollbar.resolveFadeDelay(context, widget.axis), () {
      if (mounted && !_hovering && !_dragging) setState(() => _shown = false);
    });
  }

  void _setHovering(bool value) {
    if (_hovering == value) return;
    setState(() => _hovering = value);
    if (value) {
      _show();
    } else {
      _scheduleHide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _shown || widget.scrollbar.resolveAlwaysVisible(context, widget.axis);
    final background = widget.scrollbar.buildAxisBackground(
      context,
      widget.axis,
      visible: visible,
      hovered: _hovering,
      dragging: _dragging,
    );
    final leadingExtent = widget.scrollbar.resolveLeadingButtonExtent(context, widget.axis);
    final trailingExtent = widget.scrollbar.resolveTrailingButtonExtent(context, widget.axis);
    final track = _buildTrack(context, visible: visible);
    Widget panel = Stack(
      fit: StackFit.expand,
      children: [
        if (background != null) Positioned.fill(child: background),
        _ScrollbarAxisLayout(
          axis: widget.axis.axis,
          leadingExtent: leadingExtent,
          trailingExtent: trailingExtent,
          children: [
            if (leadingExtent > 0.0)
              _ScrollbarAxisSlot(
                slot: _ScrollbarAxisLayoutSlot.leading,
                child: _ScrollbarButton(
                  scrollbar: widget.scrollbar,
                  axis: widget.axis,
                  forward: false,
                  extent: leadingExtent,
                ),
              ),
            _ScrollbarAxisSlot(slot: _ScrollbarAxisLayoutSlot.track, child: track),
            if (trailingExtent > 0.0)
              _ScrollbarAxisSlot(
                slot: _ScrollbarAxisLayoutSlot.trailing,
                child: _ScrollbarButton(
                  scrollbar: widget.scrollbar,
                  axis: widget.axis,
                  forward: true,
                  extent: trailingExtent,
                ),
              ),
          ],
        ),
      ],
    );

    if (!widget.scrollbar.resolveInteractive(context, widget.axis)) {
      return IgnorePointer(child: panel);
    }
    panel = ElView(
      event: ElEvent(
        onTapDown: _stopPropagation,
        onDragDown: _stopPropagation,
        onSecondaryTapDown: _stopPropagation,
        onTertiaryTapDown: _stopPropagation,
        onForwardTapDown: _stopPropagation,
        onBackTapDown: _stopPropagation,
        onPointerMove: _stopPropagation,
        onPointerUp: _stopPropagation,
        onPointerCancel: _stopPropagation,
        onPointerEnter: _stopPropagation,
        onPointerHover: _stopPropagation,
        onPointerExit: _stopPropagation,
        onPointerSignal: _handlePointerSignal,
      ),
      style: const ElStyle(cursor: SystemMouseCursors.basic),
      child: panel,
    );
    return _ScrollbarStripPriorityGate(
      viewId: View.of(context).viewId,
      axis: widget.axis.axis,
      crossAxisHitExtent: widget.scrollbar.resolveInteractiveThickness(context, widget.axis),
      centerCross: widget.scrollbar.resolveCenterThumb(context, widget.axis),
      child: panel,
    );
  }

  Widget _buildTrack(BuildContext context, {required bool visible}) {
    final track = widget.scrollbar.buildTrack(
      context,
      widget.axis,
      visible: visible,
      hovered: _hovering,
      dragging: _dragging,
    );
    return ElView(
      key: _trackKey,
      event: ElEvent(
        onTapDown: _handleTrackTapDown,
        onDragDown: _stopPropagation,
        onPointerMove: _handleTrackPointerMove,
        onPointerUp: _handleTrackPointerUpOrCancel,
        onPointerCancel: _handleTrackPointerUpOrCancel,
        onPointerEnter: _handleTrackPointerEnter,
        onPointerHover: _handleTrackPointerHover,
        onPointerExit: _handleTrackPointerExit,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (track != null) Positioned.fill(child: track),
          Positioned.fill(
            child: _ScrollbarThumbSlide(
              axis: widget.axis,
              repaint: widget.details,
              minThumbExtent: widget.scrollbar.resolveMinThumbExtent(context, widget.axis),
              minOverscrollThumbExtent: widget.scrollbar.resolveMinOverscrollThumbExtent(context, widget.axis),
              centerCross: widget.scrollbar.resolveCenterThumb(context, widget.axis),
              onGeometry: _publishGeometry,
              // thumb 稳定 key：测试/基准经它取 thumb 元素与全局矩形
              // （elThumbRect 三处 support 件共用；strip 有 resolveAxisKey）。
              child: KeyedSubtree(
                key: ValueKey<String>('el-scrollbar-thumb-${widget.axis.axis.name}'),
                child: widget.scrollbar.buildThumb(
                  context,
                  widget.axis,
                  visible: visible,
                  hovered: _hovering,
                  dragging: _dragging,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _stopPropagation(ElEventDetails callback) => callback.stopPropagation();

  void _handlePointerSignal(ElEventDetails callback) {
    final event = callback.originalEvent;
    if (event is PointerSignalEvent && widget.details.dispatchPointerSignal(event)) {
      callback.stopPropagation();
    }
  }

  bool _isHoverCapable(PointerDeviceKind kind) {
    return kind == PointerDeviceKind.mouse ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus;
  }

  void _handleTrackTapDown(ElEventDetails callback) {
    callback.stopPropagation();
    final event = callback.originalEvent;
    if (event is PointerDownEvent) _handleDown(event, callback.localPosition, callback);
  }

  void _handleTrackPointerMove(ElEventDetails callback) {
    callback.stopPropagation();
    final event = callback.originalEvent;
    if (event is PointerMoveEvent) _handleMove(event, callback.localPosition);
  }

  void _handleTrackPointerUpOrCancel(ElEventDetails callback) {
    callback.stopPropagation();
    final event = callback.originalEvent;
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _handleUpOrCancel(event as PointerEvent, callback.localPosition);
    }
  }

  void _handleTrackPointerEnter(ElEventDetails callback) {
    callback.stopPropagation();
    final event = callback.originalEvent;
    if (event is PointerEnterEvent && _isHoverCapable(event.kind)) {
      _updateHover(callback.localPosition);
    }
  }

  void _handleTrackPointerHover(ElEventDetails callback) {
    callback.stopPropagation();
    final event = callback.originalEvent;
    if (event is PointerHoverEvent && _isHoverCapable(event.kind)) {
      _updateHover(callback.localPosition);
    }
  }

  void _handleTrackPointerExit(ElEventDetails callback) {
    callback.stopPropagation();
    if (callback.originalEvent is PointerExitEvent) _setHovering(false);
  }

  void _updateHover(Offset localPosition) {
    final entireTrack = widget.scrollbar.resolveHoverOnEntireTrack(context, widget.axis);
    final geometry = _lastGeometry;
    _setHovering(entireTrack || (geometry != null && _onThumbMainSpan(localPosition, geometry)));
  }

  void _publishGeometry(_AxisThumbGeometry geometry) {
    _lastGeometry = geometry;
  }

  void _handleDown(PointerDownEvent event, Offset localPosition, ElEventDetails callback) {
    if (_dragging) return;
    if (event.kind == PointerDeviceKind.mouse && (event.buttons & kPrimaryButton) == 0) return;
    final geometry = _lastGeometry;
    if (geometry == null) return;
    final onThumb = _onThumbMainSpan(localPosition, geometry);
    if (!onThumb && !widget.scrollbar.resolveTrackTapJumps(context, widget.axis)) return;
    callback.eagerGesture(cancelSelfTap: true);

    final pressDuration = widget.scrollbar.resolvePressDuration(context, widget.axis);
    if (pressDuration <= Duration.zero) {
      _beginDrag(localPosition, geometry, pointer: event.pointer, kind: event.kind);
      return;
    }
    _pendingPointer = event.pointer;
    _pendingLocal = localPosition;
    _pendingDownPosition = event.position;
    _pendingKind = event.kind;
    _pressGateTimer?.cancel();
    _pressGateTimer = Timer(pressDuration, () {
      final local = _pendingLocal;
      final kind = _pendingKind;
      final pointer = _pendingPointer;
      _clearPressGate();
      if (!mounted || _dragging || local == null || pointer == null) return;
      _beginDrag(local, _lastGeometry ?? geometry, pointer: pointer, kind: kind);
    });
  }

  void _handleMove(PointerMoveEvent event, Offset localPosition) {
    if (_pendingPointer == event.pointer && _pressGateTimer != null) {
      final down = _pendingDownPosition;
      if (down != null && (event.position - down).distance > kTouchSlop) {
        _clearPressGate();
      }
      return;
    }
    if (!_dragging || event.pointer != _dragPointer) return;
    _dragVelocityTracker?.addPosition(event.timeStamp, event.position);
    final geometry = _dragGeometry ?? _lastGeometry;
    if (geometry == null) return;
    final main = _mainOffset(localPosition);
    if (_dragStartMain != null && (main - _dragStartMain!).abs() > precisionErrorTolerance) {
      _dragMovedSinceStart = true;
    }
    widget.axis.updateThumbDrag(geometry.fractionForThumbStart(main - _dragThumbOffset));
  }

  void _handleUpOrCancel(PointerEvent event, Offset localPosition) {
    if (_pendingPointer == event.pointer) _clearPressGate();
    if (!_dragging || event.pointer != _dragPointer) return;
    _endDrag();
  }

  void _clearPressGate() {
    _pressGateTimer?.cancel();
    _pressGateTimer = null;
    _pendingPointer = null;
    _pendingLocal = null;
    _pendingDownPosition = null;
    _pendingKind = null;
  }

  bool _onThumbMainSpan(Offset position, _AxisThumbGeometry geometry) {
    final main = _mainOffset(position);
    return main >= geometry.thumbStart && main <= geometry.thumbStart + geometry.thumbExtent;
  }

  void _beginDrag(Offset position, _AxisThumbGeometry geometry, {int? pointer, PointerDeviceKind? kind}) {
    final main = _mainOffset(position);
    final onThumb = _onThumbMainSpan(position, geometry);
    if (!onThumb && !widget.scrollbar.resolveTrackTapJumps(context, widget.axis)) return;
    _dragThumbOffset = onThumb ? main - geometry.thumbStart : geometry.thumbExtent / 2.0;
    setState(() => _dragging = true);
    _dragPointer = pointer;
    _dragGeometry = geometry;
    _dragStartMain = main;
    _dragMovedSinceStart = false;
    _dragVelocityTracker = kind == null ? null : VelocityTracker.withKind(kind);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handleGlobalPointerEvent);
    widget.axis.beginThumbDrag();
    widget.scrollbar.onThumbDragStart(widget.axis);
    if (kind == PointerDeviceKind.mouse) {
      final render = _trackRender;
      if (render != null) {
        _pointerLockOwner = render;
        DragPointerLock.claim(render);
      }
    }
    if (widget.scrollbar.resolveHapticOnThumbPress(context, widget.axis)) {
      _pressHapticTimer?.cancel();
      final duration = widget.scrollbar.resolveAnimationStyle(context).duration ?? const Duration(milliseconds: 160);
      _pressHapticTimer = Timer(duration, () {
        _pressHapticTimer = null;
        if (mounted && _dragging) HapticFeedback.mediumImpact();
      });
    }
    final seededThumbStart = onThumb ? geometry.thumbStart : main - _dragThumbOffset;
    widget.axis.updateThumbDrag(geometry.fractionForThumbStart(seededThumbStart));
    _show();
  }

  RenderBox? get _trackRender {
    final render = _trackKey.currentContext?.findRenderObject();
    return render is RenderBox ? render : null;
  }

  void _endDrag() {
    if (widget.scrollbar.resolveHapticOnThumbPress(context, widget.axis) && _dragMovedSinceStart) {
      final velocity = _dragVelocityTracker?.getVelocity().pixelsPerSecond;
      final axisVelocity = velocity == null ? 0.0 : (widget.axis.axis == Axis.vertical ? velocity.dy : velocity.dx);
      if (axisVelocity.abs() < 10.0) HapticFeedback.mediumImpact();
    }
    _teardownDragSession();
    if (mounted) setState(() => _dragging = false);
    _scheduleHide();
  }

  void _teardownDragSession() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handleGlobalPointerEvent);
    _releasePointerLock();
    _pressHapticTimer?.cancel();
    _pressHapticTimer = null;
    _dragVelocityTracker = null;
    _dragPointer = null;
    _dragGeometry = null;
    _dragStartMain = null;
    widget.axis.endThumbDrag();
    widget.scrollbar.onThumbDragEnd(widget.axis);
  }

  void _releasePointerLock() {
    final owner = _pointerLockOwner;
    _pointerLockOwner = null;
    if (owner != null) DragPointerLock.release(owner);
  }

  void _handleGlobalPointerEvent(PointerEvent event) {
    if (event is! PointerRemovedEvent || !_dragging) return;
    if (_dragPointer != null && event.pointer != _dragPointer) return;
    _endDrag();
  }

  double _mainOffset(Offset offset) => widget.axis.axis == Axis.vertical ? offset.dy : offset.dx;
}

enum _ScrollbarAxisLayoutSlot { leading, track, trailing }

class _ScrollbarAxisSlot extends ParentDataWidget<_ScrollbarAxisLayoutParentData> {
  const _ScrollbarAxisSlot({required this.slot, required super.child});

  final _ScrollbarAxisLayoutSlot slot;

  @override
  Type get debugTypicalAncestorWidgetClass => _ScrollbarAxisLayout;

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData! as _ScrollbarAxisLayoutParentData;
    if (parentData.slot == slot) return;
    parentData.slot = slot;
    final parent = renderObject.parent;
    if (parent is _RenderScrollbarAxisLayout) parent.markNeedsLayout();
  }
}

class _ScrollbarAxisLayout extends MultiChildRenderObjectWidget {
  const _ScrollbarAxisLayout({
    required this.axis,
    required this.leadingExtent,
    required this.trailingExtent,
    required super.children,
  });

  final Axis axis;
  final double leadingExtent;
  final double trailingExtent;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderScrollbarAxisLayout(axis: axis, leadingExtent: leadingExtent, trailingExtent: trailingExtent);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderScrollbarAxisLayout renderObject) {
    renderObject
      ..axis = axis
      ..leadingExtent = leadingExtent
      ..trailingExtent = trailingExtent;
  }
}

class _ScrollbarAxisLayoutParentData extends ContainerBoxParentData<RenderBox> {
  _ScrollbarAxisLayoutSlot slot = _ScrollbarAxisLayoutSlot.track;
  double laidOutMainExtent = 0.0;
}

class _RenderScrollbarAxisLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ScrollbarAxisLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ScrollbarAxisLayoutParentData> {
  _RenderScrollbarAxisLayout({required this._axis, required this._leadingExtent, required this._trailingExtent});

  Axis _axis;
  set axis(Axis value) {
    if (_axis == value) return;
    _axis = value;
    markNeedsLayout();
  }

  double _leadingExtent;
  set leadingExtent(double value) {
    if (_leadingExtent == value) return;
    _leadingExtent = value;
    markNeedsLayout();
  }

  double _trailingExtent;
  set trailingExtent(double value) {
    if (_trailingExtent == value) return;
    _trailingExtent = value;
    markNeedsLayout();
  }

  bool get _isVertical => _axis == Axis.vertical;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _ScrollbarAxisLayoutParentData) {
      child.parentData = _ScrollbarAxisLayoutParentData();
    }
  }

  RenderBox? _childFor(_ScrollbarAxisLayoutSlot slot) {
    var child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as _ScrollbarAxisLayoutParentData;
      if (parentData.slot == slot) return child;
      child = parentData.nextSibling;
    }
    return null;
  }

  Size _sizeFor(BoxConstraints constraints) {
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : constraints.minWidth;
    final height = constraints.hasBoundedHeight ? constraints.maxHeight : constraints.minHeight;
    return constraints.constrain(Size(width.isFinite ? width : 0.0, height.isFinite ? height : 0.0));
  }

  double _mainExtentOf(Size size) => _isVertical ? size.height : size.width;

  double _crossExtentOf(Size size) => _isVertical ? size.width : size.height;

  BoxConstraints _constraintsFor(double mainExtent) {
    final main = math.max(0.0, mainExtent);
    final cross = math.max(0.0, _crossExtentOf(size));
    return _isVertical ? BoxConstraints.tight(Size(cross, main)) : BoxConstraints.tight(Size(main, cross));
  }

  Offset _offsetFor(double mainOffset) => _isVertical ? Offset(0.0, mainOffset) : Offset(mainOffset, 0.0);

  void _layoutSlot(_ScrollbarAxisLayoutSlot slot, double mainExtent, double mainOffset) {
    final child = _childFor(slot);
    if (child == null) return;
    child.layout(_constraintsFor(mainExtent), parentUsesSize: true);
    final parentData = child.parentData! as _ScrollbarAxisLayoutParentData;
    parentData.offset = _offsetFor(mainOffset);
    parentData.laidOutMainExtent = math.max(0.0, mainExtent);
  }

  bool _shouldExpose(RenderBox child) {
    final parentData = child.parentData! as _ScrollbarAxisLayoutParentData;
    return parentData.laidOutMainExtent > precisionErrorTolerance && !child.size.isEmpty;
  }

  @override
  void performLayout() {
    size = _sizeFor(constraints);
    final mainExtent = math.max(0.0, _mainExtentOf(size));
    final hasLeading = _childFor(_ScrollbarAxisLayoutSlot.leading) != null && _leadingExtent > 0.0;
    final hasTrailing = _childFor(_ScrollbarAxisLayoutSlot.trailing) != null && _trailingExtent > 0.0;
    final requestedLeading = hasLeading ? _leadingExtent : 0.0;
    final requestedTrailing = hasTrailing ? _trailingExtent : 0.0;
    final buttonExtent = requestedLeading + requestedTrailing;

    // Windows 双轴极短视口会让条带主轴短于两个按钮；此时按钮退为 0，
    // 轨道独占空间，避免重叠命中和 RenderFlex overflow。
    final buttonsFit = mainExtent + precisionErrorTolerance >= buttonExtent;
    final leadingExtent = buttonsFit ? requestedLeading : 0.0;
    final trailingExtent = buttonsFit ? requestedTrailing : 0.0;
    final trackExtent = math.max(0.0, mainExtent - leadingExtent - trailingExtent);

    _layoutSlot(_ScrollbarAxisLayoutSlot.leading, leadingExtent, 0.0);
    _layoutSlot(_ScrollbarAxisLayoutSlot.track, trackExtent, leadingExtent);
    _layoutSlot(_ScrollbarAxisLayoutSlot.trailing, trailingExtent, leadingExtent + trackExtent);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints);

  @override
  void paint(PaintingContext context, Offset offset) {
    var child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as _ScrollbarAxisLayoutParentData;
      if (_shouldExpose(child)) context.paintChild(child, offset + parentData.offset);
      child = parentData.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = lastChild;
    while (child != null) {
      final current = child;
      final parentData = child.parentData! as _ScrollbarAxisLayoutParentData;
      final previous = parentData.previousSibling;
      if (_shouldExpose(child)) {
        final hit = result.addWithPaintOffset(
          offset: parentData.offset,
          position: position,
          hitTest: (result, transformed) => current.hitTest(result, position: transformed),
        );
        if (hit) return true;
      }
      child = previous;
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final parentData = child.parentData! as _ScrollbarAxisLayoutParentData;
    transform.translateByDouble(parentData.offset.dx, parentData.offset.dy, 0.0, 1.0);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    var child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as _ScrollbarAxisLayoutParentData;
      if (_shouldExpose(child)) visitor(child);
      child = parentData.nextSibling;
    }
  }
}

class _ScrollbarButton extends StatefulWidget {
  const _ScrollbarButton({required this.scrollbar, required this.axis, required this.forward, required this.extent});

  final ElScrollbar scrollbar;
  final ElScrollbarAxisDetails axis;
  final bool forward;
  final double extent;

  @override
  State<_ScrollbarButton> createState() => _ScrollbarButtonState();
}

class _ScrollbarButtonState extends State<_ScrollbarButton> with SingleTickerProviderStateMixin {
  Timer? _repeatDelayTimer;
  Ticker? _holdTicker;
  Duration _lastHoldTick = Duration.zero;
  bool _pressed = false;
  bool _reportedPress = false;

  bool get _canScroll => widget.forward ? widget.axis.canScrollTrailing : widget.axis.canScrollLeading;

  bool get _enabled =>
      _canScroll || widget.scrollbar.resolveButtonInteractiveAtBoundary(context, widget.axis, forward: widget.forward);

  @override
  void dispose() {
    if (_reportedPress) {
      _reportedPress = false;
      widget.scrollbar.onButtonPressEnd(widget.axis, forward: widget.forward);
    }
    _pressed = false;
    _stopRepeat();
    _holdTicker?.dispose();
    super.dispose();
  }

  void _handleDown(ElEventDetails callback) {
    callback.stopPropagation();
    if (!_enabled || _pressed) return;
    callback.eagerGesture(cancelSelfTap: true);
    setState(() => _pressed = true);
    if (!_canScroll) return;
    _reportedPress = true;
    widget.scrollbar.onButtonPressStart(widget.axis, forward: widget.forward);
    final delta = widget.scrollbar.resolveButtonLineDelta(context, widget.axis, forward: widget.forward);
    widget.axis.animateToPixels(
      widget.axis.pixels + delta,
      duration: widget.scrollbar.resolveButtonAnimateDuration(context, widget.axis),
      curve: Curves.easeOutCubic,
    );
    _repeatDelayTimer = Timer(widget.scrollbar.resolveButtonRepeatDelay(context, widget.axis), () {
      _repeatDelayTimer = null;
      _lastHoldTick = Duration.zero;
      final ticker = _holdTicker ??= createTicker(_handleHoldTick);
      if (!ticker.isActive) ticker.start();
    });
  }

  void _stopDrag(ElEventDetails callback) => callback.stopPropagation();

  void _handleHoldTick(Duration elapsed) {
    final seconds = (elapsed - _lastHoldTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastHoldTick = elapsed;
    if (seconds <= 0) return;
    if (!_canScroll) {
      _stopRepeat();
      return;
    }
    final interval = widget.scrollbar.resolveButtonRepeatInterval(context, widget.axis);
    final intervalSeconds = interval.inMicroseconds / Duration.microsecondsPerSecond;
    if (intervalSeconds <= 0) return;
    final delta = widget.scrollbar.resolveButtonLineDelta(context, widget.axis, forward: widget.forward);
    widget.axis.scrollByPixels(delta / intervalSeconds * seconds);
  }

  void _handleUpOrCancel(ElEventDetails callback) {
    callback.stopPropagation();
    _stopRepeat();
    if (!_pressed) return;
    if (_reportedPress) {
      _reportedPress = false;
      widget.scrollbar.onButtonPressEnd(widget.axis, forward: widget.forward);
    }
    if (mounted) setState(() => _pressed = false);
  }

  void _stopRepeat() {
    _repeatDelayTimer?.cancel();
    _repeatDelayTimer = null;
    _holdTicker?.stop();
    _lastHoldTick = Duration.zero;
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.forward
        ? widget.scrollbar.buildTrailingButton(context, widget.axis, enabled: _enabled, pressed: _pressed)
        : widget.scrollbar.buildLeadingButton(context, widget.axis, enabled: _enabled, pressed: _pressed);
    if (child == null) return const SizedBox.shrink();
    final isVertical = widget.axis.axis == Axis.vertical;
    return ElView(
      semantics: ElSemantics(
        button: true,
        enabled: _enabled,
        label: widget.scrollbar.resolveButtonSemanticsLabel(context, widget.axis, forward: widget.forward),
      ),
      event: ElEvent(
        onTapDown: _handleDown,
        onDragDown: _stopDrag,
        onPointerUp: _handleUpOrCancel,
        onPointerCancel: _handleUpOrCancel,
      ),
      style: ElStyle(
        width: isVertical ? '100%' : widget.extent,
        height: isVertical ? widget.extent : '100%',
        alignment: .center,
      ),
      child: child,
    );
  }
}

class _ScrollbarStripPriorityGate extends SingleChildRenderObjectWidget {
  const _ScrollbarStripPriorityGate({
    required this.viewId,
    required this.axis,
    required this.crossAxisHitExtent,
    required this.centerCross,
    required super.child,
  });

  final int viewId;
  final Axis axis;
  final double crossAxisHitExtent;
  final bool centerCross;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderScrollbarStripPriorityGate(
      viewId: viewId,
      axis: axis,
      crossAxisHitExtent: crossAxisHitExtent,
      centerCross: centerCross,
    );
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderScrollbarStripPriorityGate renderObject) {
    renderObject
      ..viewId = viewId
      ..axis = axis
      ..crossAxisHitExtent = crossAxisHitExtent
      ..centerCross = centerCross;
  }
}

class _RenderScrollbarStripPriorityGate extends RenderProxyBox {
  _RenderScrollbarStripPriorityGate({
    required this.viewId,
    required this.axis,
    required this.crossAxisHitExtent,
    required this.centerCross,
  });

  int viewId;
  Axis axis;
  double crossAxisHitExtent;
  bool centerCross;

  static int _attachedCount = 0;
  static bool _probingNestedPriority = false;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _attachedCount++;
  }

  @override
  void detach() {
    _attachedCount--;
    super.detach();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position) || !_containsCrossAxis(position)) return false;
    if (_probingNestedPriority) {
      result.add(BoxHitTestEntry(this, position));
      return false;
    }
    if (_attachedCount > 1 && _hasDeeperScrollbarAt(localToGlobal(position))) return false;
    return super.hitTest(result, position: position);
  }

  bool _containsCrossAxis(Offset position) {
    final crossExtent = axis == Axis.vertical ? size.width : size.height;
    final hitExtent = crossAxisHitExtent.clamp(0.0, crossExtent).toDouble();
    final start = centerCross ? (crossExtent - hitExtent) / 2.0 : crossExtent - hitExtent;
    final crossOffset = axis == Axis.vertical ? position.dx : position.dy;
    return crossOffset >= start && crossOffset <= start + hitExtent;
  }

  bool _hasDeeperScrollbarAt(Offset globalPosition) {
    final result = HitTestResult();
    _probingNestedPriority = true;
    try {
      WidgetsBinding.instance.hitTestInView(result, globalPosition, viewId);
    } finally {
      _probingNestedPriority = false;
    }
    var sawSelf = false;
    for (final entry in result.path) {
      final target = entry.target;
      if (target is! _RenderScrollbarStripPriorityGate) continue;
      if (identical(target, this)) {
        sawSelf = true;
      } else if (sawSelf) {
        return true;
      }
    }
    return false;
  }
}

@immutable
class _AxisThumbGeometry {
  const _AxisThumbGeometry({
    required this.axis,
    required this.size,
    required this.thumbExtent,
    required this.thumbStart,
  });

  final Axis axis;
  final Size size;
  final double thumbExtent;
  final double thumbStart;

  static _AxisThumbGeometry resolve({
    required Size size,
    required Axis axis,
    required ElScrollbarAxisDetails details,
    required double minThumbExtent,
    double? minOverscrollThumbExtent,
  }) {
    final trackExtent = axis == Axis.vertical ? size.height : size.width;
    final contentExtent = details.maxScrollExtent - details.minScrollExtent + details.viewportExtent;
    final leadingOverscroll = (details.minScrollExtent - details.pixels).clamp(0.0, details.viewportExtent);
    final trailingOverscroll = (details.pixels - details.maxScrollExtent).clamp(0.0, details.viewportExtent);
    final extentInside = details.viewportExtent - leadingOverscroll - trailingOverscroll;
    final proportional = contentExtent <= 0.0 ? trackExtent : trackExtent * extentInside / contentExtent;
    final normalMinimum = math.min(minThumbExtent, trackExtent);
    final overscroll = math.max(leadingOverscroll, trailingOverscroll);
    final minimum = minOverscrollThumbExtent == null
        ? normalMinimum
        : lerpDouble(
            normalMinimum,
            math.min(minOverscrollThumbExtent, trackExtent),
            (overscroll / math.max(details.viewportExtent * 0.2, 1.0)).clamp(0.0, 1.0),
          )!;
    final extent = proportional.clamp(minimum, trackExtent).toDouble();
    final start = (trackExtent - extent) * details.visualFraction;
    return _AxisThumbGeometry(axis: axis, size: size, thumbExtent: extent, thumbStart: start);
  }

  static const double _edgeSnapTolerance = 2.0;

  double fractionForThumbStart(double value) {
    final trackExtent = axis == Axis.vertical ? size.height : size.width;
    final travel = trackExtent - thumbExtent;
    if (travel <= 0.0) return 0.0;
    if (value <= _edgeSnapTolerance) return 0.0;
    if (value + thumbExtent >= trackExtent - _edgeSnapTolerance) return 1.0;
    return (value / travel).clamp(0.0, 1.0).toDouble();
  }
}

class _ScrollbarThumbSlide extends SingleChildRenderObjectWidget {
  const _ScrollbarThumbSlide({
    required this.axis,
    required this.repaint,
    required this.minThumbExtent,
    this.minOverscrollThumbExtent,
    this.centerCross = false,
    required this.onGeometry,
    required super.child,
  });

  final ElScrollbarAxisDetails axis;
  final Listenable repaint;
  final double minThumbExtent;
  final double? minOverscrollThumbExtent;
  final bool centerCross;
  final ValueSetter<_AxisThumbGeometry> onGeometry;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderScrollbarThumbSlide(axis, repaint, minThumbExtent, minOverscrollThumbExtent, centerCross, onGeometry);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderScrollbarThumbSlide renderObject) {
    renderObject
      ..axis = axis
      ..repaint = repaint
      ..minThumbExtent = minThumbExtent
      ..minOverscrollThumbExtent = minOverscrollThumbExtent
      ..centerCross = centerCross
      ..onGeometry = onGeometry;
  }
}

class _RenderScrollbarThumbSlide extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  _RenderScrollbarThumbSlide(
    this._axis,
    this._repaint,
    this._minThumbExtent,
    this._minOverscrollThumbExtent,
    this._centerCross,
    this.onGeometry,
  );

  ValueSetter<_AxisThumbGeometry> onGeometry;

  ElScrollbarAxisDetails _axis;
  set axis(ElScrollbarAxisDetails value) {
    if (identical(value, _axis)) return;
    _axis = value;
    markNeedsLayout();
  }

  Listenable _repaint;
  set repaint(Listenable value) {
    if (identical(value, _repaint)) return;
    if (attached) _repaint.removeListener(_handleTick);
    _repaint = value;
    if (attached) _repaint.addListener(_handleTick);
    markNeedsLayout();
  }

  double _minThumbExtent;
  set minThumbExtent(double value) {
    if (value == _minThumbExtent) return;
    _minThumbExtent = value;
    markNeedsLayout();
  }

  double? _minOverscrollThumbExtent;
  set minOverscrollThumbExtent(double? value) {
    if (value == _minOverscrollThumbExtent) return;
    _minOverscrollThumbExtent = value;
    markNeedsLayout();
  }

  bool _centerCross;
  set centerCross(bool value) {
    if (value == _centerCross) return;
    _centerCross = value;
    markNeedsLayout();
  }

  @override
  bool get isRepaintBoundary => true;

  Offset _childOffset = Offset.zero;
  double _lastThumbExtent = double.nan;
  final LayerHandle<TransformLayer> _transformLayer = LayerHandle<TransformLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint.addListener(_handleTick);
  }

  @override
  void detach() {
    _repaint.removeListener(_handleTick);
    super.detach();
  }

  bool get _isVertical => _axis.axis == Axis.vertical;

  _AxisThumbGeometry _resolveGeometry() {
    return _AxisThumbGeometry.resolve(
      size: size,
      axis: _axis.axis,
      details: _axis,
      minThumbExtent: _minThumbExtent,
      minOverscrollThumbExtent: _minOverscrollThumbExtent,
    );
  }

  void _handleTick() {
    if (!attached || !hasSize) return;
    final geometry = _resolveGeometry();
    onGeometry(geometry);
    if ((geometry.thumbExtent - _lastThumbExtent).abs() > precisionErrorTolerance) {
      markNeedsLayout();
      return;
    }
    final offset = _childOffsetFor(geometry);
    if (offset != _childOffset) {
      _childOffset = offset;
      markNeedsPaint();
    }
  }

  Offset _childOffsetFor(_AxisThumbGeometry geometry) {
    final childSize = child?.size ?? Size.zero;
    if (_isVertical) {
      final dx = _centerCross ? (size.width - childSize.width) / 2.0 : size.width - childSize.width;
      return Offset(math.max(0.0, dx), geometry.thumbStart);
    }
    final dy = _centerCross ? (size.height - childSize.height) / 2.0 : size.height - childSize.height;
    return Offset(geometry.thumbStart, math.max(0.0, dy));
  }

  Matrix4 _childTransformFor(_AxisThumbGeometry geometry) {
    final thumb = child;
    if (thumb == null) return Matrix4.identity();
    final offset = _childOffsetFor(geometry);
    final laidOutExtent = _isVertical ? thumb.size.height : thumb.size.width;
    final scale = laidOutExtent <= precisionErrorTolerance ? 1.0 : geometry.thumbExtent / laidOutExtent;
    return Matrix4.identity()
      ..translateByDouble(offset.dx, offset.dy, 0.0, 1.0)
      ..scaleByDouble(_isVertical ? 1.0 : scale, _isVertical ? scale : 1.0, 1.0, 1.0);
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    final geometry = _resolveGeometry();
    _lastThumbExtent = geometry.thumbExtent;
    onGeometry(geometry);
    final thumb = child;
    if (thumb == null) return;
    thumb.layout(
      _isVertical
          ? BoxConstraints(maxWidth: size.width, minHeight: geometry.thumbExtent, maxHeight: geometry.thumbExtent)
          : BoxConstraints(maxHeight: size.height, minWidth: geometry.thumbExtent, maxWidth: geometry.thumbExtent),
      parentUsesSize: true,
    );
    _childOffset = _childOffsetFor(geometry);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final thumb = child;
    if (thumb == null) {
      _transformLayer.layer = null;
      return;
    }
    final geometry = _resolveGeometry();
    onGeometry(geometry);
    final laidOutExtent = _isVertical ? thumb.size.height : thumb.size.width;
    if ((geometry.thumbExtent - laidOutExtent).abs() <= precisionErrorTolerance) {
      _transformLayer.layer = null;
      context.paintChild(thumb, offset + _childOffsetFor(geometry));
      return;
    }
    _transformLayer.layer = context.pushTransform(
      needsCompositing,
      offset,
      _childTransformFor(geometry),
      (context, offset) => context.paintChild(thumb, offset),
      oldLayer: _transformLayer.layer,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final thumb = child;
    if (thumb == null) return false;
    return result.addWithPaintTransform(
      transform: _childTransformFor(_resolveGeometry()),
      position: position,
      hitTest: (result, position) => thumb.hitTest(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    transform.multiply(_childTransformFor(_resolveGeometry()));
  }

  @override
  void dispose() {
    _transformLayer.layer = null;
    super.dispose();
  }
}
