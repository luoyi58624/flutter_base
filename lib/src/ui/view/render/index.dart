import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../style/index.dart';

/// 包内单子盒模型，独立承担约束求值、自动尺寸测量与绘制。
class ViewRenderBox extends RenderShiftedBox {
  ViewRenderBox(this._style, this._direction) : super(null) {
    _values = [
      for (final field in ElTransitionField.values)
        field.read(_style, _direction),
    ];
  }

  ElStyle _style;
  TextDirection _direction;
  late final List<Object?> _values;
  StyleEngine? _animation;
  TickerModeData _tickerMode = TickerModeData.fallback;
  bool _disabled = false, _needsSnapshot = false, _dependsOnReference = false;
  bool _hasReferenceDependents = false;
  int _damage = 0;
  double? _referenceWidth, _referenceHeight;
  BoxConstraints? _lastConstraints;
  Size _boxSize = Size.zero;

  T _get<T>(ElTransitionField field, [List<Object?>? values]) =>
      (values ?? _values)[field.index] as T;

  void configure(TickerModeData mode, bool disabled) {
    _tickerMode = mode;
    _disabled = disabled;
    _configureAnimation();
    if (disabled) _animation?.finish();
  }

  void update(ElStyle style, TextDirection direction) {
    if (_style == style && _direction == direction) return;
    _style = style;
    _direction = direction;
    final next = [
      for (final field in ElTransitionField.values)
        field.read(style, direction),
    ];
    final transitions = style.transitions ?? const <ElTransition>[];
    final animate = hasSize && !_disabled && transitions.isNotEmpty;
    if (animate && _animation == null) {
      _animation = StyleEngine(
        _values,
        captureFrom: _captureFrom,
        invalidate: _invalidate,
      );
      _configureAnimation();
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

  void _configureAnimation() => _animation?.configure(
    enabled: attached && _tickerMode.enabled,
    forceFrames: _tickerMode.forceFrames,
  );

  StyleLength _captureFrom(ElTransitionField field, StyleLength? value) =>
      _unresolved(field, value) ? styleLength(_usedLength(field)) : value!;

  double _available(bool horizontal, double bound) {
    if (bound.isFinite) return bound;
    _dependsOnReference = true;
    for (RenderObject? node = parent; node != null; node = node.parent) {
      if (node is ViewRenderBox) {
        node._hasReferenceDependents = true;
        final value = horizontal ? node._referenceWidth : node._referenceHeight;
        if (value != null) return value;
      }
    }
    return bound;
  }

  double _usedLength(ElTransitionField field) =>
      field == ElTransitionField.width ? _boxSize.width : _boxSize.height;

  double? _resolve(StyleLength? value, bool horizontal, double bound) =>
      value?.resolve(value.relative ? _available(horizontal, bound) : 0);

  bool _unresolved(ElTransitionField field, Object? value) {
    if (value == null) return true;
    final m = _get<EdgeInsets>(ElTransitionField.margin);
    final c = constraints.deflate(m);
    final horizontal = field == ElTransitionField.width;
    return _resolve(
          value as StyleLength,
          horizontal,
          horizontal ? c.maxWidth : c.maxHeight,
        ) ==
        null;
  }

  ({BoxConstraints box, BoxConstraints inner, EdgeInsets p, EdgeInsets m})
  _constraints(BoxConstraints outer, List<Object?> values) {
    final p = _get<EdgeInsets>(ElTransitionField.padding, values);
    final m = _get<EdgeInsets>(ElTransitionField.margin, values);
    final c = outer.deflate(m);
    final w = _resolve(
      _get<StyleLength?>(ElTransitionField.width, values),
      true,
      c.maxWidth,
    );
    final h = _resolve(
      _get<StyleLength?>(ElTransitionField.height, values),
      false,
      c.maxHeight,
    );
    final box = BoxConstraints.tightFor(width: w, height: h).enforce(c);
    // 沿用旧版：显式尺寸仅限制 child 的上限；未声明的轴透传父最小约束。
    final inner = BoxConstraints(
      minWidth: w == null ? box.minWidth : 0,
      maxWidth: box.maxWidth,
      minHeight: h == null ? box.minHeight : 0,
      maxHeight: box.maxHeight,
    ).deflate(p);
    return (box: box, inner: inner, p: p, m: m);
  }

  void _setReferences(double? width, double? height) {
    if (_referenceWidth == width && _referenceHeight == height) return;
    _referenceWidth = width;
    _referenceHeight = height;
    void invalidate(RenderObject node) {
      if (node is ViewRenderBox && node._dependsOnReference) {
        node.markNeedsLayout();
      }
      node.visitChildren(invalidate);
    }

    // 参照可能穿过约束不变的 Flex；布局期间必须通过官方回调使后代失效。
    if (hasSize && _hasReferenceDependents) {
      invokeLayoutCallback<BoxConstraints>((_) => visitChildren(invalidate));
    }
  }

  Size _measureBox(
    BoxConstraints outer,
    List<Object?> values, {
    required bool dry,
  }) {
    final c = _constraints(outer, values);
    if (!dry) {
      _setReferences(
        c.box.hasTightWidth
            ? math.max(0, c.box.maxWidth - c.p.horizontal)
            : null,
        c.box.hasTightHeight
            ? math.max(0, c.box.maxHeight - c.p.vertical)
            : null,
      );
      child?.layout(c.inner, parentUsesSize: true);
      if (child != null) {
        (child!.parentData! as BoxParentData).offset =
            c.m.topLeft + c.p.topLeft;
      }
    }
    final content = dry ? child?.getDryLayout(c.inner) : child?.size;
    return c.box.constrain(c.p.inflateSize(content ?? Size.zero));
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

  double _intrinsic(
    bool horizontal,
    double extent,
    double Function(double)? measure,
  ) {
    final p = _get<EdgeInsets>(ElTransitionField.padding),
        m = _get<EdgeInsets>(ElTransitionField.margin);
    final field = horizontal
        ? ElTransitionField.width
        : ElTransitionField.height;
    final fixed = _resolve(
      _get<StyleLength?>(field),
      horizontal,
      double.infinity,
    );
    final margin = horizontal ? m.horizontal : m.vertical;
    if (fixed != null) return fixed + margin;
    final availableCross = math.max(
      0.0,
      extent - (horizontal ? m.vertical : m.horizontal),
    );
    final cross =
        _resolve(
          _get<StyleLength?>(
            horizontal ? ElTransitionField.height : ElTransitionField.width,
          ),
          !horizontal,
          availableCross,
        ) ??
        availableCross;
    return (measure?.call(
              math.max(0, cross - (horizontal ? p.vertical : p.horizontal)),
            ) ??
            0) +
        margin +
        (horizontal ? p.horizontal : p.vertical);
  }

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
    _configureAnimation();
    markNeedsLayout();
  }

  @override
  void detach() {
    super.detach();
    _configureAnimation();
  }

  @override
  void dispose() {
    _animation?.dispose();
    super.dispose();
  }
}
