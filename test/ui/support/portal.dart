import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';

/// 为业务测试提供一个声明式浮层槽，不维护层序或 entry 账本。
class ElTestPortal extends StatefulWidget {
  /// 创建保留原位正文的单浮层测试槽。
  const ElTestPortal({super.key, required this.child});

  /// 浮层触发物所在的正文。
  final Widget child;

  /// 查找正文所属的测试槽。
  static ElTestPortalState of(BuildContext context) => context.findAncestorStateOfType<ElTestPortalState>()!;

  @override
  State<ElTestPortal> createState() => ElTestPortalState();
}

/// 仅负责给实际 ElPopup 配置测试面板。
class ElTestPortalState extends State<ElTestPortal> {
  final _controller = ElPopupController();
  final _scope = FocusScopeNode(debugLabel: 'ElTestPortal');
  WidgetBuilder _builder = (_) => SizedBox.shrink();
  AlignmentGeometry _align = Alignment.center;
  Offset _offset = Offset.zero;
  Duration _exitDuration = Duration.zero;
  bool _escape = false;

  /// 配置并打开本槽的面板；嵌套面板的寿命由声明式子树决定。captureFocus 时打开后把焦点移进面板。
  ElPopupController show({
    required WidgetBuilder builder,
    AlignmentGeometry align = Alignment.center,
    Offset offset = Offset.zero,
    Duration exitDuration = Duration.zero,
    bool captureFocus = true,
    bool closeOnEscape = false,
  }) {
    setState(() {
      _builder = builder;
      _align = align;
      _offset = offset;
      _exitDuration = exitDuration;
      _escape = closeOnEscape;
    });
    _controller.open();
    if (captureFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.isOpen && _scope.context != null) _scope.requestFocus();
      });
    }
    return _controller;
  }

  @override
  Widget build(BuildContext context) => ElPopup(
    controller: _controller,
    trigger: const {},
    anchor: _ViewportAnchor(_align.resolve(Directionality.of(context)), _offset),
    closeOnOutsideTap: false,
    closeOnEscape: _escape,
    // 关闭后按 exitDuration 完整保持挂载，模拟品牌退场；进场立即完成，进场途中关闭也保活满时长。
    builder: (context) => ElOverlayTransition(
      duration: Duration.zero,
      reverseDuration: _exitDuration,
      builder: (context, _) => FocusScope(
        node: _scope,
        child: ElTestPortal(child: _builder(context)),
      ),
    ),
    child: widget.child,
  );

  @override
  void dispose() {
    _controller.dispose();
    _scope.dispose();
    super.dispose();
  }
}

/// 非锚定业务用例显式按视口定位，布局和挂载仍由 ElPopup 执行。
class _ViewportAnchor extends ElOverlayAnchor {
  const _ViewportAnchor(this.align, this.offsetInViewport) : super(viewportPadding: 0);
  final Alignment align;
  final Offset offsetInViewport;

  @override
  ElOverlayAnchorGeometry resolve(Rect anchorRect, Size childSize, Rect viewport) => (
    placement: ElPlacement.bottomStart,
    arrowTarget: Offset.zero,
    anchorRect: anchorRect,
    overlayRect:
        (viewport.topLeft +
            align.alongOffset(Offset(viewport.width - childSize.width, viewport.height - childSize.height)) +
            offsetInViewport) &
        childSize,
  );

  @override
  BoxConstraints constraints(Rect anchorRect, Rect viewport) => BoxConstraints.loose(viewport.size);
}
