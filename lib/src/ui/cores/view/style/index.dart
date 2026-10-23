import 'dart:math' as math;
import 'dart:ui' show ColorSpace, lerpDouble;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/dart.dart';

import '../layout/box_layout.dart';
import 'resolved/filter.dart';
import 'resolved/layout.dart';
import 'resolved/outline.dart';
import 'resolved/transform.dart';

part 'index.g.dart';
part 'transition.dart';
part 'lerp.dart';
part 'style_engine.dart';
part 'fields.dart';
part 'outline.dart';
part 'shadow.dart';
part 'transform.dart';
part 'filter.dart';

/// 不可变的盒模型样式；宽高包含 padding，不包含 margin。
@immutable
@ElModelGenerator.copy()
class ElStyle with Equatable {
  /// 创建样式，集合参数应保持不可变。
  const ElStyle({
    this.width,
    this.height,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.widthFactor,
    this.heightFactor,
    this.aspectRatio,
    this.backgroundColor,
    this.gradient,
    this.boxShadow,
    this.opacity,
    this.transform,
    this.transformAlignment,
    this.filter,
    this.backdropFilter,
    this.padding,
    this.margin,
    this.border,
    this.outline,
    this.borderRadius,
    this.clipper,
    this.clipBehavior,
    this.transitions,
  });

  /// 逻辑像素数值或百分比字符串；null 表示自动宽度。
  final Object? width;

  /// 逻辑像素数值或百分比字符串；null 表示自动高度。
  final Object? height;

  /// 最小视觉盒宽度，数值或百分比，包含 padding；null 为零，maxWidth 冲突优先。
  final Object? minWidth;

  /// 最大视觉盒宽度，数值或百分比，包含 padding；null 表示不增加上限。
  final Object? maxWidth;

  /// 最小视觉盒高度，数值或百分比，包含 padding；null 为零，maxHeight 冲突优先。
  final Object? minHeight;

  /// 最大视觉盒高度，数值或百分比，包含 padding；null 表示不增加上限。
  final Object? maxHeight;

  /// 非负有限的自然盒宽度倍数，包含 padding；null 等同于 1，显式宽度优先。
  final num? widthFactor;

  /// 非负有限的自然盒高度倍数，包含 padding；null 等同于 1，显式高度优先。
  final num? heightFactor;

  /// 正有限的视觉盒宽高比；双显式轴或有效 auto 倍数优先，null 表示不用比例。
  final num? aspectRatio;

  /// 背景色，覆盖内容和 padding；null 表示不绘制。
  final Color? backgroundColor;

  /// 覆盖背景色的原生渐变；null 表示不绘制，使用当前文字方向解析几何。
  final Gradient? gradient;

  /// 按声明顺序绘制的阴影，支持 ElBoxShadow.inset；不占布局或扩大命中范围。
  final List<BoxShadow>? boxShadow;

  /// 背景滤镜、装饰与 child 的整组透明度，限制在 0～1；null 为 1，零值不绘制或命中。
  final num? opacity;

  /// 整组视觉变换，不占布局；null 表示不变换，平移单位为逻辑像素。
  final ElTransform? transform;

  /// 变换原点，优先于 transform.origin；缺省回退内部原点或视觉盒中心。
  final AlignmentGeometry? transformAlignment;

  /// 作用于全部装饰与 child 的自身滤镜，不占布局，模糊允许向盒外扩散。
  final ElFilter? filter;

  /// 仅处理盒后方画面的背景滤镜，采样范围按当前盒形状裁剪，不裁掉装饰。
  final ElFilter? backdropFilter;

  /// 非负有限内边距，支持方向性边距；null 等同于零。
  final EdgeInsetsGeometry? padding;

  /// 非负有限外边距，背景不覆盖此区域；null 等同于零。
  final EdgeInsetsGeometry? margin;

  /// 原生 Border 或 BorderDirectional，仅覆盖绘制、不占布局；null 表示无边框。
  /// 粗细必须非负且有限，strokeAlign 必须有限；零宽 solid 保留原生 hairline。
  final BoxBorder? border;

  /// 盒外轮廓，仅绘制、不占布局；偏移可将其移入盒内，null 表示不绘制。
  final ElOutline? outline;

  /// 非负有限的背景与边框圆角，支持方向性圆角；有效 clipper 存在时让位。
  final BorderRadiusGeometry? borderRadius;

  /// 裁剪全部视觉的自定义路径；默认抗锯齿，显式 Clip.none 禁用此路径。
  final CustomClipper<Path>? clipper;

  /// 裁剪方式；未指定时自定义路径用 antiAlias，普通盒不裁剪，切换不参与过渡。
  final Clip? clipBehavior;

  /// 过渡声明，合并时整体替换；同一属性由最后一条匹配声明决定。
  final List<ElTransition>? transitions;

  @override
  List<Object?> get props => _props;
}
