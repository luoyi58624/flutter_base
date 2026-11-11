part of 'index.dart';

Widget _buildScrollbar(
  BuildContext context, {
  required bool occupiesSpace,
  required ScrollController? controller,
  required AxisDirection direction,
  required int notificationDepth,
  required double extent,
  required double thickness,
  required double radius,
  required double minThumbLength,
  required Color? thumbColor,
  required Color? thumbHoverColor,
  required Color? thumbActiveColor,
  Color? trackColor,
  Color? arrowColor,
  double arrowExtent = 0,
  double arrowSize = 9,
  required Widget child,
}) {
  final vertical = axisDirectionToAxis(direction) == Axis.vertical;
  final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  final resolvedTrackColor = trackColor ?? (dark ? const Color(0xFF2C2C2C) : const Color(0xFFFCFCFC));
  Widget content = child;
  if (occupiesSpace) {
    // 占位放在官方绘制层内部，让条带仍画在整个包装区域的最外缘。
    final border = BorderSide(color: resolvedTrackColor, width: extent);
    content = DecoratedBox(
      decoration: BoxDecoration(
        border: vertical ? Border(right: border) : Border(bottom: border),
      ),
      child: Padding(
        padding: vertical ? EdgeInsets.only(right: extent) : EdgeInsets.only(bottom: extent),
        child: child,
      ),
    );
  }
  final scrollbar = _DesktopRawScrollbar(
    controller: controller,
    notificationPredicate: (notification) =>
        notification.depth == notificationDepth && notification.metrics.axis == axisDirectionToAxis(direction),
    scrollbarOrientation: vertical ? ScrollbarOrientation.right : ScrollbarOrientation.bottom,
    thumbVisibility: occupiesSpace,
    trackVisibility: occupiesSpace,
    interactive: true,
    // 命中宽度覆盖整条轨道，shape 只收窄绘制，避免细边界被官方识别成轨道点击。
    thickness: extent,
    shape: _ThumbShape(axis: axisDirectionToAxis(direction), inset: (extent - thickness) / 2, radius: radius),
    minThumbLength: minThumbLength,
    mainAxisMargin: arrowExtent,
    padding: EdgeInsets.zero,
    thumbColor: thumbColor ?? (dark ? const Color(0x8BFFFFFF) : const Color(0x72000000)),
    hoverColor: thumbHoverColor ?? (dark ? const Color(0xB3FFFFFF) : const Color(0x99000000)),
    activeColor: thumbActiveColor ?? thumbHoverColor ?? (dark ? const Color(0xB3FFFFFF) : const Color(0x99000000)),
    trackColor: resolvedTrackColor,
    trackBorderColor: const Color(0x00000000),
    child: content,
  );
  final wheel = Listener(
    // 透明命中层先登记滚轮，点击和拖动仍落到下层官方滚动条。
    behavior: HitTestBehavior.translucent,
    onPointerSignal: (event) => _routeWheel(context, controller, event),
  );
  Widget arrow(bool forward) => _ArrowButton(
    controller: controller,
    axis: axisDirectionToAxis(direction),
    forward: forward,
    color: arrowColor ?? thumbColor ?? (dark ? const Color(0x8BFFFFFF) : const Color(0x72000000)),
    size: arrowSize,
  );
  return Stack(
    children: [
      scrollbar,
      if (vertical)
        Positioned(right: 0, top: 0, bottom: 0, width: extent, child: wheel)
      else
        Positioned(left: 0, right: 0, bottom: 0, height: extent, child: wheel),
      if (occupiesSpace && vertical) ...[
        Positioned(right: 0, top: 0, width: extent, height: arrowExtent, child: arrow(false)),
        Positioned(right: 0, bottom: 0, width: extent, height: arrowExtent, child: arrow(true)),
      ] else if (occupiesSpace) ...[
        Positioned(left: 0, bottom: 0, width: arrowExtent, height: extent, child: arrow(false)),
        Positioned(right: 0, bottom: 0, width: arrowExtent, height: extent, child: arrow(true)),
      ],
    ],
  );
}

// 复用正文滚动位置的平滑滚轮与嵌套协商，普通官方位置继续由 RawScrollbar 处理。
void _routeWheel(BuildContext context, ScrollController? controller, PointerSignalEvent event) {
  final effective = controller ?? PrimaryScrollController.maybeOf(context);
  if (effective == null || effective.positions.length != 1) return;
  final position = effective.position;
  if (position is ScrollHostPosition) position.handlePointerSignal(event);
}

// 官方 Painter 用完整 thumbRect 命中；仅通过形状缩小视觉宽度，不缩小拖动区域。
class _ThumbShape extends OutlinedBorder {
  const _ThumbShape({required this.axis, required this.inset, this.radius = 9999});

  final Axis axis;
  final double inset;
  final double radius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final visual = axis == Axis.vertical
        ? Rect.fromLTRB(rect.left + inset, rect.top, rect.right - inset, rect.bottom)
        : Rect.fromLTRB(rect.left, rect.top + inset, rect.right, rect.bottom - inset);
    return Path()..addRRect(RRect.fromRectAndRadius(visual, Radius.circular(radius)));
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => getOuterPath(rect, textDirection: textDirection);

  @override
  _ThumbShape copyWith({BorderSide? side}) => this;

  @override
  _ThumbShape scale(double t) => _ThumbShape(axis: axis, inset: inset * t, radius: radius * t);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}
}

