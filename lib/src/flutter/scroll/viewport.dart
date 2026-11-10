import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'scroll_position.dart' show ScrollHostPosition;

/// 跨 [ScrollPosition] 换绑存活的滚动偏移监听通道。
///
/// Scrollable 在依赖或物理变化时会重建 ScrollPosition 实例，长期监听直接挂在旧实例上
/// 会在换绑后失聪；视口持有本中继并在 offset 换绑时转接。
class ScrollOffsetRelay extends ChangeNotifier {
  /// 视口在滚动偏移变化时转发。
  void notify() => notifyListeners();
}

/// 选区、编辑器与拖放共用的滚动视口能力，由 ElScroll 的官方视口子类实现。
abstract interface class ScrollViewport implements RenderBox {
  /// 当前滚动位置。
  ScrollPosition get position;

  /// 滚动偏移变更的稳定监听通道，长期监听必须挂这里而不是 `position.addListener`。
  Listenable get scrollOffsetListenable;

  /// 滚动主轴。
  Axis get axis;

  /// 滚动方向。
  AxisDirection get axisDirection;

  /// 正文可滚动区域的本地矩形。
  Rect get contentViewportRect;

  /// 选区拖动期间把命中的滚轮信号交给本视口滚动。
  bool dispatchSelectionPointerSignal(PointerSignalEvent event);

  /// 选区自动滚动：按屏幕方向的增量滚动，返回实际移动的像素。
  double applySelectionAutoScrollDelta(double delta);

  /// 内容区拖拽滚动认领的 pointer 种类。
  Set<PointerDeviceKind> get effectiveContentDragDevices;
}

/// 在官方视口上实现 [ScrollViewport]。
mixin _ScrollViewportMixin<P extends ContainerParentDataMixin<RenderSliver>> on RenderViewportBase<P>
    implements ScrollViewport {
  final _relay = ScrollOffsetRelay();
  Set<PointerDeviceKind> _dragDevices = const {};

  @override
  ScrollPosition get position => offset as ScrollPosition;

  @override
  Listenable get scrollOffsetListenable => _relay;

  @override
  Rect get contentViewportRect => Offset.zero & size;

  @override
  Set<PointerDeviceKind> get effectiveContentDragDevices => _dragDevices;

  set dragDevices(Set<PointerDeviceKind> value) => _dragDevices = value;

  @override
  set offset(ViewportOffset value) {
    final previous = offset;
    if (identical(previous, value)) return;
    if (attached) previous.removeListener(_relay.notify);
    super.offset = value;
    if (attached) value.addListener(_relay.notify);
    // 新位置可能已经处在不同偏移，监听方需要按新实例重新同步。
    _relay.notify();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    offset.addListener(_relay.notify);
  }

  @override
  void detach() {
    offset.removeListener(_relay.notify);
    super.detach();
  }

  @override
  void dispose() {
    _relay.dispose();
    super.dispose();
  }

  @override
  bool dispatchSelectionPointerSignal(PointerSignalEvent event) {
    final position = offset;
    if (position is! ScrollHostPosition) return false;
    if (event is PointerScrollInertiaCancelEvent) {
      position.cancelPointerScroll();
      return true;
    }
    return event is PointerScrollEvent && position.handlePointerSignal(event);
  }

  @override
  double applySelectionAutoScrollDelta(double delta) {
    final position = offset;
    if (position is! ScrollPosition || !position.hasPixels || !position.hasContentDimensions) return 0;
    final pixelDelta = axisDirectionIsReversed(axisDirection) ? -delta : delta;
    final target = (position.pixels + pixelDelta).clamp(position.minScrollExtent, position.maxScrollExtent);
    final applied = target - position.pixels;
    if (applied.abs() <= precisionErrorTolerance) return 0;
    position.jumpTo(target);
    return applied;
  }
}

/// ElScroll 使用的官方视口，附带选区与拖放需要的滚动能力。
class ElRenderViewport extends RenderViewport with _ScrollViewportMixin<SliverPhysicalContainerParentData> {
  /// 创建视口。
  ElRenderViewport({
    super.axisDirection,
    required super.crossAxisDirection,
    required super.offset,
    super.scrollCacheExtent,
    super.clipBehavior,
  });
}

/// shrinkWrap 时使用的官方视口，能力同 [ElRenderViewport]。
class ElRenderShrinkWrappingViewport extends RenderShrinkWrappingViewport
    with _ScrollViewportMixin<SliverLogicalContainerParentData> {
  /// 创建视口。
  ElRenderShrinkWrappingViewport({
    super.axisDirection,
    required super.crossAxisDirection,
    required super.offset,
    super.scrollCacheExtent,
    super.clipBehavior,
  });
}

/// 创建 [ElRenderViewport] 的官方 Viewport。
class ElViewport extends Viewport {
  /// 创建视口。
  ElViewport({
    super.key,
    super.axisDirection,
    required super.offset,
    super.scrollCacheExtent,
    super.clipBehavior,
    super.slivers,
  });

  @override
  RenderViewport createRenderObject(BuildContext context) => ElRenderViewport(
    axisDirection: axisDirection,
    crossAxisDirection: crossAxisDirection ?? Viewport.getDefaultCrossAxisDirection(context, axisDirection),
    offset: offset,
    scrollCacheExtent: scrollCacheExtent,
    clipBehavior: clipBehavior,
  )..dragDevices = ScrollConfiguration.of(context).dragDevices;

  @override
  void updateRenderObject(BuildContext context, RenderViewport renderObject) {
    super.updateRenderObject(context, renderObject);
    (renderObject as ElRenderViewport).dragDevices = ScrollConfiguration.of(context).dragDevices;
  }
}

/// 创建 [ElRenderShrinkWrappingViewport] 的官方 ShrinkWrappingViewport。
class ElShrinkWrappingViewport extends ShrinkWrappingViewport {
  /// 创建视口。
  const ElShrinkWrappingViewport({
    super.key,
    super.axisDirection,
    required super.offset,
    super.scrollCacheExtent,
    super.clipBehavior,
    super.slivers,
  });

  @override
  RenderShrinkWrappingViewport createRenderObject(BuildContext context) => ElRenderShrinkWrappingViewport(
    axisDirection: axisDirection,
    crossAxisDirection: crossAxisDirection ?? Viewport.getDefaultCrossAxisDirection(context, axisDirection),
    offset: offset,
    scrollCacheExtent: scrollCacheExtent,
    clipBehavior: clipBehavior,
  )..dragDevices = ScrollConfiguration.of(context).dragDevices;

  @override
  void updateRenderObject(BuildContext context, RenderShrinkWrappingViewport renderObject) {
    super.updateRenderObject(context, renderObject);
    (renderObject as ElRenderShrinkWrappingViewport).dragDevices = ScrollConfiguration.of(context).dragDevices;
  }
}
