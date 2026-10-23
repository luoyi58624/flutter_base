import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'shape.dart';

/// 缓存边框几何，沿用孤边完整圆角与相邻边共分圆角的绘制规则。
class BorderPainter {
  /// 创建边框执行器，与背景和裁剪共用规范圆角。
  BorderPainter(this._shape);

  final ShapeGeometry Function() _shape;
  final Paint _paint = Paint();
  Paint? _layerPaint;
  Object? _key;
  RRect? _base;
  RRect? _uniformOuter;
  RRect? _uniformInner;
  List<Path?>? _fills;
  List<Path?>? _lines;

  /// 返回包含外侧描边及孤角突出部分的保守绘制范围。
  static Rect bounds(Rect rect, Border border, {BorderRadius? borderRadius}) {
    final sides = [border.top, border.right, border.bottom, border.left];
    final extents = List<double>.filled(4, 0);
    final radii = borderRadius == null
        ? null
        : [
            borderRadius.topLeft,
            borderRadius.topRight,
            borderRadius.bottomRight,
            borderRadius.bottomLeft,
          ];
    for (var i = 0; i < 4; i++) {
      final side = sides[i];
      if (!_visible(side)) continue;
      final extent = side.width == 0 ? 0.5 : math.max(0.0, side.strokeOutset);
      extents[i] = math.max(extents[i], extent);
      if (radii == null) continue;
      final (a, b, _) = _sideArcs(i);
      final previous = (i + 3) & 3;
      final next = (i + 1) & 3;
      if (!_present(sides[previous]) && _rounded(radii[a])) {
        extents[previous] = math.max(extents[previous], extent);
      }
      if (!_present(sides[next]) && _rounded(radii[b])) {
        extents[next] = math.max(extents[next], extent);
      }
    }
    return Rect.fromLTRB(
      rect.left - extents[3],
      rect.top - extents[0],
      rect.right + extents[1],
      rect.bottom + extents[2],
    );
  }

  /// 绘制已解析的物理边框，不改变盒尺寸或子节点约束。
  void paint(
    Canvas canvas,
    Rect rect,
    Border border, {
    BorderRadius? borderRadius,
  }) {
    if (rect.isEmpty) return;
    final key = (
      rect.size,
      borderRadius,
      _dimensions(border.top),
      _dimensions(border.right),
      _dimensions(border.bottom),
      _dimensions(border.left),
    );
    if (_key != key) {
      _key = key;
      _base = borderRadius == null
          ? RRect.fromRectAndRadius(Offset.zero & rect.size, Radius.zero)
          : _shape().resolve(rect.size, borderRadius);
      _fills = null;
      _lines = null;
      _uniformOuter = null;
      _uniformInner = null;
    }
    final shifted = rect.topLeft != Offset.zero;
    if (shifted) {
      canvas.save();
      canvas.translate(rect.left, rect.top);
    }
    if (border.isUniform) {
      final side = border.top;
      _paint.color = side.color;
      if (side.width == 0) {
        _paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0;
        canvas.drawRRect(_base!, _paint);
      } else {
        _paint.style = PaintingStyle.fill;
        if (_uniformOuter == null) {
          final base = _base!;
          _uniformOuter = _offsetShape(base, side.strokeOutset);
          _uniformInner = _offsetShape(base, -side.strokeInset);
        }
        final outer = _uniformOuter!;
        final inner = _uniformInner!;
        if (!outer.isEmpty) {
          if (inner.isEmpty) {
            canvas.drawRRect(outer, _paint);
          } else {
            canvas.drawDRRect(outer, inner, _paint);
          }
        }
      }
    } else {
      final sides = [border.top, border.right, border.bottom, border.left];
      if (_fills == null) _build(sides);
      var visibleCount = 0;
      for (final side in sides) {
        if (_visible(side)) visibleCount++;
      }
      final blend = visibleCount > 1;
      if (blend) {
        // 相邻共角的预乘覆盖相加，保留轮廓抗锯齿且不重复叠深半透明。
        canvas.saveLayer(
          bounds(
            Offset.zero & rect.size,
            border,
            borderRadius: borderRadius,
          ).inflate(1),
          _layerPaint ??= Paint(),
        );
        _paint.blendMode = BlendMode.plus;
      }
      for (var i = 0; i < 4; i++) {
        if (!_visible(sides[i])) continue;
        _paint.color = sides[i].color;
        final fill = _fills![i];
        if (fill != null) {
          _paint.style = PaintingStyle.fill;
          canvas.drawPath(fill, _paint);
        } else if (_lines![i] case final line?) {
          _paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0;
          canvas.drawPath(line, _paint);
        }
      }
      if (blend) {
        canvas.restore();
        _paint.blendMode = BlendMode.srcOver;
      }
    }
    if (shifted) canvas.restore();
  }

