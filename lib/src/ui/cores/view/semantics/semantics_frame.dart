import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

import '../render/render_view.dart';
import '../render/hit_bounds.dart';

/// 将容器语义放在可见盒原点，避免 Windows 重复叠加父矩形的外边距。
class ViewSemanticsFrame extends SingleChildRenderObjectWidget {
  const ViewSemanticsFrame({super.key, required this.host, required super.child});

  final ElRenderView host;

  @override
  RenderViewSemanticsFrame createRenderObject(BuildContext context) => RenderViewSemanticsFrame(host);
}

/// 布局仍按内容测量，语义边界和后代变换共用可见盒坐标系。
class RenderViewSemanticsFrame extends RenderShiftedBox with ElOverflowHitBounds {
  RenderViewSemanticsFrame(this.host) : super(null);

  final ElRenderView host;
  Size _boxSize = Size.zero;
  Offset _contentOffset = Offset.zero;

  void updateGeometry(Size boxSize, Offset contentOffset) {
    if (_boxSize == boxSize && _contentOffset == contentOffset) return;
    _boxSize = boxSize;
    _contentOffset = contentOffset;
    markHitBoundsDirty();
    if (child case final child?) (child.parentData! as BoxParentData).offset = contentOffset;
    markNeedsSemanticsUpdate();
  }

  @override
  void performLayout() {
    markHitBoundsDirty();
    size = (child?..layout(constraints, parentUsesSize: true))?.size ?? constraints.smallest;
    if (child case final child?) (child.parentData! as BoxParentData).offset = _contentOffset;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => child?.getDryLayout(constraints) ?? constraints.smallest;

  @override
  Rect get semanticBounds => Offset.zero & _boxSize;

  @override
  Rect get paintBounds => semanticBounds;

  @override
  Rect get selfHitRect => semanticBounds;

  @override
  bool get clipsHitBounds => false;

  @override
  void visitHitBoundsChildren(void Function(RenderBox child, Offset offset) visitor) {
    if (child case final child?) visitor(child, _contentOffset);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) => host.describeContainerSemantics(config);

  @override
  void assembleSemanticsNode(SemanticsNode node, SemanticsConfiguration config, Iterable<SemanticsNode> children) {
    // 部分裁剪不能改写容器坐标原点；可见性和命中仍由祖先视口约束。
    node.rect = semanticBounds;
    super.assembleSemanticsNode(node, config, children);
  }

  /// 语义坐标框不截断可见子内容，也不为自身追加命中项。
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => hitTestChildren(result, position: position);
}
