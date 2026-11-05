import 'package:flutter/foundation.dart' show ValueListenable, visibleForTesting;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../render/editable_render_scope.dart';
import 'editable_floating_cursor_state.dart';

/// 在编辑器正文之后绘制 iOS 浮动光标，并把光标裁在编辑器边界内。
final class EditableFloatingCursorOverlay extends SingleChildRenderObjectWidget {
  /// 创建只监听浮动光标帧、不会重建正文子树的绘制层。
  const EditableFloatingCursorOverlay({
    super.key,
    required this.frame,
    required this.caretColor,
    this.scope,
    required super.child,
  });

  /// 当前浮动光标帧；null 表示不绘制。
  final ValueListenable<EditableFloatingCursorFrame?> frame;

  /// 浮动光标的基准颜色。
  final Color caretColor;

  /// 主题绘制通道，颜色变化直接重绘光标。
  final EditableRenderScope? scope;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderEditableFloatingCursorOverlay(frame, caretColor)..scope = scope;

  @override
  void updateRenderObject(BuildContext context, RenderEditableFloatingCursorOverlay renderObject) {
    renderObject
      ..frame = frame
      ..caretColor = caretColor
      ..scope = scope;
  }
}

/// 浮动光标的单 child 绘制宿主；正文先画，光标后画。
final class RenderEditableFloatingCursorOverlay extends RenderProxyBox {
  /// 创建浮动光标绘制宿主。
  RenderEditableFloatingCursorOverlay(this._frame, this._caretColor) : _active = _frame.value != null;

  ValueListenable<EditableFloatingCursorFrame?> _frame;
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
  Paint? _floatingPaint;
  Paint? _placeholderPaint;

  /// 当前帧通道；换绑时会安全迁移重绘监听。
  ValueListenable<EditableFloatingCursorFrame?> get frame => _frame;
  set frame(ValueListenable<EditableFloatingCursorFrame?> value) {
    if (identical(value, _frame)) return;
    if (attached) _frame.removeListener(_handleFrameChanged);
    _frame = value;
    if (attached) _frame.addListener(_handleFrameChanged);
    _syncActiveState();
  }

  /// 浮动光标的基准颜色。
  Color get caretColor => _scope?.config.caretColor ?? _caretColor;
  set caretColor(Color value) {
    if (value == _caretColor) return;
    _caretColor = value;
    markNeedsPaint();
  }

  /// 测试探针：当前实际参与绘制的浮动帧。
  @visibleForTesting
  EditableFloatingCursorFrame? get debugFrame => _frame.value;

  @override
  bool get isRepaintBoundary => _active;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scope?.addListener(markNeedsPaint);
    _frame.addListener(_handleFrameChanged);
    _syncActiveState();
  }

  @override
  void detach() {
    _scope?.removeListener(markNeedsPaint);
    _frame.removeListener(_handleFrameChanged);
    super.detach();
  }

  void _handleFrameChanged() {
    _syncActiveState();
    markNeedsPaint();
  }

  void _syncActiveState() {
    final active = _frame.value != null;
    if (_active == active) return;
    _active = active;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    // Portal 的 fallback chrome 允许越出正文边界；只裁本层新画的两根光标，
    // 不能顺手把 child 的 handle / magnifier / toolbar 一起截断。
    context.paintChild(child!, offset);
    final frame = _frame.value;
    if (frame == null) return;
    context.pushClipRect(needsCompositing, offset, offset & size, (context, offset) {
      final canvas = context.canvas;
      if (frame.resetProgress == null && !frame.hidePlaceholder) {
        canvas.drawRect(
          frame.placeholderRect.shift(offset),
          (_placeholderPaint ??= Paint())..color = caretColor.withValues(alpha: caretColor.a * 0.25),
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(frame.freeRect.shift(offset), const Radius.circular(1)),
        (_floatingPaint ??= Paint())..color = caretColor.withValues(alpha: caretColor.a * 0.75),
      );
    }, clipBehavior: Clip.hardEdge);
  }
}
