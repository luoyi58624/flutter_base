import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 锚定方位：主轴四边 × 交叉轴三档。
///
/// 不带后缀表示交叉轴居中；Start / End 对齐锚的起始或结束边，水平交叉轴按物理左右，不随 RTL 翻转。
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

  /// 主轴翻到对侧后的方位，交叉轴档保持。
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

  /// 交叉轴起止对调后的方位，居中档保持。
  ElPlacement get crossFlipped => switch (this) {
    topStart => topEnd,
    topEnd => topStart,
    bottomStart => bottomEnd,
    bottomEnd => bottomStart,
    leftStart => leftEnd,
    leftEnd => leftStart,
    rightStart => rightEnd,
    rightEnd => rightStart,
    _ => this,
  };
}

/// 锚定定位配置：方位、间距、翻转、平移钳制、宽度跟随与覆盖目标。
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
    this.cover = false,
  });

  /// 首选方位。
  final ElPlacement placement;

  /// 主轴间距，沿方位方向远离锚。
  final double offset;

  /// 交叉轴微调，沿交叉轴正方向平移。
  final double crossOffset;

  /// 首选侧放不下且对侧更宽裕时翻到对侧；交叉轴起止对齐越界而对调后放得下时一并对调。
  final bool flip;

  /// 翻转后仍越界时把面板钳进视口安全区，必要时与锚重叠。
  final bool shift;

  /// 视口内边距，翻转判定与钳制都在它以内进行。
  final double viewportPadding;

  /// 面板宽度锁定为锚宽，例如选择器下拉与输入框同宽。
  final bool matchWidth;

  /// 面板最小宽度抬到锚宽；与 [matchWidth] 同时声明时 [matchWidth] 胜出。
  final bool matchMinWidth;

  /// 面板覆盖锚自身：主轴起点从锚的近边改为远边，例如安卓溢出菜单从按钮所在位置向下展开。
  final bool cover;

  bool get _vertical => axisDirectionToAxis(placement.side) == Axis.vertical;

  /// 锚在 [side] 一侧可供面板使用的主轴空间。
  double _space(AxisDirection side, Rect anchor, Rect area) => switch (side) {
    AxisDirection.up => (cover ? anchor.bottom : anchor.top) - offset - area.top,
    AxisDirection.down => area.bottom - (cover ? anchor.top : anchor.bottom) - offset,
    AxisDirection.left => (cover ? anchor.right : anchor.left) - offset - area.left,
    AxisDirection.right => area.right - (cover ? anchor.left : anchor.right) - offset,
  };

  /// 面板布局约束：交叉轴不超过视口，主轴不超过可翻转两侧中较宽裕的一侧，超出部分由面板内部滚动。
  BoxConstraints constraints(Rect anchorRect, Rect viewport) {
    final area = viewport.deflate(viewportPadding);
    final side = placement.side;
    var main = _space(side, anchorRect, area);
    if (flip) main = math.max(main, _space(placement.flipped.side, anchorRect, area));
    // 两侧都放不下时允许钳制后与锚重叠，主轴最多用到整个安全区。
    if (shift && main <= 0) main = _vertical ? area.height : area.width;
    final maxMain = math.max(0.0, main);
    var result = _vertical
        ? BoxConstraints(maxWidth: math.max(0.0, area.width), maxHeight: maxMain)
        : BoxConstraints(maxWidth: maxMain, maxHeight: math.max(0.0, area.height));
    final width = math.min(anchorRect.width, result.maxWidth);
    if (matchWidth) {
      result = result.copyWith(minWidth: width, maxWidth: width);
    } else if (matchMinWidth) {
      result = result.copyWith(minWidth: width);
    }
    return result;
  }

  /// 按面板实测尺寸解算位置：先按主轴空间翻转，再处理交叉轴起止对调，最后把两个轴钳进视口安全区。
  ElOverlayAnchorGeometry resolve(Rect anchorRect, Size childSize, Rect viewport) {
    final area = viewport.deflate(viewportPadding);
    final vertical = _vertical;
    var effective = placement;
    if (flip) {
      final needed = vertical ? childSize.height : childSize.width;
      final space = _space(effective.side, anchorRect, area);
      if (needed > space && _space(effective.flipped.side, anchorRect, area) > space) effective = effective.flipped;
    }
    final main = switch (effective.side) {
      AxisDirection.up => (cover ? anchorRect.bottom : anchorRect.top) - offset - childSize.height,
      AxisDirection.down => (cover ? anchorRect.top : anchorRect.bottom) + offset,
      AxisDirection.left => (cover ? anchorRect.right : anchorRect.left) - offset - childSize.width,
      AxisDirection.right => (cover ? anchorRect.left : anchorRect.right) + offset,
    };
    double crossOf(ElPlacement placement) {
      final aligned = placement.align.alongOffset(
        Offset(anchorRect.width - childSize.width, anchorRect.height - childSize.height),
      );
      return (vertical ? anchorRect.left + aligned.dx : anchorRect.top + aligned.dy) + crossOffset;
    }

    final low = vertical ? area.left : area.top;
    final high = (vertical ? area.right - childSize.width : area.bottom - childSize.height);
    bool fits(double value) => value >= low && value <= high;
    var cross = crossOf(effective);
    if (flip && !fits(cross) && effective.crossFlipped != effective && fits(crossOf(effective.crossFlipped))) {
      effective = effective.crossFlipped;
      cross = crossOf(effective);
    }
    var position = vertical ? Offset(cross, main) : Offset(main, cross);
    if (shift) {
      position = Offset(
        position.dx.clamp(area.left, math.max(area.left, area.right - childSize.width)),
        position.dy.clamp(area.top, math.max(area.top, area.bottom - childSize.height)),
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

  /// 复制并替换部分配置。
  ElOverlayAnchor copyWith({
    ElPlacement? placement,
    double? offset,
    double? crossOffset,
    bool? flip,
    bool? shift,
    double? viewportPadding,
    bool? matchWidth,
    bool? matchMinWidth,
    bool? cover,
  }) => ElOverlayAnchor(
    placement: placement ?? this.placement,
    offset: offset ?? this.offset,
    crossOffset: crossOffset ?? this.crossOffset,
    flip: flip ?? this.flip,
    shift: shift ?? this.shift,
    viewportPadding: viewportPadding ?? this.viewportPadding,
    matchWidth: matchWidth ?? this.matchWidth,
    matchMinWidth: matchMinWidth ?? this.matchMinWidth,
    cover: cover ?? this.cover,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElOverlayAnchor &&
          placement == other.placement &&
          offset == other.offset &&
          crossOffset == other.crossOffset &&
          flip == other.flip &&
          shift == other.shift &&
          viewportPadding == other.viewportPadding &&
          matchWidth == other.matchWidth &&
          matchMinWidth == other.matchMinWidth &&
          cover == other.cover;

  @override
  int get hashCode =>
      Object.hash(placement, offset, crossOffset, flip, shift, viewportPadding, matchWidth, matchMinWidth, cover);
}

/// Overlay 坐标下的解算结果：实际方位、锚矩形、面板矩形和面板内指向锚中心的箭头落点。
typedef ElOverlayAnchorGeometry = ({ElPlacement placement, Rect anchorRect, Rect overlayRect, Offset arrowTarget});
