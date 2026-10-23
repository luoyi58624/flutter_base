import 'dart:math' as math;
import 'dart:ui' show ColorSpace, lerpDouble;

import 'package:equatable/equatable.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/dart.dart';

import '../layout/box_layout.dart';
import 'resolved/layout.dart';
import 'resolved/outline.dart';

part 'index.g.dart';
part 'transition.dart';
part 'lerp.dart';
part 'style_engine.dart';
part 'fields.dart';
part 'outline.dart';

/// 不可变的盒模型样式；宽高包含 padding，不包含 margin。
@immutable
@ElModelGenerator.copy()
class ElStyle with Equatable {
  /// 创建样式，集合参数应保持不可变。
  const ElStyle({
    this.width,
    this.height,
    this.widthFactor,
    this.heightFactor,
    this.backgroundColor,
    this.padding,
    this.margin,
    this.border,
    this.outline,
    this.borderRadius,
    this.clipBehavior,
    this.transitions,
  });

  /// 逻辑像素数值或百分比字符串；null 表示自动宽度。
  final Object? width;

  /// 逻辑像素数值或百分比字符串；null 表示自动高度。
  final Object? height;

  /// 非负有限的自然盒宽度倍数，包含 padding；null 等同于 1，显式宽度优先。
  final num? widthFactor;

  /// 非负有限的自然盒高度倍数，包含 padding；null 等同于 1，显式高度优先。
  final num? heightFactor;

  /// 背景色，覆盖内容和 padding；null 表示不绘制。
  final Color? backgroundColor;

  /// 非负有限内边距，支持方向性边距；null 等同于零。
  final EdgeInsetsGeometry? padding;

  /// 非负有限外边距，背景不覆盖此区域；null 等同于零。
  final EdgeInsetsGeometry? margin;

  /// 原生 Border 或 BorderDirectional，仅覆盖绘制、不占布局；null 表示无边框。
  /// 粗细必须非负且有限，strokeAlign 必须有限；零宽 solid 保留原生 hairline。
  final BoxBorder? border;

  /// 盒外轮廓，仅绘制、不占布局；偏移可将其移入盒内，null 表示不绘制。
  final ElOutline? outline;

  /// 非负有限的背景与边框圆角，支持方向性圆角；裁剪由 clipBehavior 决定。
  final BorderRadiusGeometry? borderRadius;

  /// 背景与 child 的裁剪方式；null 等同于 Clip.none，模式切换不参与过渡。
  final Clip? clipBehavior;

  /// 过渡声明，合并时整体替换；同一属性由最后一条匹配声明决定。
  final List<ElTransition>? transitions;

  @override
  List<Object?> get props => _props;
}
