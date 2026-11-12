import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../selection/common/selection_boundary.dart' show SelectionGeometryObserver, SelectionItemVisibility;
import 'scroll_position.dart' show ScrollHostPosition;

/// 跨 [ScrollPosition] 换绑存活的滚动偏移监听通道。
///
/// Scrollable 在依赖或物理变化时会重建 ScrollPosition 实例，长期监听直接挂在旧实例上
/// 会在换绑后失聪；视口持有本中继并在 offset 换绑时转接。
class ScrollOffsetRelay extends ChangeNotifier {
  /// 视口在滚动偏移变化时转发。
  void notify() => notifyListeners();
}

/// 自己驱动滚动中选择的选区注册器，例如 ElSelectionView 的文档。
///
/// 官方 Scrollable 遇到选区注册器会再套一层自带的选区容器：文本按无分隔符拼接，并自行驱动拖选滚动。
/// 实现本接口的注册器已承担这些职责，ElScrollView 让视口内容直接登记到它，与普通内容共享文档序。
abstract interface class ScrollTransparentSelectionRegistrar implements SelectionRegistrar {}

/// 选区、编辑器与拖放共用的滚动视口能力，由 ElScrollView 的官方视口子类实现。
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

  /// 选区自动滚动：按滚动位置方向的增量滚动（调用方已处理反向轴），返回实际移动的像素。
  double applySelectionAutoScrollDelta(double delta);

  /// 内容区拖拽滚动认领的 pointer 种类。
  Set<PointerDeviceKind> get effectiveContentDragDevices;
}

/// 在官方视口上实现 [ScrollViewport]。
mixin _ScrollViewportMixin<P extends ContainerParentDataMixin<RenderSliver>> on RenderViewportBase<P>
    implements ScrollViewport, SelectionItemVisibility {
  final _relay = ScrollOffsetRelay();
  Set<PointerDeviceKind> _dragDevices = const {};
  SelectionGeometryObserver? _selectionObserver;
  double? _laidOutPixels;

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
    _selectionObserver = null;
    for (RenderObject? node = parent; node != null; node = node.parent) {
      if (node is SelectionGeometryObserver) {
        _selectionObserver = node as SelectionGeometryObserver;
        break;
      }
    }
  }

  @override
  void detach() {
    offset.removeListener(_relay.notify);
    _selectionObserver = null;
    super.detach();
  }

  @override
  void performLayout() {
    // 框选拖动中新挂载的对象要在本帧绘制前登记几何；登记改变选中样式时重新布局。
    // 观察方要读取子项尺寸并同步选中样式，放在布局回调里执行才允许这些读写。
    var changed = false;
    do {
      super.performLayout();
      _laidOutPixels = offset.hasPixels ? offset.pixels : null;
      final observer = _selectionObserver;
      if (observer == null) return;
      invokeLayoutCallback<BoxConstraints>((_) => changed = observer.selectionLayoutChanged());
    } while (changed);
  }

  /// 偏移已变、视口尚未重新布局时，子项几何仍停在上次布局；按待生效的偏移差补上，
  /// 让选区端点、句柄与拖放在滚动的同一帧读到新位置，布局后差值归零。
  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    super.applyPaintTransform(child, transform);
    final laidOut = _laidOutPixels;
    if (laidOut == null || !offset.hasPixels) return;
    final shift = laidOut - offset.pixels;
    if (shift == 0) return;
    switch (axisDirection) {
      case AxisDirection.down:
        transform.translateByDouble(0, shift, 0, 1);
      case AxisDirection.up:
        transform.translateByDouble(0, -shift, 0, 1);
      case AxisDirection.right:
        transform.translateByDouble(shift, 0, 0, 1);
      case AxisDirection.left:
        transform.translateByDouble(-shift, 0, 0, 1);
    }
  }

  /// 官方 Sliver 会保留缓存区与恰好贴边的子项；只有与视口及祖先裁剪有交集的才算可见。
  @override
  bool isSelectionItemAvailable(RenderObject descendant, {required bool visibleOnly}) {
    if (!descendant.attached || descendant is! RenderBox || !descendant.hasSize) return false;
    if (!visibleOnly) return true;
    var bounds = MatrixUtils.transformRect(
      descendant.getTransformTo(this),
      Offset.zero & descendant.size,
    ).intersect(contentViewportRect);
    if (bounds.isEmpty) return false;
    RenderObject child = this;
    for (RenderObject? ancestor = parent; ancestor != null; ancestor = ancestor.parent) {
      bounds = MatrixUtils.transformRect(child.getTransformTo(ancestor), bounds);
      final clip = ancestor.describeApproximatePaintClip(child);
      if (clip != null) bounds = bounds.intersect(clip);
      if (bounds.isEmpty) return false;
      child = ancestor;
    }
    return true;
  }

  @override
  void dispose() {
    _relay.dispose();
    super.dispose();
  }

  // 仅不透明宿主认领空白区域，同时让框选、拖放能从命中点沿父链找到视口。
  @override
  bool hitTestSelf(Offset position) => acceptsEmptyHit;

  bool acceptsEmptyHit = true;

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
    final target = (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    final applied = target - position.pixels;
    if (applied.abs() <= precisionErrorTolerance) return 0;
    position.jumpTo(target);
    return applied;
  }
}

