import 'dart:ui' show Offset, Rect, TextPosition;

import 'package:flutter/animation.dart' show Curves;

/// 把编辑器局部坐标命中为最接近的文本位置。
typedef EditableFloatingCursorHitTest = TextPosition Function(Offset localPoint);

/// 返回指定文本位置在编辑器局部坐标中的真实 caret 矩形。
typedef EditableFloatingCursorCaretRectResolver = Rect Function(TextPosition position);

/// 浮动光标一次拖动或回落帧的纯几何快照。
final class EditableFloatingCursorFrame {
  /// 创建不可变的浮动光标几何快照。
  const EditableFloatingCursorFrame({
    required this.cursorAnchor,
    required this.freeRect,
    required this.placeholderRect,
    required this.snappedPosition,
    required this.resetProgress,
    required this.isComplete,
    required this.shouldCollapseSelection,
  });

  /// 自由 caret prototype 在编辑器局部坐标中的 shift 锚点。
  ///
  /// 这不是 [freeRect] 的中心：Flutter 平台协议以 caret prototype 的原点
  /// 平移，命中位置还需要向下补半个首选行高。
  final Offset cursorAnchor;

  /// 自由拖动中的光标矩形；回落阶段为当前位置的插值矩形。
  final Rect freeRect;

  /// 命中文本位置对应的真实 caret 矩形，供占位光标绘制。
  final Rect placeholderRect;

  /// 自由光标当前吸附到的文本位置。
  final TextPosition snappedPosition;

  /// 回落动画的曲线进度；自由拖动时为 null，回落时取值 0..1。
  final double? resetProgress;

  /// 本帧是否已经结束回落，调用方应在该帧移除浮动光标。
  final bool isComplete;

  /// 完成后是否应把主选区折叠到 [snappedPosition]。
  ///
  /// 双指浮动选区会在拖动中形成非折叠选区，因此完成帧只提供决策，模型本身
  /// 不写 controller。
  final bool shouldCollapseSelection;

  /// 浮动光标与占位 caret 相距不足 15px 时是否应隐藏占位 caret。
  bool get hidePlaceholder =>
      EditableFloatingCursorState.shouldHidePlaceholder(floatingRect: freeRect, placeholderRect: placeholderRect);
}

enum _FloatingCursorPhase { idle, dragging, settling }

/// iOS 浮动光标的纯状态与几何内核。
///
/// 本类不依赖 Widget、RenderObject 或 controller：视图层注入命中与 caret
/// 几何，模型层只在完成帧根据 [EditableFloatingCursorFrame.shouldCollapseSelection]
/// 决定是否写入选区。
final class EditableFloatingCursorState {
  /// 对齐 Flutter EditableText 的回落时长。
  static const Duration resetDuration = Duration(milliseconds: 125);

  /// 对齐 iOS/Flutter 的浮动光标与占位 caret 最短并存距离。
  static const double placeholderHideDistance = 15.0;

  static const double _placeholderHideDistanceSquared = placeholderHideDistance * placeholderHideDistance;

  // 对齐 Flutter `_kFloatingCursorSizeIncrease`：自由拖动时比普通 caret
  // 横向每侧多 0.5px、纵向每侧多 1px；回落由 Rect.lerp 连尺寸一起收缩。
  static const double _floatingHorizontalIncrease = 0.5;
  static const double _floatingVerticalIncrease = 1.0;

  _FloatingCursorPhase _phase = _FloatingCursorPhase.idle;
  Object? _controllerToken;
  int? _documentRevision;
  Offset? _pointOrigin;
  Offset? _startCaretCenter;
  Offset? _floatingCursorOffset;
  Rect? _floatingPrototype;
  Offset? _cursorAnchor;
  EditableFloatingCursorFrame? _frame;

  // 边界外的原始拖动距离不能在回拖时造成跳变：反向第一步只把边界重新设为
  // 相对原点，之后的位移才从边界继续进入编辑框。
  Offset _relativeOrigin = Offset.zero;
  Offset? _previousRawAnchor;
  bool _shouldResetOrigin = true;
  bool _resetOriginOnLeft = false;
  bool _resetOriginOnRight = false;
  bool _resetOriginOnTop = false;
  bool _resetOriginOnBottom = false;

  Rect? _settleFromRect;
  Offset? _settleFromAnchor;

  /// 当前是否存在拖动或回落会话。
  bool get isActive => _phase != _FloatingCursorPhase.idle;

