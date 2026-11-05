import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../style/resolved/resolved_style.dart';
import '../style/style.dart';

/// 盒模型 paint 工具集 —— 阴影 / 背景 / 边框 / 裁剪几何辅助。
class ViewBoxPainter {
  const ViewBoxPainter._();

  /// 按文字方向解析原生圆角，自定义裁剪存在时圆角让位。
  static BorderRadius? effectiveBorderRadius(Box box, {TextDirection textDirection = TextDirection.ltr}) =>
      box.clipPath == null ? box.borderRadius?.resolve(textDirection) : null;

  /// 背景、裁剪与内阴影共用当前盒子的原生圆角几何。
  static RRect resolveContentRRect(Rect outer, BorderRadius? radius) =>
      radius == null ? RRect.fromRectAndCorners(outer) : radius.toRRect(outer);

  /// 按原声明顺序绘制盒内或盒外阴影，只有实际内阴影才保存并裁剪 Canvas。
  /// 正 offset 向同方向移动内阴影的孔，因此阴影留在相反内边缘。
  static void paintShadows(
    Canvas canvas, {
    required RRect outerRRect,
    required List<BoxShadow> shadows,
    required bool inset,
    Color? backgroundColor,
  }) {
    var clipped = false;
    final base = outerRRect.scaleRadii();
    for (final shadow in shadows) {
      if ((shadow is ElBoxShadow && shadow.inset) != inset) continue;
      final paint = shadow is ElBoxShadow ? shadow.toPaintWithBackground(backgroundColor) : shadow.toPaint();
      if (paint.color.a == 0) continue;
      final shape = _shadowRRect(base, shadow, inset: inset);
      if (!inset) {
        if (!shape.isEmpty) canvas.drawRRect(shape, paint);
        continue;
      }
      if (!clipped) {
        canvas.save();
        canvas.clipRRect(base);
        clipped = true;
      }
      final bounds = base.outerRect.expandToInclude(shape.outerRect).inflate(shadow.blurRadius * 2 + 1);
      final path = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(bounds);
      if (!shape.isEmpty) path.addRRect(shape);
      canvas.drawPath(path, paint);
    }
    if (clipped) canvas.restore();
  }

  /// 按 [shape] 运行时形状（[Path] / [RRect] / [Rect]）发出单条绘制指令。
  static void drawShapeOp(Canvas canvas, Object shape, Paint paint) {
    if (shape is Path) {
      canvas.drawPath(shape, paint);
    } else if (shape is RRect) {
      canvas.drawRRect(shape, paint);
    } else {
      canvas.drawRect(shape as Rect, paint);
    }
  }

  /// 判断 [contentRRect] 是否含圆角 —— 任一角 x 半径大于 0 即为有圆角。
  /// 背景图片只有实际圆角才需要创建裁剪 Path。
  static bool contentRRectHasRadius(RRect contentRRect) {
    return contentRRect.tlRadiusX > 0 ||
        contentRRect.trRadiusX > 0 ||
        contentRRect.blRadiusX > 0 ||
        contentRRect.brRadiusX > 0;
  }

  // Canvas 会自动缩放超限 RRect，但手工拆边必须先取得真实圆角，否则圆心会落到盒外。
  static BorderRadius? _fitBorderRadius(Rect rect, BorderRadius? radius) {
    if (radius == null ||
        (radius.topLeft.x + radius.topRight.x <= rect.width &&
            radius.bottomLeft.x + radius.bottomRight.x <= rect.width &&
            radius.topLeft.y + radius.bottomLeft.y <= rect.height &&
            radius.topRight.y + radius.bottomRight.y <= rect.height)) {
      return radius;
    }
    final fitted = radius.toRRect(rect).scaleRadii();
    return BorderRadius.only(
      topLeft: fitted.tlRadius,
      topRight: fitted.trRadius,
      bottomLeft: fitted.blRadius,
      bottomRight: fitted.brRadius,
    );
  }

