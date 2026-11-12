part of 'index.dart';

/// 固定占据轨道空间、两端带箭头的 Windows 滚动条。
class ElWindowsScrollbar extends StatelessWidget {
  /// 创建 Windows 占位滚动条。
  const ElWindowsScrollbar({
    super.key,
    this.controller,
    this.direction = AxisDirection.down,
    this.notificationDepth = 0,
    this.extent = 15,
    this.thickness = 9,
    this.radius = 9999,
    this.minThumbLength = 17,
    this.thumbColor,
    this.thumbHoverColor,
    this.thumbActiveColor,
    this.trackColor,
    this.arrowColor,
    this.arrowExtent = 18,
    this.arrowSize = 9,
    required this.child,
  }) : assert(extent > 0),
       assert(thickness > 0 && thickness <= extent),
       assert(radius >= 0),
       assert(minThumbLength > 0),
       assert(notificationDepth >= 0),
       assert(arrowExtent > 0),
       assert(arrowSize > 0 && arrowSize <= extent && arrowSize <= arrowExtent);

  /// 与内容共享的官方控制器，缺省使用最近的 PrimaryScrollController。
  final ScrollController? controller;

  /// 滚动轴方向，纵向条位于右侧，横向条位于底部。
  final AxisDirection direction;

  /// 被监听滚动视图相对 child 的嵌套深度。
  final int notificationDepth;

  /// 滚动条占位和命中区域的宽度。
  final double extent;

  /// 滑块的可见宽度，两侧留白仍属于滑块拖动区域。
  final double thickness;

  /// 滑块圆角半径，默认呈胶囊形。
  final double radius;

  /// 滑块的最小长度。
  final double minThumbLength;

  /// 滑块的默认颜色，缺省随系统明暗模式变化。
  final Color? thumbColor;

  /// 鼠标悬停滑块时的颜色。
  final Color? thumbHoverColor;

  /// 拖动滑块时的颜色，缺省沿用悬停颜色。
  final Color? thumbActiveColor;

  /// 轨道背景颜色。
  final Color? trackColor;

  /// 两端箭头的颜色，缺省沿用滑块默认颜色。
  final Color? arrowColor;

  /// 每个箭头区域沿滚动轴的长度。
  final double arrowExtent;

  /// 箭头图案的大小，按下时自动缩小。
  final double arrowSize;

  /// 被滚动条包装的内容。
  final Widget child;

  @override
  Widget build(BuildContext context) => _buildScrollbar(
    context,
    occupiesSpace: true,
    controller: controller,
    direction: direction,
    notificationDepth: notificationDepth,
    extent: extent,
    thickness: thickness,
    radius: radius,
    minThumbLength: minThumbLength,
    thumbColor: thumbColor,
    thumbHoverColor: thumbHoverColor,
    thumbActiveColor: thumbActiveColor,
    trackColor: trackColor,
    arrowColor: arrowColor,
    arrowExtent: arrowExtent,
    arrowSize: arrowSize,
    child: child,
  );
}

class _ArrowButton extends StatefulWidget {
  const _ArrowButton({
    required this.controller,
    required this.axis,
    required this.forward,
    required this.color,
    required this.size,
  });
  final ScrollController? controller;
  final Axis axis;
  final bool forward;
  final Color color;
  final double size;

  @override
  State<_ArrowButton> createState() => _ArrowButtonState();
}

class _ArrowButtonState extends State<_ArrowButton> with SingleTickerProviderStateMixin {
  Timer? _timer;
  int? _pointer;
  late final _ticker = createTicker(_tick);
  Duration _lastTick = Duration.zero;

  void _tick(Duration elapsed) {
    final delta = elapsed - _lastTick;
    _lastTick = elapsed;
    // 保留原来每 50ms 一个步长的速度，但按实际帧间隔连续推进。
    if (delta > Duration.zero) _step(steps: delta.inMicroseconds / 50000);
  }

  void _step({bool animate = false, double steps = 1}) {
    final controller = widget.controller ?? PrimaryScrollController.maybeOf(context);
    if (controller == null || controller.positions.length != 1) return;
    final position = controller.position;
    if (!position.hasContentDimensions || !position.physics.shouldAcceptUserOffset(position)) return;
    final direction = (widget.forward ? 1.0 : -1.0) * (axisDirectionIsReversed(position.axisDirection) ? -1 : 1);
    final target = (position.pixels + position.viewportDimension.clamp(160.0, 480.0) * 0.1 * direction * steps).clamp(
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
      _timer = null;
      _lastTick = Duration.zero;
      _ticker.start();
    });
  }

  void _stop() {
    _ticker.stop();
    _timer?.cancel();
    _timer = null;
    if (_pointer != null) setState(() => _pointer = null);
  }

  @override
  void deactivate() {
    _ticker.stop();
    _timer?.cancel();
    _timer = null;
    _pointer = null;
    super.deactivate();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.axis == Axis.vertical
        ? (widget.forward ? '向下滚动' : '向上滚动')
        : (widget.forward ? '向右滚动' : '向左滚动');
    final side = widget.size * (_pointer == null ? 1 : 7 / 9);
    final delta = widget.forward ? 1.0 : -1.0;
    return Semantics(
      button: true,
      label: label,
      onTap: () => _step(animate: true),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerSignal: (event) => _routeWheel(context, widget.controller, event),
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
