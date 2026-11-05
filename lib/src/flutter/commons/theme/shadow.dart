import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models.dart';

/// 根据悬浮层级、实际表面颜色与圆角几何生成柔和投影，不读取上下文或改变组件样式。
abstract final class ElShadow {
  /// 生成可直接用于 ElStyle.boxShadow 的只读列表，xs 为一层，其余档位为近、远两层。
  ///
  /// backgroundColor 必须是已合成的不透明背景；surfaceColor 可透明。
  /// size 为实际逻辑尺寸，圆角会先按尺寸归一化；strength 非负，softness 大于零。
  /// 返回值是视觉启发式结果，纯黑背景无法通过黑色投影产生可见层次。
  static List<BoxShadow> resolve({
    required ElLevelType level,
    required Brightness brightness,
    required Color surfaceColor,
    required Color backgroundColor,
    required Size size,
    BorderRadius borderRadius = BorderRadius.zero,
    double strength = 1,
    double softness = 1,
  }) {
    final corners = [borderRadius.topLeft, borderRadius.topRight, borderRadius.bottomLeft, borderRadius.bottomRight];
    final dimensions = [
      size.width,
      size.height,
      for (final r in corners) ...[r.x, r.y],
      strength,
      softness,
    ];
    if (dimensions.any((v) => !v.isFinite || v < 0) || softness == 0) {
      throw ArgumentError('尺寸、圆角和强度必须为非负有限数，柔和程度必须大于零');
    }
    if (backgroundColor.a != 1) throw ArgumentError.value(backgroundColor, 'backgroundColor', '请先合成不透明背景');
    if (size.isEmpty || strength == 0 || surfaceColor.a == 0) return const [];

    final shortSide = size.shortestSide;
    final shape = borderRadius.toRRect(Offset.zero & size).scaleRadii();
    final radii = [
      shape.tlRadiusX,
      shape.tlRadiusY,
      shape.trRadiusX,
      shape.trRadiusY,
      shape.blRadiusX,
      shape.blRadiusY,
      shape.brRadiusX,
      shape.brRadiusY,
    ];
    final roundness = (radii.reduce((a, b) => a + b) / 8 / (shortSide / 2)).clamp(0.0, 1.0);
    // 圆角只作小幅修正，避免胶囊形状把层级推高；尺寸上限防止小组件产生大团灰雾。
    final geometry = .94 + .12 * roundness;
    final maxBlur = math.min(96.0, math.max(2.0, shortSide * .45));
    final elevation = switch (level) {
      .xs => 1.0,
      .sm => 2.0,
      .md => 4.0,
      .lg => 8.0,
      .xl => 14.0,
    };
    final root = math.sqrt(elevation);

    final backdropLuminance = backgroundColor.computeLuminance();
    final surface = Color.alphaBlend(surfaceColor, backgroundColor);
    final contrast = (surface.computeLuminance() - backdropLuminance).abs();
    final similarity = 1 - _smoothStep((contrast / .25).clamp(0.0, 1.0));
    // 实际背景占主要权重，主题只提供轻微先验，允许深色主题中的浅色局部表面。
    final darkness = (math.pow(1 - backdropLuminance, 2) * .85 + (brightness == Brightness.dark ? .15 : 0)).clamp(
      0.0,
      1.0,
    );
    final density = strength * (1 + 2.2 * darkness) * math.sqrt(softness).clamp(.8, 1.2);
    final contactAlpha = ((.04 + .012 * root) * density * (.85 + .15 * similarity) * (1 + .08 * roundness)).clamp(
      0.0,
      .55,
    );
    final ambientAlpha = ((.03 + .006 * elevation) * density).clamp(0.0, .5);

    return List<BoxShadow>.unmodifiable([
      BoxShadow(
        color: const Color(0xff000000).withValues(alpha: contactAlpha),
        offset: Offset(0, math.min(.5 + .25 * elevation, shortSide * .15)),
        blurRadius: math.min((1.8 + 1.5 * root) * softness * geometry, maxBlur * .65),
      ),
      if (level != ElLevelType.xs)
        BoxShadow(
          color: const Color(0xff000000).withValues(alpha: ambientAlpha),
          offset: Offset(0, math.min(elevation * geometry, shortSide * .2)),
          blurRadius: math.min((4 + 2.15 * elevation) * softness * geometry, maxBlur),
          spreadRadius: -math.min(elevation * .25 * (1 + .25 * roundness), shortSide * .12),
        ),
    ]);
  }
}

double _smoothStep(double t) => t * t * (3 - 2 * t);
