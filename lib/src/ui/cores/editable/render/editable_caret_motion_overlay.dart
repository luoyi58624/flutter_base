import 'editable_render_scope.dart';
import 'package:flutter/foundation.dart' show ValueListenable, visibleForTesting;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 在编辑器正文之后绘制位置过渡中的主 caret。
///
/// 静止 caret 仍由行渲染负责；只有 80ms 位置过渡期间才启用本层，因此跨行
/// 动画不受单行 RenderBox 边界限制，也不会改变逻辑 caret 几何。
final class EditableCaretMotionOverlay extends SingleChildRenderObjectWidget {
  /// 创建只监听动画矩形、不会重建正文子树的绘制层。
  const EditableCaretMotionOverlay({
    super.key,
    required this.rect,
    required this.caretColor,
    this.scope,
    required super.child,
  });

  /// 当前动画 caret 的编辑器本地矩形；null 表示由行渲染静态 caret。
  final ValueListenable<Rect?> rect;

  /// 动画 caret 颜色。
  final Color caretColor;

  /// 主题绘制通道，颜色变化直接重绘光标。
  final EditableRenderScope? scope;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderEditableCaretMotionOverlay(rect, caretColor)..scope = scope;

  @override
  void updateRenderObject(BuildContext context, RenderEditableCaretMotionOverlay renderObject) {
    renderObject
      ..rect = rect
      ..caretColor = caretColor
      ..scope = scope;
  }
}

/// 主 caret 位置动画的单 child 绘制宿主。
final class RenderEditableCaretMotionOverlay extends RenderProxyBox {
  /// 创建动画 caret 绘制宿主。
  RenderEditableCaretMotionOverlay(this._rect, this._caretColor) : _active = _rect.value != null;

  ValueListenable<Rect?> _rect;
  Color _caretColor;
  EditableRenderScope? _scope;

  /// 换绑主题来源时同步迁移监听，避免旧编辑器继续驱动重绘。
  set scope(EditableRenderScope? value) {
    if (identical(value, _scope)) return;
    if (attached) _scope?.removeListener(markNeedsPaint);
    _scope = value;
    if (attached) _scope?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  bool _active;
  Paint? _paint;

  /// 当前动画矩形通道；换绑时安全迁移重绘监听。
  ValueListenable<Rect?> get rect => _rect;
  set rect(ValueListenable<Rect?> value) {
    if (identical(value, _rect)) return;
    if (attached) _rect.removeListener(_handleRectChanged);
    _rect = value;
    if (attached) _rect.addListener(_handleRectChanged);
    _syncActiveState();
  }

  /// 动画 caret 颜色。
  Color get caretColor => _scope?.config.caretColor ?? _caretColor;
  set caretColor(Color value) {
    if (value == _caretColor) return;
    _caretColor = value;
    markNeedsPaint();
  }

  /// 测试探针：当前真实参与绘制的编辑器本地动画矩形。
  @visibleForTesting
  Rect? get debugRectForTest => _rect.value;

  @override
  bool get isRepaintBoundary => _active;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scope?.addListener(markNeedsPaint);
    _rect.addListener(_handleRectChanged);
    _syncActiveState();
  }

  @override
  void detach() {
    _scope?.removeListener(markNeedsPaint);
    _rect.removeListener(_handleRectChanged);
    super.detach();
  }

  void _handleRectChanged() {
    _syncActiveState();
    markNeedsPaint();
  }

  void _syncActiveState() {
    final active = _rect.value != null;
    if (_active == active) return;
    _active = active;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    context.paintChild(child!, offset);
    final rect = _rect.value;
    if (rect == null || !rect.isFinite || rect.isEmpty) return;
    context.pushClipRect(needsCompositing, offset, offset & size, (context, offset) {
      context.canvas.drawRect(rect.shift(offset), (_paint ??= Paint())..color = caretColor);
    }, clipBehavior: Clip.hardEdge);
  }
}
