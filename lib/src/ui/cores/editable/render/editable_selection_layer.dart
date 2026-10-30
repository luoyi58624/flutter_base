import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../../flutter/views/scroll/common/viewport/scroll_viewport.dart';
import '../../../../flutter/views/layout/geometry/pixel_grid.dart';
import '../composer.dart';
import 'editable_line_view.dart';
import 'editable_render_scope.dart';

/// 视口统一绘制编辑状态，正文继续复用每行自己的绘制缓存。
final class EditableSelectionLayer extends SingleChildRenderObjectWidget {
  /// 创建不参与公开 API 的编辑状态绘制层。
  const EditableSelectionLayer({super.key, required this.scope, this.beforePaint, required super.child});

  /// 当前编辑器的行与绘制状态协调器。
  final EditableRenderScope scope;

  /// 绘制前按本帧最终坐标同步选区，不依赖滚动是否触发行布局。
  final VoidCallback? beforePaint;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderEditableSelectionLayer(scope, beforePaint);

  @override
  void updateRenderObject(BuildContext context, RenderEditableSelectionLayer renderObject) {
    renderObject.scope = scope;
    renderObject.beforePaint = beforePaint;
  }
}

/// 只读取已挂载行，几何取自实际行盒，避免另算行高导致累积偏差。
final class RenderEditableSelectionLayer extends RenderProxyBox {
  /// 创建编辑状态绘制宿主。
  RenderEditableSelectionLayer(this._scope, this.beforePaint);

  /// 只同步选区与行内绘制状态，不能改变布局尺寸。
  VoidCallback? beforePaint;
  bool _syncingSelection = false;

  @override
  void markNeedsPaint() {
    if (!_syncingSelection) super.markNeedsPaint();
  }

  EditableRenderScope _scope;
  ScrollViewport? _viewport;
  final _foregroundClip = LayerHandle<ClipRectLayer>();

  /// 当前编辑器协调器；换绑时迁移监听与行绘制所有权。
  EditableRenderScope get scope => _scope;
  set scope(EditableRenderScope value) {
    if (identical(value, _scope)) return;
    if (attached) _unbind();
    _scope = value;
    if (attached) _bind();
    markNeedsLayout();
  }

  @override
  bool get isRepaintBoundary => true;

  void _bind() {
    assert(_scope.repaintSelectionLayer == null);
    _scope.repaintSelectionLayer = markNeedsPaint;
    _scope.addListener(markNeedsPaint);
  }

  void _unbind() {
    if (_scope.repaintSelectionLayer == markNeedsPaint) _scope.repaintSelectionLayer = null;
    _scope.removeListener(markNeedsPaint);
    _viewport?.scrollOffsetListenable.removeListener(markNeedsPaint);
    _viewport = null;
  }

  @override
  void attach(PipelineOwner owner) {
    _bind();
    super.attach(owner);
  }

  @override
  void detach() {
    _unbind();
    super.detach();
  }

  @override
  void dispose() {
    _foregroundClip.layer = null;
    super.dispose();
  }

  @override
  void performLayout() {
    super.performLayout();
    _syncViewport();
  }

  void _syncViewport() {
    ScrollViewport? next;
    for (final line in _scope.mountedLines.values) {
      if (!line.attached) continue;
      for (RenderObject? node = line.parent; node != null && node != this; node = node.parent) {
        if (node is ScrollViewport) {
          next = node;
          break;
        }
      }
      if (next != null) break;
    }
    if (identical(next, _viewport)) return;
    _viewport?.scrollOffsetListenable.removeListener(markNeedsPaint);
    _viewport = next;
    next?.scrollOffsetListenable.addListener(markNeedsPaint);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    _syncingSelection = true;
    try {
      beforePaint?.call();
    } finally {
      _syncingSelection = false;
    }
    _syncViewport();
    final viewport = _viewport;
    final clip = viewport == null
        ? Offset.zero & size
        : MatrixUtils.transformRect(
            viewport.getTransformTo(this),
            viewport.contentViewportRect,
          ).intersect(Offset.zero & size);
    final visible = <({RenderEditableLine line, Offset origin, Rect rect, bool fillsLine, double height})>[];
    for (final line in _scope.mountedLines.values) {
      if (!line.attached || !line.hasSize || !line.paintsEditingInLayer) continue;
      final origin = MatrixUtils.transformPoint(line.getTransformTo(this), Offset.zero);
      final fillsLine = line.selectionFillsLine;
      final height = _scope.usesFixedLineHeight && viewport != null
          ? snapVirtualItemExtentToPixelGrid(line.size.height, viewport.position.context.devicePixelRatio)
          : line.size.height;
      final rect = Rect.fromLTWH(origin.dx, origin.dy, line.size.width, height).intersect(clip);
      if (rect.isEmpty) continue;
      visible.add((line: line, origin: origin, rect: rect, fillsLine: fillsLine, height: height));
    }

    // 单一纯文本选区的完整中段恒连续，直接取窗口内并集，无需排序各行。
    final continuous =
        _scope.controller.selections.single &&
        _scope.config.composer == EditableComposer.plain &&
        _scope.config.selectionTextColor == null;
    if (!continuous) visible.sort((a, b) => a.origin.dy.compareTo(b.origin.dy));
    final canvas = context.canvas;
    canvas.save();
    canvas.clipRect(clip.shift(offset));
    Rect? middle;
    final paint = Paint()
      ..color = _scope.config.selectionColor
      ..isAntiAlias = false;
    void flushMiddle() {
      if (middle == null) return;
      canvas.drawRect(middle!.shift(offset), paint);
      assert(() {
        RenderEditableLine.debugSelectionPaintCount++;
        return true;
      }());
      middle = null;
    }

    for (final entry in visible) {
      if (entry.fillsLine) {
        final rect = entry.rect;
        if (middle != null &&
            (continuous ||
                (middle!.bottom - rect.top).abs() < 1e-6 && middle!.left == rect.left && middle!.right == rect.right)) {
          middle = middle!.expandToInclude(rect);
        } else {
          flushMiddle();
          middle = rect;
        }
      }
    }
    flushMiddle();
    for (final entry in visible) {
      entry.line.paintEditingBackground(
        canvas,
        offset + entry.origin,
        skipSelection: entry.fillsLine,
        lineExtent: entry.height,
      );
    }
    canvas.restore();

    context.paintChild(child!, offset);

    // 保留的合成层必须用 ClipRectLayer 裁剪，Canvas.clipRect 无法裁剪兄弟合成层。
    _foregroundClip.layer = context.pushClipRect(true, offset, clip, (context, offset) {
      for (final entry in visible) {
        entry.line.paintRetainedEditingForeground(context, offset + entry.origin);
      }
      final canvas = context.canvas;
      for (final entry in visible) {
        entry.line.paintEditingIndicators(canvas, offset + entry.origin);
      }
    }, oldLayer: _foregroundClip.layer);
  }
}
