import 'package:flutter/gestures.dart' show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/widgets.dart';

import '../../views/layout/stack/stack_view.dart' show ElStackView;
import '../../views/scroll/scrollbar/scrollbar_base.dart' show ElNoScrollBar, ElScrollbar;
import '../../views/scroll/scrollbar/scrollbar_controller.dart' show ScrollbarController;

/// 将桌面端现有 ElScrollbar 条带安装到官方 Scrollable 之外。
///
/// 沿用旧滚动条的轨道、滑块、步进按钮与手势，实现只依赖标准 ScrollPosition。
Widget buildElDesktopScrollbar({
  required Widget child,
  required ScrollController controller,
  required AxisDirection direction,
  required ElScrollbar scrollbar,
}) {
  if (scrollbar is ElNoScrollBar) return child;
  return _DesktopScrollbarHost(controller: controller, axisDirection: direction, scrollbar: scrollbar, child: child);
}

class _DesktopScrollbarHost extends StatefulWidget {
  const _DesktopScrollbarHost({
    required this.controller,
    required this.axisDirection,
    required this.scrollbar,
    required this.child,
  });

  final ScrollController controller;
  final AxisDirection axisDirection;
  final ElScrollbar scrollbar;
  final Widget child;

  @override
  State<_DesktopScrollbarHost> createState() => _DesktopScrollbarHostState();
}

class _DesktopScrollbarHostState extends State<_DesktopScrollbarHost> {
  late final ScrollbarController _details;

  ScrollPosition? get _position {
    if (!widget.controller.hasClients) return null;
    for (final position in widget.controller.positions) {
      if (position.axis == axisDirectionToAxis(widget.axisDirection)) return position;
    }
    return null;
  }

  void _bindPosition() {
    final position = _position;
    _details.updatePositions(
      verticalPosition: position?.axis == Axis.vertical ? position : null,
      horizontalPosition: position?.axis == Axis.horizontal ? position : null,
    );
  }

  @override
  void initState() {
    super.initState();
    _details = ScrollbarController(
      verticalPosition: null,
      horizontalPosition: null,
      dispatchPointerSignal: _dispatchPointerSignal,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindPosition();
  }

  @override
  void didUpdateWidget(_DesktopScrollbarHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindPosition();
  }

  bool _dispatchPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return false;
    final position = _position;
    if (position == null || !position.hasContentDimensions) return false;
    final delta = position.axis == Axis.vertical ? event.scrollDelta.dy : event.scrollDelta.dx;
    if (delta == 0.0) return false;
    position.pointerScroll(axisDirectionIsReversed(position.axisDirection) ? -delta : delta);
    event.respond(allowPlatformDefault: false);
    return true;
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    if (position != null && _details[position.axis] == null) {
      // 首帧 Scrollable 可能在 parent.didChangeDependencies 之后才挂 position。
      // 这里仅同步 controller 的监听关系，metrics 的推迟通知由 _details 自己负责。
      _bindPosition();
    }
    final axis = axisDirectionToAxis(widget.axisDirection);
    final inset = widget.scrollbar.resolveInsetExtent(context, axis);
    final orientation = widget.scrollbar.resolveOrientation(context, axis);
    final leading = orientation == ScrollbarOrientation.left || orientation == ScrollbarOrientation.top;
    final padding = axis == Axis.vertical
        ? (leading ? EdgeInsets.only(left: inset) : EdgeInsets.only(right: inset))
        : (leading ? EdgeInsets.only(top: inset) : EdgeInsets.only(bottom: inset));
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) _details.refresh();
        return false;
      },
      child: ListenableBuilder(
        listenable: _details,
        child: Padding(padding: padding, child: widget.child),
        builder: (context, child) =>
            ElStackView(fit: StackFit.expand, children: [child!, ...widget.scrollbar.buildChildren(context, _details)]),
      ),
    );
  }
}