// 仅覆写轨道定位和颜色反馈，官方仍负责滑块拖动与生命周期。
class _DesktopRawScrollbar extends RawScrollbar {
  const _DesktopRawScrollbar({
    required this.hoverColor,
    required this.activeColor,
    super.controller,
    required super.notificationPredicate,
    super.scrollbarOrientation,
    super.thumbVisibility,
    super.trackVisibility,
    super.interactive,
    super.thickness,
    super.shape,
    super.minThumbLength,
    super.mainAxisMargin,
    super.padding,
    super.thumbColor,
    super.trackColor,
    super.trackBorderColor,
    required super.child,
  });

  final Color hoverColor;
  final Color activeColor;

  @override
  RawScrollbarState<_DesktopRawScrollbar> createState() => _DesktopRawScrollbarState();
}

class _DesktopRawScrollbarState extends RawScrollbarState<_DesktopRawScrollbar> {
  bool _hovered = false;
  bool _dragging = false;
  int? _trackPointer;
  Offset? _trackPoint;
  ScrollController? _trackController;
  ScrollPosition? _trackPosition;
  late final _trackDrag = _TrackDragRecognizer()
    ..dragStartBehavior = DragStartBehavior.down
    ..onStart = (details) {
      _trackPoint = _localPoint(details.globalPosition);
      handleThumbPress();
      handleThumbPressStart(_trackPoint!);
    }
    ..onUpdate = (details) {
      _trackPoint = _localPoint(details.globalPosition);
      handleThumbPressUpdate(_trackPoint!);
    }
    ..onEnd = (_) {
      _endTrackDrag();
    }
    ..onCancel = _endTrackDrag;

  Offset _localPoint(Offset global) => (context.findRenderObject()! as RenderBox).globalToLocal(global);

  void _endTrackDrag() {
    final point = _trackPoint;
    _trackPoint = null;
    _trackPointer = null;
    if (point != null) handleThumbPressEnd(point, Velocity.zero);
    _trackController = null;
    _trackPosition = null;
  }

  @override
  void dispose() {
    // dispose 时不能再经官方松手回调读取祖先；仍挂载的位置直接取消拖动活动。
    final position = _trackPosition;
    if (position != null &&
        position.context.notificationContext?.mounted == true &&
        (_trackController?.positions.contains(position) ?? false)) {
      position.hold(() {}).cancel();
    }
    _trackPoint = null;
    _trackPointer = null;
    _trackDrag.dispose();
    super.dispose();
  }

  @override
  void updateScrollbarPainter() {
    super.updateScrollbarPainter();
    if (_hovered || _dragging) {
      scrollbarPainter.color = _dragging ? widget.activeColor : widget.hoverColor;
    }
  }

  @override
  void handleHover(PointerHoverEvent event) {
    super.handleHover(event);
    _hovered = isPointerOverThumb(event.position, event.kind);
    updateScrollbarPainter();
  }

  @override
  void handleHoverExit(PointerExitEvent event) {
    super.handleHoverExit(event);
    _hovered = false;
    updateScrollbarPainter();
  }

  @override
  void handleThumbPressStart(Offset localPosition) {
    super.handleThumbPressStart(localPosition);
    _dragging = true;
    updateScrollbarPainter();
  }

  @override
  void handleThumbPressEnd(Offset localPosition, Velocity velocity) {
    super.handleThumbPressEnd(localPosition, velocity);
    _dragging = false;
    updateScrollbarPainter();
  }

  // 定位已在 PointerDown 完成，不能再执行官方延迟触发的翻页。
  @override
  // ignore: must_call_super
  void handleTrackTapDown(TapDownDetails details) {}

  void _trackDown(PointerDownEvent event) {
    if (_trackPointer != null || event.buttons != kPrimaryButton || !isPointerOverTrack(event.position, event.kind)) {
      return;
    }
    final controller = widget.controller ?? PrimaryScrollController.maybeOf(context);
    if (controller == null || controller.positions.length != 1) return;
    final position = controller.position;
    if (!position.hasContentDimensions || !position.physics.shouldAcceptUserOffset(position)) return;
    final extent = position.maxScrollExtent - position.minScrollExtent;
    if (extent <= 0 || !extent.isFinite) return;
    final box = context.findRenderObject()! as RenderBox;
    final vertical = position.axis == Axis.vertical;
    final trackExtent = (vertical ? box.size.height : box.size.width) - widget.mainAxisMargin * 2;
    // 从官方 Painter 读取映射比例，避免另算最小滑块长度、越界压缩等几何。
    final ratio = scrollbarPainter.getTrackToScroll(1);
    if (!ratio.isFinite || ratio <= 0) return;
    final thumbExtent = trackExtent - extent / ratio;
    final coordinate = vertical ? event.localPosition.dy : event.localPosition.dx;
    final visual = ((coordinate - widget.mainAxisMargin - thumbExtent / 2) * ratio).clamp(0.0, extent);
    position.jumpTo(
      axisDirectionIsReversed(position.axisDirection)
          ? position.maxScrollExtent - visual
          : position.minScrollExtent + visual,
    );
    // 本次 down 已被官方归为轨道点击，主动认领同一指针并接入官方滑块拖动。
    // 同步新指标，保证不等下一帧移动时也以跳转后的位置为起点。
    scrollbarPainter.update(position, position.axisDirection);
    _trackPointer = event.pointer;
    _trackController = controller;
    _trackPosition = position;
    _trackDrag.addPointer(event);
  }

  @override
  Widget build(BuildContext context) => Listener(onPointerDown: _trackDown, child: super.build(context));
}

class _TrackDragRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
