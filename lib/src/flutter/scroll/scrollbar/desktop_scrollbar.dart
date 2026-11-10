import 'package:flutter/gestures.dart' show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/widgets.dart';

import '../../views/layout/stack/stack_view.dart' show ElStackView;
import 'mac_scroll_bar.dart' show ElMacScrollBar;
import 'scrollbar_base.dart' show ElScrollbar;
import 'scrollbar_controller.dart' show ScrollbarController;
import 'window_scroll_bar.dart' show ElWindowScrollBar;

/// 在官方 Scrollable 外安装桌面滚动条的交互与平台外观。
///
/// 轨道按下即跳转到对应位置并可继续拖动，滑块按下立即接管滚动；
/// Windows 使用常驻轨道、步进按钮和布局占位，macOS 使用悬浮、自动隐藏条带。
/// 滚动位置来自官方 ScrollController。
class ElDesktopScrollbar extends StatelessWidget {
  /// 创建 Windows 风格的桌面滚动条。
  const ElDesktopScrollbar.windows({
    super.key,
    required this.controller,
    required this.direction,
    this.notificationDepth = 0,
    required this.child,
  }) : _style = _ScrollbarStyle.windows;

  /// 创建 macOS 风格的桌面滚动条。
  const ElDesktopScrollbar.mac({
    super.key,
    required this.controller,
    required this.direction,
    this.notificationDepth = 0,
    required this.child,
  }) : _style = _ScrollbarStyle.mac;

  /// 关联当前 Scrollable 的真实滚动位置。
  final ScrollController controller;

  /// 当前滚动轴方向。
  final AxisDirection direction;

  /// 所跟随 Scrollable 相对 [child] 的嵌套层数；滚动条钉在外层视口边缘时大于 0。
  final int notificationDepth;

  /// 被滚动条包裹的 Scrollable。
  final Widget child;

  final _ScrollbarStyle _style;

  @override
  Widget build(BuildContext context) => _DesktopScrollbarHost(
    controller: controller,
    axisDirection: direction,
    notificationDepth: notificationDepth,
    scrollbar: switch (_style) {
      _ScrollbarStyle.windows => const ElWindowScrollBar(),
      _ScrollbarStyle.mac => const ElMacScrollBar(),
    },
    child: child,
  );
}

enum _ScrollbarStyle { windows, mac }

/// 轨道、滑块、步进按钮与手势由同目录的滚动条模块提供，只依赖标准 ScrollPosition。
class _DesktopScrollbarHost extends StatefulWidget {
  const _DesktopScrollbarHost({
    required this.controller,
    required this.axisDirection,
    required this.notificationDepth,
    required this.scrollbar,
    required this.child,
  });

  final ScrollController controller;
  final AxisDirection axisDirection;
  final int notificationDepth;
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
        if (notification.depth == widget.notificationDepth) _details.refresh();
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