  /// 直接绘制边框：统一边框一笔描边，其余按 CSS 角归属逐边填充或分段描边。
  /// 虚线和点线沿中心线构造 Path，无可见边时不发出绘制指令。
  static void paintBorder(
    Canvas canvas, {
    required Rect rect,
    required ElBorder border,
    required BorderRadius? borderRadius,
  }) {
    if (rect.isEmpty) return;
    final sides = border.isUniform
        ? List<ElBorderSide>.filled(4, _paintableSide(border.borderTop), growable: false)
        : [
            _paintableSide(border.borderTop),
            _paintableSide(border.borderRight),
            _paintableSide(border.borderBottom),
            _paintableSide(border.borderLeft),
          ];
    final top = sides.first;
    final uniform = top == sides[1] && top == sides[2] && top == sides[3];
    if (uniform && top == ElBorderSide.none) return;
    final BorderRadius? resolvedRadius = (borderRadius == null || borderRadius == BorderRadius.zero)
        ? null
        : _fitBorderRadius(rect, borderRadius);

    // 摆位（[ElBorderAlign]）：默认 inside（2026-07-16 裁决），用户可显式
    // 选 center / outside——出盒部分可能被后绘制兄弟盖掉，由声明侧自担。
    final align = border.align;

    // uniform 快路径：按摆位定中心线，一笔 stroke（dashed / dotted →
    // 轮廓分段）。
    if (uniform) {
      final w = top.resolveWidth();
      // 圆角同心弧偏移：用声明半宽，保描边贴盒侧的弧与盒圆角重合。
      final radiusShift = switch (align) {
        ElBorderAlign.inside => -w / 2,
        ElBorderAlign.center => 0.0,
        ElBorderAlign.outside => w / 2,
      };
      final centerRect = rect.inflate(radiusShift);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = top.borderColor!;
      Radius shiftR(Radius r) => Radius.elliptical(math.max(0, r.x + radiusShift), math.max(0, r.y + radiusShift));
      final RRect? centerRRect = resolvedRadius == null
          ? null
          : RRect.fromRectAndCorners(
              centerRect,
              topLeft: shiftR(resolvedRadius.topLeft),
              topRight: shiftR(resolvedRadius.topRight),
              bottomRight: shiftR(resolvedRadius.bottomRight),
              bottomLeft: shiftR(resolvedRadius.bottomLeft),
            );
      final lineStyle = top.borderStyle;
      if (lineStyle == ElBorderStyle.solid) {
        drawShapeOp(canvas, centerRRect ?? centerRect, paint);
        return;
      }
      final outline = Path();
      if (centerRRect == null) {
        outline.addRect(centerRect);
      } else {
        outline.addRRect(centerRRect);
      }
      final (on, off, cap) = _dashPattern(w, lineStyle);
      paint.strokeCap = cap;
      canvas.drawPath(dashPath(outline, on: on, off: off), paint);
      return;
    }

    // per-side 直绘：top → right → bottom → left（CSS 绘制顺序）。
    // 每边的外缘/内缘偏移（相对盒边缘法向，向外为正），按摆位取值——
    // inside：外缘贴盒边缘（0）、内缘向盒内退整个边宽（默认，出盒描边会被
    // 后绘制兄弟盖掉，2026-07-16 裁决）；center：±w/2 骑中心线；outside：
    // 内缘贴盒边缘、带宽向盒外铺。不画的边偏移恒 0，让相邻边的直角端退化
    // 为直切（保留旧 drawRect 分支的矩形端语义）。
    final outExts = List<double>.filled(4, 0);
    final inExts = List<double>.filled(4, 0);
    for (var i = 0; i < 4; i++) {
      final s = sides[i];
      if (!_isPaintableSide(s)) continue;
      final width = s.resolveWidth();
      final (outExt, inExt) = switch (align) {
        ElBorderAlign.inside => (0.0, -width),
        ElBorderAlign.center => (width / 2, -width / 2),
        ElBorderAlign.outside => (width, 0.0),
      };
      outExts[i] = outExt;
      inExts[i] = inExt;
    }
    for (var i = 0; i < 4; i++) {
      final s = sides[i];
      if (!_isPaintableSide(s)) continue;
      final lineStyle = s.borderStyle;
      final fill = lineStyle == ElBorderStyle.solid;
      var path = _sidePath(
        fill: fill,
        rect: rect,
        radius: resolvedRadius,
        sideIndex: i,
        sides: sides,
        outExts: outExts,
        inExts: inExts,
      );
      final paint = Paint()..color = s.borderColor!;
      if (!fill) {
        // dashed / dotted：沿本边中心线（fill 带的中线）分段 stroke。
        final (on, off, cap) = _dashPattern(s.resolveWidth(), lineStyle);
        path = dashPath(path, on: on, off: off);
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.resolveWidth()
          ..strokeCap = cap;
      }
      canvas.drawPath(path, paint);
    }
  }

  /// dashed / dotted 的 (dash 段长, 间隔, 线帽)。
  ///
  /// - dashed：段 3×w、隔 3×w、平头（CSS UA 惯例区间）
  /// - dotted：近零段 + round cap 成直径 = w 的圆点，中心距 2×w
  ///
  /// 宽度按 ≥ 1 计，亚像素宽不产出微尘 pattern。
  static (double, double, StrokeCap) _dashPattern(double width, ElBorderStyle style) {
    final w = math.max(1.0, width);
    if (style == ElBorderStyle.dotted) {
      const dot = 0.1;
      return (dot, 2 * w - dot, StrokeCap.round);
    }
    return (3 * w, 3 * w, StrokeCap.butt);
  }