/// ElScrollView 使用的官方视口，附带选区与拖放需要的滚动能力。
class ElRenderViewport extends RenderViewport with _ScrollViewportMixin<SliverPhysicalContainerParentData> {
  /// 创建视口。
  ElRenderViewport({
    super.anchor,
    super.axisDirection,
    required super.crossAxisDirection,
    required super.offset,
    super.scrollCacheExtent,
    super.clipBehavior,
    super.paintOrder,
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
    super.paintOrder,
  });
}

/// 创建 [ElRenderViewport] 的官方 Viewport。
class ElViewport extends Viewport {
  /// 创建视口。
  ElViewport({
    super.center,
    super.anchor,
    this.dragDevices,
    this.hitTestBehavior = HitTestBehavior.opaque,
    super.key,
    super.axisDirection,
    required super.offset,
    super.scrollCacheExtent,
    super.clipBehavior,
    super.paintOrder,
    super.slivers,
  });

  /// 可发起拖动的设备，缺省读取环境滚动配置。
  final Set<PointerDeviceKind>? dragDevices;

  /// 空白视口的命中行为。
  final HitTestBehavior hitTestBehavior;

  @override
  RenderViewport createRenderObject(BuildContext context) =>
      ElRenderViewport(
          anchor: anchor,
          axisDirection: axisDirection,
          crossAxisDirection: crossAxisDirection ?? Viewport.getDefaultCrossAxisDirection(context, axisDirection),
          offset: offset,
          scrollCacheExtent: scrollCacheExtent,
          clipBehavior: clipBehavior,
          paintOrder: paintOrder,
        )
        ..dragDevices = dragDevices ?? ScrollConfiguration.of(context).dragDevices
        ..acceptsEmptyHit = hitTestBehavior == HitTestBehavior.opaque;

  @override
  void updateRenderObject(BuildContext context, RenderViewport renderObject) {
    super.updateRenderObject(context, renderObject);
    (renderObject as ElRenderViewport)
      ..dragDevices = dragDevices ?? ScrollConfiguration.of(context).dragDevices
      ..acceptsEmptyHit = hitTestBehavior == HitTestBehavior.opaque;
  }
}

/// 创建 [ElRenderShrinkWrappingViewport] 的官方 ShrinkWrappingViewport。
class ElShrinkWrappingViewport extends ShrinkWrappingViewport {
  /// 创建视口。
  const ElShrinkWrappingViewport({
    this.dragDevices,
    this.hitTestBehavior = HitTestBehavior.opaque,
    super.key,
    super.axisDirection,
    required super.offset,
    super.scrollCacheExtent,
    super.clipBehavior,
    super.paintOrder,
    super.slivers,
  });

  /// 可发起拖动的设备，缺省读取环境滚动配置。
  final Set<PointerDeviceKind>? dragDevices;

  /// 空白视口的命中行为。
  final HitTestBehavior hitTestBehavior;

  @override
  RenderShrinkWrappingViewport createRenderObject(BuildContext context) =>
      ElRenderShrinkWrappingViewport(
          axisDirection: axisDirection,
          crossAxisDirection: crossAxisDirection ?? Viewport.getDefaultCrossAxisDirection(context, axisDirection),
          offset: offset,
          scrollCacheExtent: scrollCacheExtent,
          clipBehavior: clipBehavior,
          paintOrder: paintOrder,
        )
        ..dragDevices = dragDevices ?? ScrollConfiguration.of(context).dragDevices
        ..acceptsEmptyHit = hitTestBehavior == HitTestBehavior.opaque;

  @override
  void updateRenderObject(BuildContext context, RenderShrinkWrappingViewport renderObject) {
    super.updateRenderObject(context, renderObject);
    (renderObject as ElRenderShrinkWrappingViewport)
      ..dragDevices = dragDevices ?? ScrollConfiguration.of(context).dragDevices
      ..acceptsEmptyHit = hitTestBehavior == HitTestBehavior.opaque;
  }
}