  static (BorderStyle, double, double) _dimensions(BorderSide side) =>
      (side.style, side.width, side.strokeAlign);

  void _build(List<BorderSide> sides) {
    final base = _base!;
    final rect = base.outerRect;
    final radii = [base.tlRadius, base.trRadius, base.brRadius, base.blRadius];
    final outer = <_Corner>[];
    final inner = <_Corner>[];
    for (var corner = 0; corner < 4; corner++) {
      final horizontal = corner < 2 ? 0 : 2;
      final vertical = corner == 0 || corner == 3 ? 3 : 1;
      final h = sides[horizontal];
      final v = sides[vertical];
      final rounded = _rounded(radii[corner]);
      // 透明 solid 保留角域，颜色过渡到零时才不会突然改变邻边形状。
      double extent(BorderSide side, BorderSide adjacent, bool outside) {
        final effective = _present(side)
            ? side
            : rounded && _present(adjacent)
            ? adjacent
            : BorderSide.none;
        return outside ? effective.strokeOutset : -effective.strokeInset;
      }

      outer.add(
        _corner(
          rect,
          radii[corner],
          corner,
          extent(v, h, true),
          extent(h, v, true),
        ),
      );
      inner.add(
        _corner(
          rect,
          radii[corner],
          corner,
          extent(v, h, false),
          extent(h, v, false),
        ),
      );
    }
    // 粗线吃掉内框时，各边汇入同一线或点，不形成反向的洞。
    final left = math.max(inner[0].edge.dx, inner[3].edge.dx);
    final right = math.min(inner[1].edge.dx, inner[2].edge.dx);
    final top = math.max(inner[0].edge.dy, inner[1].edge.dy);
    final bottom = math.min(inner[2].edge.dy, inner[3].edge.dy);
    final x = left > right
        ? ((left + right) / 2).clamp(rect.left, rect.right)
        : null;
    final y = top > bottom
        ? ((top + bottom) / 2).clamp(rect.top, rect.bottom)
        : null;
    if (x != null || y != null) {
      for (var i = 0; i < 4; i++) {
        inner[i] = inner[i].collapse(x, y);
      }
    }
    _scaleRadii(outer);
    _scaleRadii(inner);
    Path? ring;
    _fills = List<Path?>.filled(4, null);
    _lines = List<Path?>.filled(4, null);
    for (var i = 0; i < 4; i++) {
      final side = sides[i];
      if (!_present(side)) continue;
      final (a, b, start) = _sideArcs(i);
      final aSolo = !_present(sides[(i + 3) & 3]);
      final bSolo = !_present(sides[(i + 1) & 3]);
      final aStart = start - (aSolo ? math.pi / 4 : 0);
      final aSweep = aSolo ? math.pi / 2 : math.pi / 4;
      final bSweep = bSolo ? math.pi / 2 : math.pi / 4;
      final mid = start + math.pi / 4;
      if (side.width == 0) {
        // 原版中心线用于虚线；这里仅适配原生零宽 hairline，不引入线型系统。
        final line = Path();
        _arc(
          line,
          _corner(rect, radii[a], a, 0, 0),
          aStart,
          aSweep,
          move: true,
        );
        _arc(line, _corner(rect, radii[b], b, 0, 0), mid, bSweep);
        _lines![i] = line;
        continue;
      }
      final path = Path();
      _arc(path, outer[a], aStart, aSweep, move: true);
      _arc(path, outer[b], mid, bSweep);
      _arc(path, inner[b], mid + bSweep, -bSweep);
      _arc(path, inner[a], mid, -aSweep);
      path.close();
      // 极不对称粗线的内弧可穿出外弧，统一环同时约束外缘和内孔。
      _fills![i] = Path.combine(
        PathOperation.intersect,
        path,
        ring ??= Path.combine(
          PathOperation.difference,
          _outline(outer),
          _outline(inner),
        ),
      );
    }
  }

  static bool _present(BorderSide side) => side.style == BorderStyle.solid;
  static bool _visible(BorderSide side) => _present(side) && side.color.a > 0;
  static bool _rounded(Radius radius) => radius.x > 0 && radius.y > 0;

  static Path _outline(List<_Corner> corners) {
    final path = Path();
    for (var i = 0; i < 4; i++) {
      _arc(
        path,
        corners[i],
        math.pi + i * math.pi / 2,
        math.pi / 2,
        move: i == 0,
      );
    }
    return path..close();
  }