  /// 把 [source] 按 `on / off` 分段为虚线 [Path]。
  ///
  /// 段数对齐（避免接缝 / 断头）：闭合轮廓取最近整周期数微缩放（首尾无缝）；
  /// 开放段取「n 段 dash + n-1 段间隔」撑满全长（两端都落 dash，单边虚线
  /// 分隔线两头不秃）；每条虚线轮廓最终只发一条 drawPath。
  static Path dashPath(Path source, {required double on, required double off}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      final length = metric.length;
      if (length <= 0) continue;
      final period = on + off;
      final closed = metric.isClosed;
      final count = math.max(1, ((closed ? length : length + off) / period).round());
      final scale = length / (closed ? count * period : count * on + (count - 1) * off);
      final onLen = on * scale, offLen = off * scale;
      var distance = 0.0;
      while (distance < length) {
        dest.addPath(metric.extractPath(distance, math.min(distance + onLen, length)), Offset.zero);
        distance += onLen;
        if (distance < length) distance += offLen;
      }
    }
    return dest;
  }

  /// 绘制盒外描边及其渐变；非正宽度或退化矩形不产生绘制。
  static void paintOutline(
    Canvas canvas, {
    required Rect outerRect,
    required ElOutline outline,
    required BorderRadius? borderRadius,
  }) {
    final width = outline.resolveWidth();
    final offset = outline.resolveOffset();
    if (width <= 0) return;
    final outlineColor = outline.outlineColor is Color ? outline.outlineColor! : const Color(0xFF000000);
    // outline 固定画在 box 外；offset 再向外推（可为负）。
    final finalRect = outerRect.inflate(width + offset);
    // 圆角自适应外推（替代 CSS 简单加法，解决小圆角 + 大 offset 变胶囊的失真）
    final finalRadius = borderRadius == null
        ? null
        : outline.extrudeRadius(borderRadius, resolvedWidth: width, resolvedOffset: offset);
    final strokeRect = finalRect.deflate(width / 2);
    if (strokeRect.isEmpty) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    if (outline.gradient != null) {
      // gradient 描边：shader 跑在最终 stroke rect 上
      paint.shader = outline.gradient!.createShader(strokeRect);
    } else {
      paint.color = outlineColor;
    }
    drawShapeOp(
      canvas,
      finalRadius != null && finalRadius != BorderRadius.zero ? finalRadius.toRRect(strokeRect) : strokeRect,
      paint,
    );
  }

  /// 单边描边的闭合 fill 区域（**孤边接管全弧** + 共角 45° miter 混合模型）。
  static (Offset, Radius, Offset) _cornerGeometry(Rect rect, BorderRadius? radius, int i) {
    switch (i) {
      case 0:
        final r = radius?.topLeft ?? Radius.zero;
        return (Offset(rect.left + r.x, rect.top + r.y), r, const Offset(-1, -1));
      case 1:
        final r = radius?.topRight ?? Radius.zero;
        return (Offset(rect.right - r.x, rect.top + r.y), r, const Offset(1, -1));
      case 2:
        final r = radius?.bottomRight ?? Radius.zero;
        return (Offset(rect.right - r.x, rect.bottom - r.y), r, const Offset(1, 1));
      default:
        final r = radius?.bottomLeft ?? Radius.zero;
        return (Offset(rect.left + r.x, rect.bottom - r.y), r, const Offset(-1, 1));
    }
  }

  /// 实线的外/内边缘和虚线中心线共用角归属；相邻边缺失时独占完整圆弧。
  static Path _sidePath({
    required Rect rect,
    required BorderRadius? radius,
    required int sideIndex,
    required List<ElBorderSide> sides,
    required List<double> outExts,
    required List<double> inExts,
    bool fill = true,
  }) {
    final a = sideIndex, b = (sideIndex + 1) & 3;
    final start = ((225 + sideIndex * 90) % 360) * math.pi / 180;
    final mid = start + math.pi / 4;
    final aSolo = !_isPaintableSide(sides[(sideIndex + 3) & 3]);
    final bSolo = !_isPaintableSide(sides[(sideIndex + 1) & 3]);
    final aStart = start - (aSolo ? math.pi / 4 : 0);
    final aSweep = aSolo ? math.pi / 2 : math.pi / 4;
    final bSweep = bSolo ? math.pi / 2 : math.pi / 4;
    final out = outExts[sideIndex], inside = inExts[sideIndex];
    final path = Path();

    void corner(int index, double angle, double sweep, double extension, {bool move = false, bool outer = true}) {
      final (center, cornerRadius, sign) = _cornerGeometry(rect, radius, index);
      final rx = math.max(0.0, cornerRadius.x + extension);
      final ry = math.max(0.0, cornerRadius.y + extension);
      final rounded = cornerRadius.x > 0 && cornerRadius.y > 0;
      Offset point;
      if (rounded) {
        // 内缘或中心线半径退化时汇到圆心，不能向外翻转圆弧。
        point = rx > 0 && ry > 0 ? center + Offset(math.cos(angle) * rx, math.sin(angle) * ry) : center;
      } else {
        final horizontal = sideIndex.isEven;
        final ext = outer ? outExts : inExts;
        final dx = fill
            ? (horizontal ? ext[index == 0 || index == 3 ? 3 : 1] : extension)
            : (horizontal ? 0.0 : extension);
        final dy = fill ? (horizontal ? extension : ext[index < 2 ? 0 : 2]) : (horizontal ? extension : 0.0);
        point = center + Offset(sign.dx * dx, sign.dy * dy);
      }
      if (move) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      if (rounded && rx > 0 && ry > 0) {
        path.arcTo(Rect.fromCenter(center: center, width: rx * 2, height: ry * 2), angle, sweep, false);
      }
    }

    if (fill) {
      corner(a, aStart, aSweep, out, move: true);
      corner(b, mid, bSweep, out);
      corner(b, mid + bSweep, -bSweep, inside, outer: false);
      corner(a, mid, -aSweep, inside, outer: false);
      path.close();
    } else {
      final center = (out + inside) / 2;
      corner(a, aStart, aSweep, center, move: true);
      corner(b, mid, bSweep, center);
    }
    return path;
  }

  static bool _isPaintableSide(ElBorderSide side) =>
      side.borderStyle != ElBorderStyle.none && side.resolveWidth() > 0 && (side.borderColor?.a ?? 1) > 0;

  /// 不可见边不参与相邻圆弧归属，缺省边色统一按黑色绘制。
  static ElBorderSide _paintableSide(ElBorderSide side) {
    assert(side.borderStyle == ElBorderStyle.none || side.resolveWidth() >= 0, '可见边框的宽度必须非负。');
    if (!_isPaintableSide(side)) return ElBorderSide.none;
    return side.borderColor == null ? side.copyWith(borderColor: const Color(0xFF000000)) : side;
  }

  static RRect _shadowRRect(RRect base, BoxShadow shadow, {required bool inset}) {
    final rect = base.shift(shadow.offset);
    final spread = shadow.spreadRadius;
    if (spread == 0) return rect;
    final delta = inset ? -spread : spread;
    final x = math.max(-rect.width / 2, delta);
    final y = math.max(-rect.height / 2, delta);
    // W3C 小圆角扩散修正：直角保持直角，逐轴连续过渡到半径直接加扩散量。
    double grow(double radius, double distance) {
      if (distance <= 0 || radius >= distance) return math.max(0, radius + distance);
      final ratio = radius / distance - 1;
      return radius + distance * (1 + ratio * ratio * ratio);
    }

    Radius radius(double rx, double ry) => Radius.elliptical(grow(rx, x), grow(ry, y));
    return RRect.fromLTRBAndCorners(
      rect.left - x,
      rect.top - y,
      rect.right + x,
      rect.bottom + y,
      topLeft: radius(rect.tlRadiusX, rect.tlRadiusY),
      topRight: radius(rect.trRadiusX, rect.trRadiusY),
      bottomLeft: radius(rect.blRadiusX, rect.blRadiusY),
      bottomRight: radius(rect.brRadiusX, rect.brRadiusY),
    ).scaleRadii();
  }

  /// 将声明折算为统一的 8 位透明度，供合成判定与绘制共用。
  static int opacityAlpha(double? value) {
    if (value != null && value <= 0) return 0;
    if (value == null || !value.isFinite) return 255;
    return Color.getAlphaFromOpacity(value.clamp(0.0, 1.0).toDouble());
  }

  /// 解析 box 当前视觉变换矩阵，供 paint、hit-test 和坐标链共用。
  ///
  /// [offset] 是当前 box 在父 paint 坐标系里的偏移；命中测试在本地坐标系内
  /// 使用时传 [Offset.zero]，即可得到同一 transform-origin 语义下的本地矩阵。
  static Matrix4? resolveEffectiveTransform({
    required Offset offset,
    required Size size,
    required ResolvedStyle resolved,
    TextDirection? textDirection,
  }) {
    final transform = resolved.box.transform;
    if (transform == null) return null;
    // transform 原点：transformOrigin 默认 center（CSS transform-origin: 50% 50%）
    final align = resolved.box.transformOrigin ?? transform.origin ?? Alignment.center;
    final resolvedAlign = align.resolve(textDirection ?? resolved.inheritedBox.direction ?? TextDirection.ltr);
    final origin = offset + resolvedAlign.alongSize(size);
    return Matrix4.identity()
      ..translateByDouble(origin.dx, origin.dy, 0.0, 1.0)
      ..multiply(transform.toMatrix4())
      ..translateByDouble(-origin.dx, -origin.dy, 0.0, 1.0);
  }
}
