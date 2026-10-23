import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../style/resolved/transform.dart';

/// 将原始变换解析为盒坐标矩阵，绘制、命中和语义共用同一几何结果。
class TransformGeometry {
  Matrix4? _source, _effective, _zero;
  Offset? _pivot, _translation;
  Rect? _box, _paintBounds;
  bool _matrixValid = false, _valid = false;

  /// 当前样本是否可绘制，投影触及或退到视平面后方时为 false。
  bool get valid => _valid;

  /// 只读使用的盒坐标矩阵；无效样本返回零矩阵，避免后代获得错误几何。
  Matrix4 get matrix => _valid ? _effective! : (_zero ??= Matrix4.zero());

  /// 纯平移的偏移量；其他有效矩阵与无效样本返回 null。
  Offset? get translation => _valid ? _translation : null;

  /// 按视觉盒确定原点，绘制边界变化只重验投影，不重建相同矩阵。
  void resolve(TransformStyle style, Rect box, Rect paintBounds) {
    final pivot = box.topLeft + style.alignment.alongSize(box.size);
    final matrixChanged =
        !MatrixUtils.matrixEquals(_source, style.matrix) || _pivot != pivot;
    if (!matrixChanged && _box == box && _paintBounds == paintBounds) return;
    _box = box;
    _paintBounds = paintBounds;
    if (matrixChanged) {
      _source = style.matrix;
      _pivot = pivot;
      _matrixValid =
          pivot.dx.isFinite &&
          pivot.dy.isFinite &&
          style.matrix.storage.every((value) => value.isFinite);
      if (_matrixValid) {
        _effective = Matrix4.translationValues(pivot.dx, pivot.dy, 0)
          ..multiply(style.matrix)
          ..translateByDouble(-pivot.dx, -pivot.dy, 0, 1);
        final determinant = _effective!.determinant();
        _matrixValid =
            determinant != 0 &&
            determinant.isFinite &&
            _effective!.storage.every((value) => value.isFinite);
        _translation = _matrixValid
            ? MatrixUtils.getAsTranslation(_effective!)
            : null;
      }
    }
    _valid =
        _matrixValid && _project(box) != null && _project(paintBounds) != null;
  }

  /// 返回同一有效矩阵的有限投影包围盒；无效输入或投影返回空矩形。
  Rect mapBounds(Rect rect) => _valid ? _project(rect) ?? Rect.zero : Rect.zero;

  Rect? _project(Rect rect) {
    if (!rect.isFinite) return null;
    if (rect.isEmpty) return Rect.zero;
    final m = _effective!.storage;
    if (m[3] != 0 || m[7] != 0 || m[15] != 1) {
      final w00 = m[3] * rect.left + m[7] * rect.top + m[15];
      final w10 = m[3] * rect.right + m[7] * rect.top + m[15];
      final w01 = m[3] * rect.left + m[7] * rect.bottom + m[15];
      final w11 = m[3] * rect.right + m[7] * rect.bottom + m[15];
      final low = math.min(math.min(w00, w10), math.min(w01, w11));
      final high = math.max(math.max(w00, w10), math.max(w01, w11));
      // 有限角点仍可能穿过 w=0；全负 w 也会被后端裁掉，不能保留命中和语义。
      if (!low.isFinite || !high.isFinite || low <= 0) {
        return null;
      }
    }
    final result = _translation == null
        ? MatrixUtils.transformRect(_effective!, rect)
        : rect.shift(_translation!);
    return result.isFinite ? result : null;
  }
}