  /// 当前是否处于自由拖动阶段。
  bool get isDragging => _phase == _FloatingCursorPhase.dragging;

  /// 当前是否处于 125ms 回落阶段。
  bool get isSettling => _phase == _FloatingCursorPhase.settling;

  /// 当前可绘制快照；空闲或完成后为 null。
  EditableFloatingCursorFrame? get frame => _frame;

  /// 本次会话开始时的 caret 中心；空闲时为 null。
  Offset? get startCaretCenter => _startCaretCenter;

  /// 本次会话的平台点原点；空闲时为 null。
  Offset? get pointOrigin => _pointOrigin;

  /// 当前自由 caret 的 prototype shift 锚点；空闲时为 null。
  Offset? get cursorAnchor => _cursorAnchor;

  /// 浮动光标与占位 caret 中心距离小于 15px 时返回 true。
  ///
  /// 严格使用 `< 15`，恰好 15px 时仍允许两个 caret 同时绘制。
  static bool shouldHidePlaceholder({required Rect floatingRect, required Rect placeholderRect}) {
    return (floatingRect.center - placeholderRect.center).distanceSquared < _placeholderHideDistanceSquared;
  }

  /// 开始一次浮动光标会话并缓存 caret 中心与平台点原点。
  ///
  /// [anchorBounds] 描述 caret prototype **平移锚点**允许到达的编辑器局部
  /// 区域；调用方可在传入前计入平台 margin、padding 与滚动条占位。
  /// [preferredLineHeight] 决定锚点到平台命中点的半行高偏移。
  /// [startCaretCenter] 为空时使用当前 [caretRect] 中心；带平台 startLocation
  /// 的长按入口传其局部坐标并把 [resetRelativeOrigin] 设为 false。
  bool start({
    required Offset pointOrigin,
    required Rect caretRect,
    required TextPosition caretPosition,
    required double preferredLineHeight,
    required Rect anchorBounds,
    required Object controllerToken,
    required int documentRevision,
    Offset? startCaretCenter,
    bool resetRelativeOrigin = true,
  }) {
    assert(pointOrigin.isFinite);
    assert(caretRect.isFinite);
    assert(preferredLineHeight.isFinite && preferredLineHeight > 0);
    assert(anchorBounds.isFinite);
    assert(startCaretCenter == null || startCaretCenter.isFinite);
    assert(documentRevision >= 0);

    _clear();
    _phase = _FloatingCursorPhase.dragging;
    _controllerToken = controllerToken;
    _documentRevision = documentRevision;
    _pointOrigin = pointOrigin;
    _startCaretCenter = startCaretCenter ?? caretRect.center;
    _floatingCursorOffset = Offset(0, preferredLineHeight / 2);
    _floatingPrototype = Rect.fromLTRB(
      -_floatingHorizontalIncrease,
      -_floatingVerticalIncrease,
      caretRect.width + _floatingHorizontalIncrease,
      caretRect.height + _floatingVerticalIncrease,
    );
    _shouldResetOrigin = resetRelativeOrigin;

    final rawAnchor = _startCaretCenter! - _floatingCursorOffset!;
    final boundedAnchor = _calculateBoundedAnchor(rawAnchor, anchorBounds);
    _cursorAnchor = boundedAnchor;
    final freeRect = _rectAtAnchor(boundedAnchor);
    _frame = EditableFloatingCursorFrame(
      cursorAnchor: boundedAnchor,
      freeRect: freeRect,
      placeholderRect: caretRect,
      snappedPosition: caretPosition,
      resetProgress: null,
      isComplete: false,
      shouldCollapseSelection: false,
    );
    return true;
  }

