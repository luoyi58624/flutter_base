import 'dart:ui' as ui show lerpDouble;

import 'package:flutter/foundation.dart';

/// 长度字段（width / height / minWidth / maxWidth / minHeight / maxHeight）
/// 的归一化值类型。
@immutable
class ElDimension {
  const ElDimension._(this.kind, this.pxPart, this.percentPart);

  /// 未声明（user 不写 / 写 null / 字符串无法解析时的兜底）。
  static const ElDimension auto = ElDimension._(ElLengthKind.auto, 0.0, 0.0);

  /// 像素值。
  const ElDimension.pixels(double v) : this._(ElLengthKind.pixels, v, 0.0);

  /// 百分比（[v] = 80.0 表示 80%）。
  const ElDimension.percent(double v) : this._(ElLengthKind.percent, 0.0, v);

  /// CSS `calc(px + percent%)` 形态。
  ///
  /// **不**作为 public construction shape —— 仅 [lerp] 跨 kind 时生成，
  /// user 直接写 `calc` 字面量目前不接（[parse] 返回 [auto]）。
  const ElDimension.calc(double pxPart, double percentPart) : this._(ElLengthKind.calc, pxPart, percentPart);

  /// 类型。
  final ElLengthKind kind;

  /// 像素分量。pixels 时 = 数值；percent 时 = 0；calc 时 = px 部分；auto 无意义。
  final double pxPart;

  /// 百分比分量。percent 时 = ratio（80 = 80%）；calc 时 = percent 部分；
  /// pixels / auto 时 = 0。
  final double percentPart;

  /// 解析公共输入：`num` / `String` / `null` / 现成 [ElDimension]。
  static ElDimension? parse(Object? value) {
    if (value == null) return null;
    if (value is ElDimension) return value.isAuto ? null : value;
    if (value is num) {
      return ElDimension.pixels(value.toDouble());
    }
    if (value is String) {
      final text = value.trim();
      if (text.endsWith('%')) {
        final percent = double.tryParse(text.substring(0, text.length - 1).trim());
        return percent == null ? null : ElDimension.percent(percent);
      }
      final pixels = double.tryParse(text);
      if (pixels != null) return ElDimension.pixels(pixels);
    }
    return null;
  }

  /// 折算为像素。
  double? resolve(double available) {
    return switch (kind) {
      ElLengthKind.auto => null,
      ElLengthKind.pixels => pxPart,
      ElLengthKind.percent => available.isFinite ? available * percentPart / 100.0 : null,
      ElLengthKind.calc => available.isFinite ? pxPart + available * percentPart / 100.0 : null,
    };
  }

  /// 是否 auto。
  bool get isAuto => kind == ElLengthKind.auto;

  /// 是否负值（用于 adjuster clamp）。auto 不视为负。
  ///
  /// pixels / percent / calc：任一分量为负即视为负。
  bool get isNegative {
    if (kind == ElLengthKind.auto) return false;
    return pxPart < 0 || percentPart < 0;
  }

  /// 同 kind 数值插值；跨 kind 用 [calc] 形态做 lazy 像素插值。
  ///
  /// auto 与 非 auto 之间走 snap（auto 无法 calc）。
  static ElDimension lerp(ElDimension a, ElDimension b, double t) {
    if (identical(a, b)) return a;

    // auto 一侧 → snap，calc 无法跨 auto
    if (a.kind == ElLengthKind.auto || b.kind == ElLengthKind.auto) {
      return t < 0.5 ? a : b;
    }

    // 同类型保留原类型，跨类型保留像素和百分比两部分，布局时才折算。
    return ElDimension._(
      a.kind == b.kind ? a.kind : ElLengthKind.calc,
      ui.lerpDouble(a.pxPart, b.pxPart, t)!,
      ui.lerpDouble(a.percentPart, b.percentPart, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ElDimension && other.kind == kind && other.pxPart == pxPart && other.percentPart == percentPart;

  @override
  int get hashCode => Object.hash(kind, pxPart, percentPart);

  @override
  String toString() => switch (kind) {
    ElLengthKind.auto => 'ElDimension.auto',
    ElLengthKind.pixels => 'ElDimension.pixels($pxPart)',
    ElLengthKind.percent => 'ElDimension.percent($percentPart%)',
    ElLengthKind.calc => 'ElDimension.calc($pxPart + $percentPart%)',
  };
}

/// [ElDimension] 的四态枚举。
enum ElLengthKind { auto, pixels, percent, calc }
