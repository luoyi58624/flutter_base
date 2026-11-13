import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/widgets.dart';

import 'anchor.dart';
import 'popup.dart';

/// 面板上最靠近目标的点，作为缩放等进场动画的原点；解算完成前取上缘中点。
@internal
Alignment popupOrigin(BuildContext context) {
  final geometry = ElPopup.geometryOf(context);
  if (geometry == null || geometry.overlayRect.isEmpty) return Alignment.topCenter;
  final size = geometry.overlayRect.size;
  return FractionalOffset(geometry.arrowTarget.dx / size.width, geometry.arrowTarget.dy / size.height);
}

/// 在面板朝向目标的一侧画指向目标的三角箭头；箭头底边压住面板边框，两腰描边与边框衔接。
@internal
class PopupArrow extends StatelessWidget {
  /// 箭头在交叉轴上与面板两端保持 inset，避免压到圆角。
  const PopupArrow({
    super.key,
    required this.color,
    this.borderColor,
    this.size = 6,
    this.inset = 12,
    required this.child,
  });

  /// 填充色，通常与面板背景一致。
  final Color color;

  /// 两腰描边色，面板无边框时省略。
  final Color? borderColor;

  /// 箭头高度，也是底边半宽。
  final double size;

  /// 箭头中心距面板两端的最小距离。
  final double inset;

  /// 面板。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final geometry = ElPopup.geometryOf(context);
    if (geometry == null) return child;
    return CustomPaint(foregroundPainter: _ArrowPainter(geometry, color, borderColor, size, inset), child: child);
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.geometry, this.color, this.borderColor, this.extent, this.inset);

  final ElOverlayAnchorGeometry geometry;
  final Color color;
  final Color? borderColor;
  final double extent;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final side = geometry.placement.side;
    final vertical = axisDirectionToAxis(side) == Axis.vertical;
    final length = vertical ? size.width : size.height;
    final target = vertical ? geometry.arrowTarget.dx : geometry.arrowTarget.dy;
    final along = length < inset * 2 ? length / 2 : target.clamp(inset, length - inset);
    // normal 指向目标，tangent 沿面板边缘。
    final (base, normal) = switch (side) {
      AxisDirection.up => (Offset(along, size.height), const Offset(0, 1)),
      AxisDirection.down => (Offset(along, 0), const Offset(0, -1)),
      AxisDirection.left => (Offset(size.width, along), const Offset(1, 0)),
      AxisDirection.right => (Offset(0, along), const Offset(-1, 0)),
    };
    final tangent = Offset(normal.dy, normal.dx) * extent;
    final tip = base + normal * extent;
    canvas.drawPath(
      Path()
        ..moveTo((base + tangent - normal).dx, (base + tangent - normal).dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo((base - tangent - normal).dx, (base - tangent - normal).dy)
        ..close(),
      Paint()..color = color,
    );
    if (borderColor case final border?) {
      canvas.drawPath(
        Path()
          ..moveTo((base + tangent).dx, (base + tangent).dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo((base - tangent).dx, (base - tangent).dy),
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      geometry != oldDelegate.geometry ||
      color != oldDelegate.color ||
      borderColor != oldDelegate.borderColor ||
      extent != oldDelegate.extent ||
      inset != oldDelegate.inset;
}
