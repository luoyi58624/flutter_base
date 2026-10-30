// 虚拟挂载对账使用的既有 slot、range 与 remap 记录。
// ignore_for_file: prefer_initializing_formals

part of '../virtual_pipeline.dart';

class _ScrollElementSlot {
  const _ScrollElementSlot(this.key, this.previousChild, {this.sourceIndex});

  final Object key;
  final Element? previousChild;
  final int? sourceIndex;

  @override
  bool operator ==(Object other) {
    return other is _ScrollElementSlot &&
        other.key == key &&
        other.sourceIndex == sourceIndex &&
        identical(other.previousChild, previousChild);
  }

  @override
  int get hashCode => Object.hash(key, identityHashCode(previousChild), sourceIndex);
}

class _VirtualIndexRange {
  const _VirtualIndexRange(this.start, this.end);

  final int start;
  final int end;
}

class _VirtualChildChangeSpan {
  const _VirtualChildChangeSpan({required this.start, required this.deleteCount, required this.insertCount});

  final int start;
  final int deleteCount;
  final int insertCount;
}

/// Granular result of [_recomputeVisibleRangeWithDetail]: callers can decide
/// whether to do a full Widget rebuild (mounted set changes) or a cheap
/// render-direct push (only paint/semantic bounds shifted).
class _VirtualVisibleRangeUpdate {
  const _VirtualVisibleRangeUpdate({
    required this.rangeChanged,
    required this.paintChanged,
    required this.retainedFocusChanged,
  });

  /// True when the mounted index window [_firstIndex, _lastIndex] shifted.
  /// The slot list must be regenerated, which requires a full setState.
  final bool rangeChanged;

  /// True when only the paint-side bounds (visibleContent*, semantic*) moved.
  /// These can be pushed straight to the render object without a rebuild.
  final bool paintChanged;

  /// True when the selection retention anchor/focus range mutated, which also
  /// changes the mounted set and therefore requires a setState.
  final bool retainedFocusChanged;

  bool get anyChanged => rangeChanged || paintChanged || retainedFocusChanged;

  bool get requiresRebuild => rangeChanged || retainedFocusChanged;
}

class _VirtualExtentEnvironment {
  const _VirtualExtentEnvironment({
    required this.crossAxisExtent,
    required this.textScaler,
    required this.textDirection,
  });

  final double crossAxisExtent;
  final TextScaler textScaler;
  final TextDirection? textDirection;

  /// Cross-axis size jitter under this many logical pixels is treated as the
  /// same layout environment, so transient 1px wobble from intrinsic layouts
  /// does not discard all measured row extents on every frame.
  static const double _crossAxisHysteresisPx = 1.0;

  /// Whether [next] represents a meaningful environment change that should
  /// invalidate cached row measurements. Uses a hysteresis threshold on the
  /// cross-axis so sub-pixel jitter is absorbed without re-measuring.
  bool requiresMeasurementReset(_VirtualExtentEnvironment next) {
    if (requiresImmediateMeasurementReset(next)) return true;
    return (next.crossAxisExtent - crossAxisExtent).abs() >= _crossAxisHysteresisPx;
  }

  /// Text scale and direction can change row metrics even when the reported
  /// size for currently mounted rows has not arrived yet, so they still need an
  /// eager reset. Cross-axis width changes are validated by real child reports
  /// to avoid a first-resize offset drift when row heights are unchanged.
  bool requiresImmediateMeasurementReset(_VirtualExtentEnvironment next) {
    if (textScaler != next.textScaler) return true;
    if (textDirection != next.textDirection) return true;
    return false;
  }

  @override
  bool operator ==(Object other) {
    // Exact equality: tolerance-based == cannot satisfy the hashCode contract,
    // and sub-pixel jitter is already absorbed by the hysteresis in
    // [requiresMeasurementReset], not here.
    return other is _VirtualExtentEnvironment &&
        other.crossAxisExtent == crossAxisExtent &&
        other.textScaler == textScaler &&
        other.textDirection == textDirection;
  }

  @override
  int get hashCode => Object.hash(crossAxisExtent, textScaler, textDirection);
}
