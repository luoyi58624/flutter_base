import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

import '../../utils/internal/pixel_grid.dart';

/// 可编辑文本视觉行的纵向度量策略。
enum EditableLineHeightMode {
  /// 所有视觉行共用基础文本样式解析出的固定行高与基线。
  fixed,

  /// 视觉行允许被 composer 中更高的文本 run 撑开。
  content,
}

/// 固定文本行的共享字体度量，供正文和行号等附属区域复用。
@immutable
final class EditableLineMetrics {
  const EditableLineMetrics._({
    required this.height,
    required this.baseline,
    required this.strutStyle,
    required this._paintCorrection,
    required this._evenLeading,
  });

  /// 从基础样式测量一次强制行高；默认将额外行距均分到字形上下。
  factory EditableLineMetrics.resolve(
    TextStyle style, {
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    final effectiveStyle = style.leadingDistribution == null ? style.copyWith(leadingDistribution: .even) : style;
    final strut = StrutStyle.fromTextStyle(effectiveStyle, forceStrutHeight: true);
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: effectiveStyle),
      textDirection: textDirection,
      textScaler: textScaler,
      strutStyle: strut,
    )..layout();
    final metrics = painter.computeLineMetrics();
    final metric = metrics.isEmpty ? null : metrics.first;
    final fallbackHeight = math.max(
      1.0,
      textScaler.scale(effectiveStyle.fontSize ?? 14.0) * (effectiveStyle.height ?? 1.0),
    );
    final height = metric != null && metric.height.isFinite && metric.height > 0 ? metric.height : fallbackHeight;
    final baseline = metric != null && metric.baseline.isFinite
        ? metric.baseline.clamp(0.0, height).toDouble()
        : height;
    painter.dispose();
    final evenLeading = effectiveStyle.leadingDistribution == TextLeadingDistribution.even;
    return EditableLineMetrics._(
      height: height,
      baseline: baseline,
      strutStyle: strut,
      evenLeading: evenLeading,
      paintCorrection: evenLeading && metric != null
          ? metric.ascent - baseline + (height - metric.ascent - metric.descent) / 2
          : 0,
    );
  }

  /// 字体解析出的自然行高，尚未进行滚动布局的物理像素取整。
  final double height;

  /// Paragraph 的原始基线；实际绘制基线需加上 [textPaintOffset]。
  final double baseline;

  /// 正文使用的强制行高样式。
  final StrutStyle strutStyle;

  final double _paintCorrection;
  final bool _evenLeading;

  /// 与固定尺寸列表相同的最终单行布局高度。
  double layoutHeight(double devicePixelRatio) => snapVirtualItemExtentToPixelGrid(height, devicePixelRatio);

  /// 补偿基线取整及实际行盒余量；折行时传入全部视觉行的自然高度。
  double textPaintOffset(double layoutHeight, {double? textHeight}) =>
      _evenLeading ? _paintCorrection + (layoutHeight - (textHeight ?? height)) / 2 : 0;
}
