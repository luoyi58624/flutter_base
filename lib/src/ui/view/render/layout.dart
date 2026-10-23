part of 'view.dart';

extension _ViewLayout on ElRenderView {
  StyleLength _captureFrom(ElTransitionField field, StyleLength? value) =>
      _unresolved(field, value) ? styleLength(_usedLength(field)) : value!;

  double _available(bool horizontal, double bound) {
    if (bound.isFinite) return bound;
    _dependsOnReference = true;
    for (RenderObject? node = parent; node != null; node = node.parent) {
      if (node is ElRenderView) {
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
}