  /// 按平台点相对 Start 原点的位移更新自由光标与吸附位置。
  ///
  /// Update-before-Start、回落中的迟到 Update 与失效会话都返回 false；控制器
  /// 身份或 revision 失效时会同步取消旧会话。
  bool update({
    required Offset point,
    required Rect anchorBounds,
    required EditableFloatingCursorHitTest hitTest,
    required EditableFloatingCursorCaretRectResolver caretRectForPosition,
    required Object controllerToken,
    required int documentRevision,
  }) {
    assert(point.isFinite);
    assert(anchorBounds.isFinite);
    if (!_validateSession(controllerToken, documentRevision)) return false;
    if (_phase != _FloatingCursorPhase.dragging) return false;

    final rawAnchor = _startCaretCenter! + (point - _pointOrigin!) - _floatingCursorOffset!;
    final boundedAnchor = _calculateBoundedAnchor(rawAnchor, anchorBounds);
    final snappedPosition = hitTest(boundedAnchor + _floatingCursorOffset!);
    final placeholderRect = caretRectForPosition(snappedPosition);
    assert(placeholderRect.isFinite);
    _cursorAnchor = boundedAnchor;
    _frame = EditableFloatingCursorFrame(
      cursorAnchor: boundedAnchor,
      freeRect: _rectAtAnchor(boundedAnchor),
      placeholderRect: placeholderRect,
      snappedPosition: snappedPosition,
      resetProgress: null,
      isComplete: false,
      shouldCollapseSelection: false,
    );
    return true;
  }

  /// 结束自由拖动并进入 125ms 回落；重复或乱序 End 为幂等 no-op。
  bool end({required Object controllerToken, required int documentRevision}) {
    if (!_validateSession(controllerToken, documentRevision)) return false;
    if (_phase != _FloatingCursorPhase.dragging) return false;
    final current = _frame!;
    _phase = _FloatingCursorPhase.settling;
    _settleFromRect = current.freeRect;
    _settleFromAnchor = current.cursorAnchor;
    _frame = EditableFloatingCursorFrame(
      cursorAnchor: current.cursorAnchor,
      freeRect: current.freeRect,
      placeholderRect: current.placeholderRect,
      snappedPosition: current.snappedPosition,
      resetProgress: 0,
      isComplete: false,
      shouldCollapseSelection: false,
    );
    return true;
  }

  /// 返回 End 后指定绝对耗时的回落帧。
  ///
  /// 进度按 [Curves.decelerate] 映射；达到 125ms 时返回唯一完成帧并清理会话。
  /// [selectionCollapsed] 必须读取完成瞬间的最新主选区，不能复用 End 时快照；
  /// [caretRectForPosition] 每帧重算目标，保证滚动、resize 或重排期间不会回落
  /// 到 End 时的旧坐标。
  EditableFloatingCursorFrame? settle({
    required Duration elapsed,
    required bool selectionCollapsed,
    required EditableFloatingCursorCaretRectResolver caretRectForPosition,
    required Object controllerToken,
    required int documentRevision,
  }) {
    if (!_validateSession(controllerToken, documentRevision)) return null;
    if (_phase != _FloatingCursorPhase.settling) return null;

    final micros = elapsed.inMicroseconds.clamp(0, resetDuration.inMicroseconds);
    final linearProgress = micros / resetDuration.inMicroseconds;
    final progress = linearProgress >= 1 ? 1.0 : Curves.decelerate.transform(linearProgress);
    final current = _frame!;
    final placeholderRect = caretRectForPosition(current.snappedPosition);
    assert(placeholderRect.isFinite);
    final freeRect = Rect.lerp(_settleFromRect, placeholderRect, progress)!;
    final targetAnchor = placeholderRect.centerLeft - _floatingCursorOffset!;
    final cursorAnchor = Offset.lerp(_settleFromAnchor, targetAnchor, progress)!;
    final complete = linearProgress >= 1;
    final result = EditableFloatingCursorFrame(
      cursorAnchor: cursorAnchor,
      freeRect: freeRect,
      placeholderRect: placeholderRect,
      snappedPosition: current.snappedPosition,
      resetProgress: progress,
      isComplete: complete,
      shouldCollapseSelection: complete && selectionCollapsed,
    );
    if (complete) {
      _clear();
    } else {
      _frame = result;
    }
    return result;
  }

  /// 在滚动或 viewport 改变后，用当前自由锚点重新命中正文。
  ///
  /// 本方法不改平台点原点、越界相对原点或上一笔原始 delta，因此后续 Update
  /// 仍沿用同一手势轨迹。仅拖动阶段有效；回落阶段的目标由 [settle] 每帧重算。
  bool reproject({
    required Rect anchorBounds,
    required EditableFloatingCursorHitTest hitTest,
    required EditableFloatingCursorCaretRectResolver caretRectForPosition,
    required Object controllerToken,
    required int documentRevision,
  }) {
    assert(anchorBounds.isFinite);
    if (!_validateSession(controllerToken, documentRevision)) return false;
    if (_phase != _FloatingCursorPhase.dragging) return false;

    final boundedAnchor = _clamp(_cursorAnchor!, anchorBounds);
    final snappedPosition = hitTest(boundedAnchor + _floatingCursorOffset!);
    final placeholderRect = caretRectForPosition(snappedPosition);
    assert(placeholderRect.isFinite);
    _cursorAnchor = boundedAnchor;
    _frame = EditableFloatingCursorFrame(
      cursorAnchor: boundedAnchor,
      freeRect: _rectAtAnchor(boundedAnchor),
      placeholderRect: placeholderRect,
      snappedPosition: snappedPosition,
      resetProgress: null,
      isComplete: false,
      shouldCollapseSelection: false,
    );
    return true;
  }

