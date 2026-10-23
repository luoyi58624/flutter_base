import 'dart:math' as math;
import 'dart:ui';

import '../style/resolved/filter.dart';

/// 按有效数值缓存原生滤镜，颜色矩阵和模糊仅在实际使用时创建。
class FilterResource {
  FilterStyle? _style;
  ImageFilter? _filter;

  /// 构建先颜色后模糊的滤镜，恒等声明直接返回空。
  ImageFilter? resolve(FilterStyle value) {
    if (_style == value) return _filter;
    _style = value;
    final matrix = _colorMatrix(value);
    final ImageFilter? color = matrix == null
        ? null
        : ColorFilter.matrix(matrix);
    final ImageFilter? blur = value.blurX == 0 && value.blurY == 0
        ? null
        : ImageFilter.blur(
            sigmaX: value.blurX,
            sigmaY: value.blurY,
            tileMode: TileMode.decal,
          );
    return _filter = color == null
        ? blur
        : blur == null
        ? color
        : ImageFilter.compose(outer: blur, inner: color);
  }

  static List<double>? _colorMatrix(FilterStyle value) {
    List<double>? matrix;
    void mul(List<double> next) =>
        matrix = matrix == null ? next : _multiply(next, matrix!);
    void rgb(double gain, double offset) {
      final m = matrix ??= _identityMatrix();
      // 这几种效果只缩放 RGB 行并加偏移，无需创建再乘一张通用矩阵。
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 5; col++) {
          m[row * 5 + col] *= gain;
        }
        m[row * 5 + 4] += offset;
      }
    }

    if (value.grayscale != 0) {
      final g = 1 - value.grayscale;
      mul([
        0.2126 + 0.7874 * g,
        0.7152 - 0.7152 * g,
        0.0722 - 0.0722 * g,
        0,
        0,
        0.2126 - 0.2126 * g,
        0.7152 + 0.2848 * g,
        0.0722 - 0.0722 * g,
        0,
        0,
        0.2126 - 0.2126 * g,
        0.7152 - 0.7152 * g,
        0.0722 + 0.9278 * g,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]);
    }
    if (value.sepia != 0) {
      final s = 1 - value.sepia;
      mul([
        0.393 + 0.607 * s,
        0.769 - 0.769 * s,
        0.189 - 0.189 * s,
        0,
        0,
        0.349 - 0.349 * s,
        0.686 + 0.314 * s,
        0.168 - 0.168 * s,
        0,
        0,
        0.272 - 0.272 * s,
        0.534 - 0.534 * s,
        0.131 + 0.869 * s,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]);
    }
    if (value.saturate != 1) {
      final s = value.saturate;
      mul([
        0.213 + 0.787 * s,
        0.715 - 0.715 * s,
        0.072 - 0.072 * s,
        0,
        0,
        0.213 - 0.213 * s,
        0.715 + 0.285 * s,
        0.072 - 0.072 * s,
        0,
        0,
        0.213 - 0.213 * s,
        0.715 - 0.715 * s,
        0.072 + 0.928 * s,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]);
    }
    final hue = value.hueRotate % 360;
    if (hue != 0) {
      final radians = hue * math.pi / 180;
      final c = math.cos(radians), s = math.sin(radians);
      mul([
        0.213 + c * 0.787 - s * 0.213,
        0.715 - c * 0.715 - s * 0.715,
        0.072 - c * 0.072 + s * 0.928,
        0,
        0,
        0.213 - c * 0.213 + s * 0.143,
        0.715 + c * 0.285 + s * 0.140,
        0.072 - c * 0.072 - s * 0.283,
        0,
        0,
        0.213 - c * 0.213 - s * 0.787,
        0.715 - c * 0.715 + s * 0.715,
        0.072 + c * 0.928 + s * 0.072,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]);
    }
    if (value.invert != 0) {
      rgb(1 - 2 * value.invert, value.invert * 255);
    }
    if (value.brightness != 1) {
      rgb(value.brightness, 0);
    }
    if (value.contrast != 1) {
      rgb(value.contrast, (1 - value.contrast) * 127.5);
    }
    if (value.opacity != 1) {
      final m = matrix ??= _identityMatrix();
      for (var col = 0; col < 5; col++) {
        m[15 + col] *= value.opacity;
      }
    }
    // Native 最终接收 float 分量，不能让组合溢出变成 NaN 或 Infinity。
    final result = matrix;
    return result != null &&
            result.every((v) => v.isFinite && v.abs() <= 3.4028234663852886e38)
        ? result
        : null;
  }

  static List<double> _identityMatrix() => [
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  static List<double> _multiply(List<double> a, List<double> b) {
    final result = List<double>.filled(20, 0);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 5; col++) {
        var value = col == 4 ? a[row * 5 + 4] : 0.0;
        for (var k = 0; k < 4; k++) {
          value += a[row * 5 + k] * b[k * 5 + col];
        }
        result[row * 5 + col] = value;
      }
    }
    return result;
  }
}
