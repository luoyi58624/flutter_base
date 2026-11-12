import 'package:flutter/foundation.dart' show protected;
import 'package:flutter/rendering.dart';

/// 在布局子节点前提供内容区尺寸，供无界轴上的百分比长度读取最近祖先参照。
///
/// **契约**：
/// - 值语义 = content box 尺寸（已减 padding），双轴独立；该轴尺寸不可知
///   （shrink-wrap）时传 null 表示不提供该轴参照。
/// - 提供者仅在 performLayout 排 children 之前登记；dry layout / intrinsic
///   遍历读到的是**上一真实布局帧**的值，不做登记，不影响正确性（percent
///   在 intrinsic 通道本就退化为 undefined）。
mixin LayoutReferenceBox on RenderBox {
  static const _widthAxis = 1;
  static const _heightAxis = 2;

  double? _referenceWidth;
  double? _referenceHeight;
  int _changedReferenceAxes = 0;

  /// 当前布局是否使用祖先宽度参照。
  @protected
  bool get dependsOnAncestorReferenceWidth;

  /// 当前布局是否使用祖先高度参照。
  @protected
  bool get dependsOnAncestorReferenceHeight;

  /// 更新参照并返回是否变化，调用方可在首次布局时跳过后代通知。
  @protected
  bool setLayoutReference(double? width, double? height) {
    _changedReferenceAxes =
        (_referenceWidth == width ? 0 : _widthAxis) | (_referenceHeight == height ? 0 : _heightAxis);
    _referenceWidth = width;
    _referenceHeight = height;
    return _changedReferenceAxes != 0;
  }

  /// 只唤醒依赖变化轴的后代，遇到该轴的近层参照时停止向下传播。
  @protected
  void markSubtreeNeedsLayoutForReference() {
    var axes = _changedReferenceAxes;
    if (axes == 0) return;
    void visit(RenderObject node) {
      final inheritedAxes = axes;
      if (node is LayoutReferenceBox) {
        if ((axes & _widthAxis != 0 && node.dependsOnAncestorReferenceWidth) ||
            (axes & _heightAxis != 0 && node.dependsOnAncestorReferenceHeight)) {
          node.markNeedsLayout();
        }
        // 近层提供者若也依赖祖先，会在自己的布局中继续发布参照变化。
        if (node._referenceWidth != null) axes &= ~_widthAxis;
        if (node._referenceHeight != null) axes &= ~_heightAxis;
      }
      if (axes != 0) node.visitChildren(visit);
      axes = inheritedAxes;
    }

    // Flex 等夹层可能维持相同约束；只标记实际消费者，让 Flutter 沿父链安排必要布局。
    invokeLayoutCallback<Constraints>((_) {
      visitChildren(visit);
    });
  }

  /// 沿 parent 链爬到最近提供**宽度参照**的祖先——按轴独立（width 与 height
  /// 参照可来自不同提供者）。到根仍无提供者则返回 null（后代退回 auto，
  /// 兜底不变）。
  static double? ancestorReferenceWidth(RenderObject? node) {
    for (var n = node?.parent; n != null; n = n.parent) {
      if (n is LayoutReferenceBox) {
        final w = n._referenceWidth;
        if (w != null) return w;
      }
    }
    return null;
  }

  /// 沿 parent 链爬到最近提供**高度参照**的祖先。
  static double? ancestorReferenceHeight(RenderObject? node) {
    for (var n = node?.parent; n != null; n = n.parent) {
      if (n is LayoutReferenceBox) {
        final h = n._referenceHeight;
        if (h != null) return h;
      }
    }
    return null;
  }
}