  /// 控制器身份或正文 revision 已变化时取消会话并返回 true。
  ///
  /// 控制器 token 使用 identity 而非 `==`，避免相等值对象误续接旧编辑器会话。
  bool cancelIfInvalid({required Object controllerToken, required int documentRevision}) {
    if (!isActive || _matches(controllerToken, documentRevision)) return false;
    _clear();
    return true;
  }

  /// 幂等取消当前拖动或回落会话；确有活动会话时返回 true。
  bool cancel() {
    if (!isActive) return false;
    _clear();
    return true;
  }

  bool _validateSession(Object controllerToken, int documentRevision) {
    if (!isActive) return false;
    if (_matches(controllerToken, documentRevision)) return true;
    _clear();
    return false;
  }

  bool _matches(Object controllerToken, int documentRevision) {
    return identical(_controllerToken, controllerToken) && _documentRevision == documentRevision;
  }

  Rect _rectAtAnchor(Offset anchor) => _floatingPrototype!.shift(anchor);

  Offset _calculateBoundedAnchor(Offset rawAnchor, Rect bounds) {
    if (!_shouldResetOrigin) return _clamp(rawAnchor, bounds);

    final previous = _previousRawAnchor;
    final delta = previous == null ? Offset.zero : rawAnchor - previous;

    // 越界后的反向第一步只吃掉不可见的越界距离，从而避免光标从边界跳进正文。
    if (_resetOriginOnLeft && delta.dx > 0) {
      _relativeOrigin = Offset(rawAnchor.dx - bounds.left, _relativeOrigin.dy);
      _resetOriginOnLeft = false;
    } else if (_resetOriginOnRight && delta.dx < 0) {
      _relativeOrigin = Offset(rawAnchor.dx - bounds.right, _relativeOrigin.dy);
      _resetOriginOnRight = false;
    }
    if (_resetOriginOnTop && delta.dy > 0) {
      _relativeOrigin = Offset(_relativeOrigin.dx, rawAnchor.dy - bounds.top);
      _resetOriginOnTop = false;
    } else if (_resetOriginOnBottom && delta.dy < 0) {
      _relativeOrigin = Offset(_relativeOrigin.dx, rawAnchor.dy - bounds.bottom);
      _resetOriginOnBottom = false;
    }

    final current = rawAnchor - _relativeOrigin;
    final adjusted = _clamp(current, bounds);
    if (current.dx < bounds.left && delta.dx < 0) {
      _resetOriginOnLeft = true;
    } else if (current.dx > bounds.right && delta.dx > 0) {
      _resetOriginOnRight = true;
    }
    if (current.dy < bounds.top && delta.dy < 0) {
      _resetOriginOnTop = true;
    } else if (current.dy > bounds.bottom && delta.dy > 0) {
      _resetOriginOnBottom = true;
    }
    _previousRawAnchor = rawAnchor;
    return adjusted;
  }

  static Offset _clamp(Offset point, Rect bounds) =>
      Offset(point.dx.clamp(bounds.left, bounds.right), point.dy.clamp(bounds.top, bounds.bottom));

  void _clear() {
    _phase = _FloatingCursorPhase.idle;
    _controllerToken = null;
    _documentRevision = null;
    _pointOrigin = null;
    _startCaretCenter = null;
    _floatingCursorOffset = null;
    _floatingPrototype = null;
    _cursorAnchor = null;
    _frame = null;
    _relativeOrigin = Offset.zero;
    _previousRawAnchor = null;
    _shouldResetOrigin = true;
    _resetOriginOnLeft = false;
    _resetOriginOnRight = false;
    _resetOriginOnTop = false;
    _resetOriginOnBottom = false;
    _settleFromRect = null;
    _settleFromAnchor = null;
  }
}
