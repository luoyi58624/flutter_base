import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../style/index.dart';

part 'layout.dart';

/// 包内单子盒模型，独立承担约束求值、自动尺寸测量与绘制。
class ElRenderView extends RenderShiftedBox {
  /// 创建单子盒模型渲染对象。
  ElRenderView(this._style, this._direction) : super(null) {
    _values = [
      for (final field in ElTransitionField.values)
        field.read(_style, _direction),
    ];
  }

  ElStyle _style;
  TextDirection _direction;
  late final List<Object?> _values;
  StyleEngine? _animation;
  bool _needsSnapshot = false, _dependsOnReference = false;
  bool _hasReferenceDependents = false;
  int _damage = 0;
  double? _referenceWidth, _referenceHeight;
  BoxConstraints? _lastConstraints;
  Size _boxSize = Size.zero;

  T _get<T>(ElTransitionField field, [List<Object?>? values]) =>
      (values ?? _values)[field.index] as T;

  /// 应用目标样式与边距方向，已布局的属性变化按 transitions 过渡。
  void applyStyle(ElStyle style, {required TextDirection textDirection}) {
    if (_style == style && _direction == textDirection) return;
    _style = style;
    _direction = textDirection;
    final next = [
      for (final field in ElTransitionField.values)
        field.read(style, textDirection),
    ];
    final transitions = style.transitions ?? const <ElTransition>[];
    final animate = hasSize && transitions.isNotEmpty;
    if (animate && _animation == null) {
      _animation = StyleEngine(
        _values,
        captureFrom: _captureFrom,
        invalidate: _invalidate,
      );
    }
    if (_animation != null) {
      _animation!.update(next, transitions, animate);
    } else {
      for (final field in ElTransitionField.values) {
        _write(field, next[field.index]);
      }
      _flushDamage();
    }
  }

  void _write(ElTransitionField field, Object? value) {
    if (_values[field.index] == value) return;
    _values[field.index] = value;
    _damage |= field.damage;
  }

  void _flushDamage() {
    _invalidate(_damage);
    _damage = 0;
  }

  void _invalidate(int damage) {
    if (damage & StyleEngine.measure != 0) _needsSnapshot = true;
    if (damage & (StyleEngine.layout | StyleEngine.measure) != 0) {
      super.markNeedsLayout();
    }
    if (damage & StyleEngine.paint != 0) markNeedsPaint();
  }

  void _setReferences(double? width, double? height) {
    if (_referenceWidth == width && _referenceHeight == height) return;
    _referenceWidth = width;
    _referenceHeight = height;
    void invalidate(RenderObject node) {
      if (node is ElRenderView && node._dependsOnReference) {
        node.markNeedsLayout();
      }
      node.visitChildren(invalidate);
    }

    // 参照可能穿过约束不变的 Flex；布局期间必须通过官方回调使后代失效。
    if (hasSize && _hasReferenceDependents) {
      invokeLayoutCallback<BoxConstraints>((_) => visitChildren(invalidate));
    }
  }

  @override
  void performLayout() {
    final animation = _animation;
    if (animation != null &&
        (_needsSnapshot || _lastConstraints != constraints)) {
      Size? targetSize;
      for (final track in animation.active) {
        if (!track.field.isLength) continue;
        var current = _values[track.field.index];
        final lostReference = _unresolved(track.field, current);
        if (lostReference) {
          // 父约束变为无界时冻结已呈现尺寸，不能让混合百分比突然退回 auto。
          current = _values[track.field.index] = styleLength(
            _usedLength(track.field),
          );
        }
        if (!_unresolved(track.field, track.target)) {
          track.snapshot(
            track.target! as StyleLength,
            current,
            force: lostReference,
          );
          continue;
        }
        // 必须等 child 更新完成再测量，不能在 style setter 中读取旧 child。
        targetSize ??= _measureBox(constraints, animation.targets, dry: false);
        track.snapshot(
          styleLength(
            track.field == ElTransitionField.width
                ? targetSize.width
                : targetSize.height,
          ),
          current,
          force: lostReference,
        );
      }
    }
    _needsSnapshot = false;
    _lastConstraints = constraints;
    _boxSize = _measureBox(constraints, _values, dry: false);
    size = constraints.constrain(
      _get<EdgeInsets>(ElTransitionField.margin).inflateSize(_boxSize),
    );
  }

  @override
  void markNeedsLayout() {
    _needsSnapshot = true;
    super.markNeedsLayout();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(
    _get<EdgeInsets>(ElTransitionField.margin)
        .inflateSize(_measureBox(constraints, _values, dry: true)),
  );

  @override
  double computeMinIntrinsicWidth(double height) =>
      _intrinsic(true, height, child?.getMinIntrinsicWidth);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _intrinsic(true, height, child?.getMaxIntrinsicWidth);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsic(false, width, child?.getMinIntrinsicHeight);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsic(false, width, child?.getMaxIntrinsicHeight);

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final c = _constraints(constraints, _values);
    final value = child?.getDryBaseline(c.inner, baseline);
    return value == null ? null : value + c.p.top + c.m.top;
  }

  Rect get _backgroundRect =>
      _get<EdgeInsets>(ElTransitionField.margin).topLeft & _boxSize;

  @override
  void paint(PaintingContext context, Offset offset) {
    final color = _get<Color?>(ElTransitionField.backgroundColor);
    if (color != null) {
      context.canvas.drawRect(
        _backgroundRect.shift(offset),
        Paint()..color = color,
      );
    }
    super.paint(context, offset);
  }

  @override
  bool hitTestSelf(Offset position) =>
      _get<Color?>(ElTransitionField.backgroundColor) != null &&
      _backgroundRect.contains(position);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    markNeedsLayout();
  }

  @override
  void dispose() {
    _animation?.dispose();
    super.dispose();
  }
}