  static RRect _offsetShape(RRect base, double amount) {
    // 只移动已声明圆角；直接 inflate 会让未声明的零角也变圆。
    Radius shift(Radius radius) => _rounded(radius)
        ? Radius.elliptical(
            math.max(0.0, radius.x + amount),
            math.max(0.0, radius.y + amount),
          )
        : Radius.zero;
    return RRect.fromRectAndCorners(
      base.outerRect.inflate(amount),
      topLeft: shift(base.tlRadius),
      topRight: shift(base.trRadius),
      bottomRight: shift(base.brRadius),
      bottomLeft: shift(base.blRadius),
    ).scaleRadii();
  }

  // 派生轮廓也统一缩放，避免一条宽边挤窄内框后，对侧圆弧反向穿越。
  static void _scaleRadii(List<_Corner> corners) {
    var scale = 1.0;
    void fit(double extent, double radii) {
      if (radii > 0) scale = math.min(scale, math.max(0.0, extent) / radii);
    }

    fit(
      corners[1].edge.dx - corners[0].edge.dx,
      corners[0].radius.x + corners[1].radius.x,
    );
    fit(
      corners[2].edge.dx - corners[3].edge.dx,
      corners[2].radius.x + corners[3].radius.x,
    );
    fit(
      corners[3].edge.dy - corners[0].edge.dy,
      corners[0].radius.y + corners[3].radius.y,
    );
    fit(
      corners[2].edge.dy - corners[1].edge.dy,
      corners[1].radius.y + corners[2].radius.y,
    );
    if (scale < 1) {
      for (var i = 0; i < 4; i++) {
        final corner = corners[i];
        corners[i] = _Corner(
          corner.edge,
          corner.radius * scale,
          corner.left,
          corner.top,
        );
      }
    }
  }

  // 角序和弧域沿用旧 ViewBoxPainter 的 _cornerGeometry / _sideArcParams。
  static (int, int, double) _sideArcs(int side) => switch (side) {
    0 => (0, 1, math.pi * 1.25),
    1 => (1, 2, math.pi * 1.75),
    2 => (2, 3, math.pi * 0.25),
    _ => (3, 0, math.pi * 0.75),
  };

  static _Corner _corner(
    Rect rect,
    Radius radius,
    int index,
    double xExtent,
    double yExtent,
  ) {
    final left = index == 0 || index == 3;
    final top = index < 2;
    final edge = Offset(
      left ? rect.left - xExtent : rect.right + xExtent,
      top ? rect.top - yExtent : rect.bottom + yExtent,
    );
    final r = _rounded(radius)
        ? Radius.elliptical(
            math.max(0.0, radius.x + xExtent),
            math.max(0.0, radius.y + yExtent),
          )
        : Radius.zero;
    return _Corner(edge, r, left, top);
  }

  static void _arc(
    Path path,
    _Corner corner,
    double start,
    double sweep, {
    bool move = false,
  }) {
    final radius = corner.radius;
    if (radius == Radius.zero) {
      if (move) {
        path.moveTo(corner.edge.dx, corner.edge.dy);
      } else {
        path.lineTo(corner.edge.dx, corner.edge.dy);
      }
      return;
    }
    final center = corner.center;
    final begin = Offset(
      center.dx + math.cos(start) * radius.x,
      center.dy + math.sin(start) * radius.y,
    );
    if (move) {
      path.moveTo(begin.dx, begin.dy);
    } else {
      path.lineTo(begin.dx, begin.dy);
    }
    if (_rounded(radius)) {
      path.arcTo(
        Rect.fromCenter(
          center: center,
          width: radius.x * 2,
          height: radius.y * 2,
        ),
        start,
        sweep,
        false,
      );
    } else {
      final end = Offset(
        center.dx + math.cos(start + sweep) * radius.x,
        center.dy + math.sin(start + sweep) * radius.y,
      );
      path.lineTo(end.dx, end.dy);
    }
  }
}

class _Corner {
  const _Corner(this.edge, this.radius, this.left, this.top);

  final Offset edge;
  final Radius radius;
  final bool left;
  final bool top;

  Offset get center => Offset(
    edge.dx + (left ? radius.x : -radius.x),
    edge.dy + (top ? radius.y : -radius.y),
  );

  _Corner collapse(double? x, double? y) => _Corner(
    Offset(x ?? edge.dx, y ?? edge.dy),
    Radius.elliptical(x == null ? radius.x : 0, y == null ? radius.y : 0),
    left,
    top,
  );
}
