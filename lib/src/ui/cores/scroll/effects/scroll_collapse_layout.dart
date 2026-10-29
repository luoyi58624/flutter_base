part of '../virtual/virtual_pipeline.dart';

// 只测量效果自己的两个正常 Widget，裁剪后的展示尺寸不作为下一帧的自然端点。
class _ScrollCollapseLayout extends MultiChildRenderObjectWidget {
  const _ScrollCollapseLayout({
    required this.axis,
    required this.progress,
    required this.onRangeChanged,
    required super.children,
  });
  final Axis axis;
  final double progress;
  final ValueChanged<double> onRangeChanged;

  @override
  _RenderScrollCollapseLayout createRenderObject(BuildContext context) =>
      _RenderScrollCollapseLayout(axis, progress, onRangeChanged);

  @override
  void updateRenderObject(BuildContext context, _RenderScrollCollapseLayout renderObject) {
    renderObject.update(axis, progress, onRangeChanged);
  }
}

class _CollapseParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderScrollCollapseLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, ContainerBoxParentData<RenderBox>>,
        RenderBoxContainerDefaultsMixin<RenderBox, ContainerBoxParentData<RenderBox>> {
  _RenderScrollCollapseLayout(this._axis, this._progress, this._onRangeChanged);
  Axis _axis;
  double _progress;
  ValueChanged<double> _onRangeChanged;
  double? _reportedRange;
  int _reportGeneration = 0;

  void update(Axis axis, double progress, ValueChanged<double> onRangeChanged) {
    _onRangeChanged = onRangeChanged;
    if (_axis == axis && _progress == progress) return;
    _axis = axis;
    _progress = progress;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CollapseParentData) child.parentData = _CollapseParentData();
  }

  double _main(Size size) => _axis == .vertical ? size.height : size.width;
  double _cross(Size size) => _axis == .vertical ? size.width : size.height;

  @override
  void performLayout() {
    final natural = _axis == .vertical
        ? constraints.copyWith(minHeight: 0, maxHeight: double.infinity)
        : constraints.copyWith(minWidth: 0, maxWidth: double.infinity);
    final expanded = firstChild!;
    final collapsed = childAfter(expanded);
    expanded.layout(natural, parentUsesSize: true);
    collapsed?.layout(natural, parentUsesSize: true);
    final expandedExtent = _main(expanded.size);
    final collapsedExtent = collapsed == null ? 0.0 : _main(collapsed.size);
    final range = math.max(0.0, expandedExtent - collapsedExtent);
    final main = math.max(expandedExtent, collapsedExtent) - range * _progress;
    final cross = math.max(_cross(expanded.size), collapsed == null ? 0.0 : _cross(collapsed.size));
    size = constraints.constrain(_axis == .vertical ? Size(cross, main) : Size(main, cross));
    if (_reportedRange != range) {
      _reportedRange = range;
      final generation = ++_reportGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (attached && generation == _reportGeneration) _onRangeChanged(range);
      });
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushClipRect(needsCompositing, offset, Offset.zero & size, defaultPaint);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = _progress >= .5 && childCount > 1 ? lastChild : firstChild;
    return child?.hitTest(result, position: position) ?? false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_progress >= 1 && childCount == 1) return;
    visitor((_progress >= .5 && childCount > 1 ? lastChild : firstChild)!);
  }

  @override
  void detach() {
    _reportGeneration++;
    _reportedRange = null;
    super.detach();
  }
}
