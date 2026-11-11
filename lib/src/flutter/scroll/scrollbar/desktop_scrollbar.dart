import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// 复用官方 [RawScrollbar] 的桌面滚动条，Windows 占位，macOS/Linux 悬浮。
///
/// 与子树共享 [ScrollController]；不传时使用 [PrimaryScrollController]。
/// 滑块拖动、指标监听和绘制复用官方机制，轨道按下直接定位，Windows 两端提供步进箭头。
class ElDesktopScrollbar extends StatelessWidget {
  /// 创建预留 15 像素轨道空间的 Windows 滚动条。
  const ElDesktopScrollbar.windows({
    super.key,
    this.controller,
    this.direction = AxisDirection.down,
    this.notificationDepth = 0,
    required this.child,
  }) : _occupiesSpace = true;

  /// 创建不占正文空间的 macOS/Linux 悬浮滚动条。
  const ElDesktopScrollbar.mac({
    super.key,
    this.controller,
    this.direction = AxisDirection.down,
    this.notificationDepth = 0,
    required this.child,
  }) : _occupiesSpace = false;

  /// 与被包装滚动视图共享的官方控制器，缺省使用最近的 PrimaryScrollController。
  final ScrollController? controller;

  /// 滚动轴方向，横向条位于底部，纵向条位于右侧。
  final AxisDirection direction;

  /// 被监听的滚动视图相对 [child] 的嵌套深度。
  final int notificationDepth;

  /// 被滚动条包装的内容。
  final Widget child;

  final bool _occupiesSpace;

  @override
  Widget build(BuildContext context) {
    final vertical = axisDirectionToAxis(direction) == Axis.vertical;
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final trackColor = dark ? const Color(0xFF2C2C2C) : const Color(0xFFFCFCFC);
    Widget content = child;
    if (_occupiesSpace) {
      // 占位放在官方绘制层内部，让条带仍画在整个包装区域的最外缘。
      final border = BorderSide(color: trackColor, width: 15);
      content = DecoratedBox(
        decoration: BoxDecoration(
          border: vertical ? Border(right: border) : Border(bottom: border),
        ),
        child: Padding(
          padding: vertical ? const EdgeInsets.only(right: 15) : const EdgeInsets.only(bottom: 15),
          child: child,
        ),
      );
    }
    final scrollbar = _DesktopRawScrollbar(
      controller: controller,
      notificationPredicate: (notification) =>
          notification.depth == notificationDepth && notification.metrics.axis == axisDirectionToAxis(direction),
      scrollbarOrientation: vertical ? ScrollbarOrientation.right : ScrollbarOrientation.bottom,
      thumbVisibility: _occupiesSpace,
      trackVisibility: _occupiesSpace,
      interactive: true,
      // 命中宽度覆盖整条轨道，shape 只收窄绘制，避免细边界被官方识别成轨道点击。
      thickness: _occupiesSpace ? 15 : 10,
      shape: _ThumbShape(axis: axisDirectionToAxis(direction), inset: _occupiesSpace ? 3 : 2),
      minThumbLength: _occupiesSpace ? 17 : 36,
      mainAxisMargin: _occupiesSpace ? 18 : 0,
      padding: EdgeInsets.zero,
      thumbColor: dark ? const Color(0x8BFFFFFF) : const Color(0x72000000),
      trackColor: trackColor,
      trackBorderColor: const Color(0x00000000),
      child: content,
    );
    if (!_occupiesSpace) return scrollbar;
    Widget arrow(bool forward) => _ArrowButton(
      controller: controller,
      axis: axisDirectionToAxis(direction),
      forward: forward,
      color: dark ? const Color(0x8BFFFFFF) : const Color(0x72000000),
    );
    return Stack(
      children: [
        scrollbar,
        if (vertical) ...[
          Positioned(right: 0, top: 0, width: 15, height: 18, child: arrow(false)),
          Positioned(right: 0, bottom: 0, width: 15, height: 18, child: arrow(true)),
        ] else ...[
          Positioned(left: 0, bottom: 0, width: 18, height: 15, child: arrow(false)),
          Positioned(right: 0, bottom: 0, width: 18, height: 15, child: arrow(true)),
        ],
      ],
    );
  }
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
      scrollbarPainter.color = MediaQuery.platformBrightnessOf(context) == Brightness.dark
          ? const Color(0xB3FFFFFF)
          : const Color(0x99000000);
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

class _ArrowButton extends StatefulWidget {
  const _ArrowButton({required this.controller, required this.axis, required this.forward, required this.color});
  final ScrollController? controller;
  final Axis axis;
  final bool forward;
  final Color color;

  @override
  State<_ArrowButton> createState() => _ArrowButtonState();
}

class _ArrowButtonState extends State<_ArrowButton> {
  Timer? _timer;
  int? _pointer;

  void _step({bool animate = false}) {
    final controller = widget.controller ?? PrimaryScrollController.maybeOf(context);
    if (controller == null || controller.positions.length != 1) return;
    final position = controller.position;
    if (!position.hasContentDimensions || !position.physics.shouldAcceptUserOffset(position)) return;
    final direction = (widget.forward ? 1.0 : -1.0) * (axisDirectionIsReversed(position.axisDirection) ? -1 : 1);
    final target = (position.pixels + position.viewportDimension.clamp(160.0, 480.0) * 0.1 * direction).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (animate) {
      position.animateTo(target, duration: const Duration(milliseconds: 150), curve: Curves.easeOutCubic);
    } else {
      position.jumpTo(target);
    }
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null || event.buttons != kPrimaryButton) return;
    setState(() => _pointer = event.pointer);
    _step(animate: true);
    _timer = Timer(const Duration(milliseconds: 400), () {
      _step();
      _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => _step());
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (_pointer != null) setState(() => _pointer = null);
  }

  @override
  void deactivate() {
    _timer?.cancel();
    _timer = null;
    _pointer = null;
    super.deactivate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.axis == Axis.vertical
        ? (widget.forward ? '向下滚动' : '向上滚动')
        : (widget.forward ? '向右滚动' : '向左滚动');
    final side = _pointer == null ? 9.0 : 7.0;
    final delta = widget.forward ? 1.0 : -1.0;
    return Semantics(
      button: true,
      label: label,
      onTap: () => _step(animate: true),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerUp: (event) {
          if (event.pointer == _pointer) _stop();
        },
        onPointerCancel: (event) {
          if (event.pointer == _pointer) _stop();
        },
        child: Center(
          child: Transform.translate(
            offset: widget.axis == Axis.vertical ? Offset(0, delta) : Offset(delta, 0),
            child: CustomPaint(
              size: Size.square(side),
              painter: _ArrowPainter(widget.axis, widget.forward, widget.color),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.axis, this.forward, this.color);
  final Axis axis;
  final bool forward;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    switch ((axis, forward)) {
      case (Axis.vertical, false):
        path
          ..moveTo(w / 2, h * .25)
          ..lineTo(w, h * .72)
          ..lineTo(0, h * .72);
      case (Axis.vertical, true):
        path
          ..moveTo(w / 2, h * .75)
          ..lineTo(w, h * .28)
          ..lineTo(0, h * .28);
      case (Axis.horizontal, false):
        path
          ..moveTo(w * .25, h / 2)
          ..lineTo(w * .72, 0)
          ..lineTo(w * .72, h);
      case (Axis.horizontal, true):
        path
          ..moveTo(w * .75, h / 2)
          ..lineTo(w * .28, 0)
          ..lineTo(w * .28, h);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      axis != oldDelegate.axis || forward != oldDelegate.forward || color != oldDelegate.color;
}
