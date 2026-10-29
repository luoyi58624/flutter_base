import 'package:flutter/widgets.dart';

/// 锚定方位（floating-ui `placement` 口径）：主轴四边 × 交叉轴三档。
///
/// 不带后缀 = 交叉轴居中；`Start`/`End` = 交叉轴对齐锚的起始/结束边
/// （水平交叉轴按物理左右，不做 RTL 翻转——弹层几何对齐视觉稳定优先）。
enum ElPlacement {
  /// 锚上方，水平居中。
  top,

  /// 锚上方，左缘对齐。
  topStart,

  /// 锚上方，右缘对齐。
  topEnd,

  /// 锚下方，水平居中。
  bottom,

  /// 锚下方，左缘对齐。
  bottomStart,

  /// 锚下方，右缘对齐。
  bottomEnd,

  /// 锚左侧，垂直居中。
  left,

  /// 锚左侧，上缘对齐。
  leftStart,

  /// 锚左侧，下缘对齐。
  leftEnd,

  /// 锚右侧，垂直居中。
  right,

  /// 锚右侧，上缘对齐。
  rightStart,

  /// 锚右侧，下缘对齐。
  rightEnd;

  /// 主轴所在边。
  AxisDirection get side => switch (this) {
    top || topStart || topEnd => AxisDirection.up,
    bottom || bottomStart || bottomEnd => AxisDirection.down,
    left || leftStart || leftEnd => AxisDirection.left,
    right || rightStart || rightEnd => AxisDirection.right,
  };

  /// 交叉轴对齐档。
  Alignment get align => switch (this) {
    topStart || bottomStart || leftStart || rightStart => Alignment.topLeft,
    topEnd || bottomEnd || leftEnd || rightEnd => Alignment.bottomRight,
    _ => Alignment.center,
  };

  /// 主轴翻到对侧后的方位（交叉轴档保持）。
  ElPlacement get flipped => switch (this) {
    top => bottom,
    topStart => bottomStart,
    topEnd => bottomEnd,
    bottom => top,
    bottomStart => topStart,
    bottomEnd => topEnd,
    left => right,
    leftStart => rightStart,
    leftEnd => rightEnd,
    right => left,
    rightStart => leftStart,
    rightEnd => leftEnd,
  };
}

/// 锚定定位配置（floating-ui 语义子集）。
///
/// 解算发生在弹层 layout 期（拿弹层实测尺寸决策），锚移动/滚动/resize 由
/// 官方 Portal 的布局信息驱动重解算。
@immutable
class ElOverlayAnchor {
  /// 创建锚定配置。
  const ElOverlayAnchor({
    this.placement = ElPlacement.bottom,
    this.offset = 0,
    this.crossOffset = 0,
    this.flip = true,
    this.shift = true,
    this.viewportPadding = 8,
    this.matchWidth = false,
    this.matchMinWidth = false,
  });

  /// 首选方位。
  final ElPlacement placement;

  /// 主轴间距（锚与弹层之间）。
  final double offset;

  /// 交叉轴微调（沿交叉轴正方向平移）。
  final double crossOffset;

  /// 首选侧空间不足且对侧更大时翻转到对侧。
  final bool flip;

  /// 交叉轴钳制进视口（减去 [viewportPadding]）。
  final bool shift;

  /// 视口内边距（flip 判定与 shift 钳制的安全边）。
  final double viewportPadding;

  /// 弹层宽度锁定为锚宽（select 下拉同宽）。
  final bool matchWidth;

  /// 弹层最小宽度抬到锚宽。与 [matchWidth] 同时声明时 [matchWidth] 胜出。
  final bool matchMinWidth;

  /// 按面板实测尺寸解算位置，先翻转再将两个轴钳进视口安全区。
  ElOverlayAnchorGeometry resolve(Rect anchorRect, Size childSize, Size viewport) {
    final pad = viewportPadding;
    double sideSpace(AxisDirection side) => switch (side) {
      AxisDirection.up => anchorRect.top - pad,
      AxisDirection.down => viewport.height - pad - anchorRect.bottom,
      AxisDirection.left => anchorRect.left - pad,
      AxisDirection.right => viewport.width - pad - anchorRect.right,
    };
    var effective = placement;
    if (flip) {
      final needed =
          ((axisDirectionToAxis(effective.side) == Axis.vertical) ? childSize.height : childSize.width) + offset;
      final space = sideSpace(effective.side);
      if (needed > space && sideSpace(effective.flipped.side) > space) effective = effective.flipped;
    }
    final main = switch (effective.side) {
      AxisDirection.up => anchorRect.top - offset - childSize.height,
      AxisDirection.down => anchorRect.bottom + offset,
      AxisDirection.left => anchorRect.left - offset - childSize.width,
      AxisDirection.right => anchorRect.right + offset,
    };
    final alignment =
        effective.align.alongOffset(Offset(anchorRect.width - childSize.width, anchorRect.height - childSize.height)) +
        anchorRect.topLeft;
    final cross = (axisDirectionToAxis(effective.side) == Axis.vertical ? alignment.dx : alignment.dy) + crossOffset;
    var position = (axisDirectionToAxis(effective.side) == Axis.vertical) ? Offset(cross, main) : Offset(main, cross);
    if (shift) {
      position = Offset(
        position.dx.clamp(pad, (viewport.width - pad - childSize.width).clamp(pad, double.infinity)),
        position.dy.clamp(pad, (viewport.height - pad - childSize.height).clamp(pad, double.infinity)),
      );
    }
    final overlayRect = position & childSize;
    final local = anchorRect.center - overlayRect.topLeft;
    final arrow = switch (effective.side) {
      AxisDirection.up => Offset(local.dx.clamp(0, childSize.width), childSize.height),
      AxisDirection.down => Offset(local.dx.clamp(0, childSize.width), 0),
      AxisDirection.left => Offset(childSize.width, local.dy.clamp(0, childSize.height)),
      AxisDirection.right => Offset(0, local.dy.clamp(0, childSize.height)),
    };
    return (placement: effective, anchorRect: anchorRect, overlayRect: overlayRect, arrowTarget: arrow);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ElOverlayAnchor) return false;
    return placement == other.placement &&
        offset == other.offset &&
        crossOffset == other.crossOffset &&
        flip == other.flip &&
        shift == other.shift &&
        viewportPadding == other.viewportPadding &&
        matchWidth == other.matchWidth &&
        matchMinWidth == other.matchMinWidth;
  }

  @override
  int get hashCode =>
      Object.hash(placement, offset, crossOffset, flip, shift, viewportPadding, matchWidth, matchMinWidth);
}

/// Overlay 坐标下的解算结果：实际方位、锚矩形、面板矩形和箭头目标。
typedef ElOverlayAnchorGeometry = ({ElPlacement placement, Rect anchorRect, Rect overlayRect, Offset arrowTarget});
