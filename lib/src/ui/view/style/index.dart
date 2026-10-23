import 'dart:math' as math;
import 'dart:ui' show ColorSpace, lerpDouble;

import 'package:equatable/equatable.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/dart.dart';

import '../layout/box_layout.dart';
import 'resolved/layout.dart';

part 'index.g.dart';
part 'transition.dart';
part 'lerp.dart';
part 'style_engine.dart';
part 'fields.dart';

/// 不可变的盒模型样式；宽高包含 padding，不包含 margin。
@immutable
@ElModelGenerator.copy()
class ElStyle with Equatable {
  /// 创建样式，集合参数应保持不可变。
  const ElStyle({
    this.width,
    this.height,
    this.backgroundColor,
    this.padding,
    this.margin,
    this.transitions,
  });

  /// 逻辑像素数值或百分比字符串；null 表示自动宽度。
  final Object? width;

  /// 逻辑像素数值或百分比字符串；null 表示自动高度。
  final Object? height;

  /// 背景色，覆盖内容和 padding；null 表示不绘制。
  final Color? backgroundColor;

  /// 非负有限内边距，支持方向性边距；null 等同于零。
  final EdgeInsetsGeometry? padding;

  /// 非负有限外边距，背景不覆盖此区域；null 等同于零。
  final EdgeInsetsGeometry? margin;

  /// 过渡声明，合并时整体替换；同一属性由最后一条匹配声明决定。
  final List<ElTransition>? transitions;

  @override
  List<Object?> get props => _props;
}
