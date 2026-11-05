import 'package:flutter/rendering.dart';

import '../../../utils/internal/bit_mask.dart';
import '../render/hit_bounds.dart';
import 'inheritance/inheritable_node.dart';
import 'inheritance/propagator.dart';
import 'internal/field_spec.dart';

/// damage 路由：cascade 后比较 committed vs target，按字段 damage 通道
/// 触发布局、绘制与语义更新，并向后代传播 inherit damage。
abstract final class DamageRouter {
  /// 路由变化字段集到本节点的 dirty 通道 + 向后代传播 inherit。
  static void route({
    required RenderBox host,
    required FieldMask changedMask,
    required InheritableNode inheritableHost,
    FieldMask themeAnimationMask = FieldMask.empty,
  }) {
    if (changedMask.isEmpty) return;

    if (maskAnd(changedMask, layoutAffectingMask).isNotEmpty) host.markNeedsLayout();
    if (maskAnd(changedMask, paintAffectingMask).isNotEmpty) host.markNeedsPaint();
    if (maskAnd(changedMask, hitBoundsAffectingPaintOnlyMask).isNotEmpty) {
      // 变换不会重新布局，必须主动刷新子树语义，避免保留动画起始坐标。
      host.markNeedsSemanticsUpdate();
      final h = host;
      if (h is ElOverflowHitBounds) h.markHitBoundsDirty();
    }

    final inheritMask = maskAnd(changedMask, inheritedFieldsMask);
    if (inheritMask.isEmpty) return;
    InheritancePropagator.propagate(
      inheritableHost,
      inheritMask,
      themeAnimationMask: maskAnd(themeAnimationMask, inheritMask),
    );
  }
}
