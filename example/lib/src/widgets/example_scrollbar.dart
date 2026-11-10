import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/// 为官方与回收列表接入可直接拖拽的 iOS 风格滚动条。
class RecyclerExampleScrollbar extends StatelessWidget {
  /// 使用列表自身的控制器关联真实滚动位置。
  // ignore: prefer_const_constructors_in_immutables
  RecyclerExampleScrollbar({super.key, required this.controller, required this.child, this.stopOnThumbRelease = false});

  /// 与当前列表共用且仅连接一个位置的控制器。
  final ScrollController controller;

  /// 当前选择的列表容器。
  final Widget child;

  /// 松开滑块时停在当前滚动位置，列表本身仍使用原有惯性。
  final bool stopOnThumbRelease;

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    // 平台自动滚动条与显式 CupertinoScrollbar 只能保留一份。
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: stopOnThumbRelease
        ? _DirectThumbScrollbar(controller: controller, child: child)
        : CupertinoScrollbar(controller: controller, thumbVisibility: true, child: child),
  );
}

class _DirectThumbScrollbar extends CupertinoScrollbar {
  const _DirectThumbScrollbar({required super.controller, required super.child}) : super(thumbVisibility: true);

  @override
  RawScrollbarState<CupertinoScrollbar> createState() => _DirectThumbScrollbarState();
}

class _DirectThumbScrollbarState extends RawScrollbarState<CupertinoScrollbar> {
  static const _color = CupertinoDynamicColor.withBrightness(color: Color(0x59000000), darkColor: Color(0x80ffffff));

  late final AnimationController _resize;
  Offset? _pressStart;

  @override
  void initState() {
    super.initState();
    _resize = AnimationController(vsync: this, duration: Duration(milliseconds: 100))
      ..addListener(updateScrollbarPainter);
  }

  @override
  void updateScrollbarPainter() {
    // Cupertino 的状态类是私有的，保留其几何和按住时的视觉反馈。
    final progress = _resize.value;
    final thickness = widget.thickness!;
    scrollbarPainter
      ..color = CupertinoDynamicColor.resolve(_color, context)
      ..textDirection = Directionality.of(context)
      ..thickness = thickness + progress * (widget.thicknessWhileDragging - thickness)
      ..radius = Radius.lerp(widget.radius, widget.radiusWhileDragging, progress)
      ..mainAxisMargin = widget.mainAxisMargin
      ..crossAxisMargin = 3
      ..padding = MediaQuery.paddingOf(context)
      ..minLength = 36
      ..minOverscrollLength = 8
      ..scrollbarOrientation = widget.scrollbarOrientation;
  }

  @override
  void handleThumbPress() {
    if (getScrollbarDirection() == null) return;
    super.handleThumbPress();
    _resize.forward().then<void>((_) => HapticFeedback.mediumImpact());
  }

  @override
  void handleThumbPressStart(Offset localPosition) {
    super.handleThumbPressStart(localPosition);
    _pressStart = localPosition;
  }

  @override
  void handleThumbPressEnd(Offset localPosition, Velocity velocity) {
    final delta = localPosition - (_pressStart ?? localPosition);
    _pressStart = null;
    _resize.reverse();
    super.handleThumbPressEnd(localPosition, Velocity.zero);
    final speed = velocity.pixelsPerSecond;
    final stoppedAfterMoving = switch (getScrollbarDirection()) {
      .horizontal => delta.dx != 0 && speed.dx.abs() < 10,
      .vertical => delta.dy != 0 && speed.dy.abs() < 10,
      null => false,
    };
    if (stoppedAfterMoving) HapticFeedback.mediumImpact();
  }

  @override
  void handleTrackTapDown(TapDownDetails details) {
    if (ScrollConfiguration.of(context).getPlatform(context) != .iOS) super.handleTrackTapDown(details);
  }

  @override
  void dispose() {
    _resize.dispose();
    super.dispose();
  }
}
