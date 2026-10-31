part of 'table.dart';

/// 在有界父级中铺满可用宽，在无界父级中退回表格自然列总宽。
class _TableConstraintHost extends SingleChildRenderObjectWidget {
  const _TableConstraintHost({required this.naturalWidth, required super.child});

  final double naturalWidth;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTableConstraintHost(naturalWidth);

  @override
  void updateRenderObject(BuildContext context, _RenderTableConstraintHost renderObject) {
    renderObject.naturalWidth = naturalWidth;
  }
}

class _RenderTableConstraintHost extends RenderProxyBox {
  _RenderTableConstraintHost(this._naturalWidth);

  double _naturalWidth;

  set naturalWidth(double value) {
    if (_naturalWidth == value) return;
    _naturalWidth = value;
    markNeedsLayout();
  }

  double _resolvedWidth(BoxConstraints constraints) =>
      constraints.hasBoundedWidth ? constraints.maxWidth : math.max(_naturalWidth, constraints.minWidth);

  BoxConstraints _childConstraints(BoxConstraints constraints) {
    final width = _resolvedWidth(constraints);
    return constraints.copyWith(minWidth: width, maxWidth: width);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size(_resolvedWidth(constraints), 0));
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    size = constraints.constrain(Size(_resolvedWidth(constraints), child.size.height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.constrain(Size(_resolvedWidth(constraints), 0));
    final childSize = child.getDryLayout(_childConstraints(constraints));
    return constraints.constrain(Size(_resolvedWidth(constraints), childSize.height));
  }

  @override
  double computeMinIntrinsicWidth(double height) => _naturalWidth;

  @override
  double computeMaxIntrinsicWidth(double height) => _naturalWidth;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null || !size.contains(position)) return false;
    return child.hitTest(result, position: position);
  }
}

class _TableRowView extends ElView {
  const _TableRowView({super.key, required super.style, required Widget super.child});

  @override
  _RenderTableRowView createRenderObject(BuildContext context) => _RenderTableRowView(style: style);

  @override
  void updateRenderObject(BuildContext context, _RenderTableRowView renderObject) {
    renderObject.style = style;
  }
}

class _RenderTableRowView extends ElRenderView {
  _RenderTableRowView({required super.style});

  @override
  bool get isRepaintBoundary => true;
}

/// 表格内部实心三角裁剪，用于排序和展开按钮。
class _TableTriangleClipper extends CustomClipper<Path> {
  const _TableTriangleClipper(this.direction);

  final AxisDirection direction;

  @override
  Path getClip(Size size) {
    final path = Path();
    switch (direction) {
      case AxisDirection.up:
        path
          ..moveTo(size.width / 2, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height);
      case AxisDirection.down:
        path
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width / 2, size.height);
      case AxisDirection.right:
        path
          ..moveTo(0, 0)
          ..lineTo(size.width, size.height / 2)
          ..lineTo(0, size.height);
      case AxisDirection.left:
        path
          ..moveTo(size.width, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height / 2);
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant _TableTriangleClipper oldClipper) => oldClipper.direction != direction;

  @override
  bool operator ==(Object other) => other is _TableTriangleClipper && other.direction == direction;

  @override
  int get hashCode => direction.hashCode;
}

/// 当前排序列的单一方向指示，交互由完整表头单元格承担。
class _TableSortIndicator extends StatelessWidget {
  const _TableSortIndicator({required this.style, required this.ascending});

  final ElStyle style;
  final bool ascending;

  @override
  Widget build(BuildContext context) => ElView(
    style: style,
    child: ElView(
      style: ElStyle(
        width: 8,
        height: 5,
        backgroundColor: style.color ?? const Color(0xff909399),
        clipPath: _TableTriangleClipper(ascending ? AxisDirection.up : AxisDirection.down),
      ),
    ),
  );
}
