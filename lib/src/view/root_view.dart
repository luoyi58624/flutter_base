part of 'index.dart';

/// 将一棵命令式 View 树挂入 Widget 树，首次挂载后保持原来的根实例。
class ElRootView extends LeafRenderObjectWidget {
  /// 使用给定根实例创建宿主，只有更换 key 才会重新接入新的 root。
  const ElRootView({super.key, required this.root});

  /// 首次创建宿主时挂载的根 View，Widget 重建时不会替换它。
  final ElView root;

  @override
  RenderBox createRenderObject(BuildContext context) => _RootRenderBox(root);

  @override
  void updateRenderObject(BuildContext context, covariant RenderBox renderObject) {}
}

class _RootRenderBox extends RenderBox {
  _RootRenderBox(this._root) {
    if (_root._parent != null || _root._requestLayout != null) {
      throw StateError('根 View 已经挂载到父节点或其他宿主。');
    }
    _root._requestLayout = markNeedsLayout;
    _root._requestPaint = markNeedsPaint;
  }

  final ElView _root;

  @override
  bool get isRepaintBoundary => true;

  @override
  void performLayout() {
    size = _root._layout(constraints);
    _root._position(_root._margin.topLeft);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _root._layout(constraints, dry: true);

  @override
  double computeMinIntrinsicWidth(double height) => computeMaxIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) => _root._layout(BoxConstraints(maxHeight: height), dry: true).width;

  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _root._layout(BoxConstraints(maxWidth: width), dry: true).height;

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    _root._paint(canvas);
    canvas.restore();
  }

  @override
  void dispose() {
    _root._requestLayout = null;
    _root._requestPaint = null;
    super.dispose();
  }
}
