// 虚拟滚动的边界判据与坐标换算的单一事实来源。
//
// State（`ElScrollView`）、content render、viewport render 三处历史上
// 各持一份**要求逐位一致**的判据数学（贴边、thumb 分数↔边缘、分数→内容
// 偏移、可见窗口）；任一处漂移即出现"拖到底松手回弹"级别的错位。此处收口为
// 纯函数，三方全部委托，容差统一取 [precisionErrorTolerance]。

import 'package:flutter/foundation.dart' show precisionErrorTolerance;

/// thumb 松手时贴住的视觉边缘；null = 不贴边。
///
/// 原 `ElIntegratedScrollbarDragEdge`：集成滚动条整体删除后迁到此处并改名，
/// 消费方只剩 widget 层 thumb 快拖通道。
enum ScrollbarDragEdge { leading, trailing }

/// 滚动位置贴住的逻辑边缘（min = pixels 0 端，max = maxScrollExtent 端）。
enum VirtualScrollEdge { min, max }

/// 虚拟滚动的判据纯函数集合。
abstract final class VirtualScrollGeometry {
  /// 当前滚动位置是否贴边（容差内）。
  ///
  /// [overscrollCountsAsPinned] 区分两处历史口径，差异只在 pixels 越过 max 端
  /// 之后（bouncing 回弹期）：State 的锚点保留用 `.abs()` 判定，越界即视为"不
  /// 贴边"（false）；滚动条的贴边回流用单向判定，越界仍算贴住 max（true）。
  /// 收口时保留两种语义而不是二选一——任一侧改判都会动 bouncing 回弹的落点。
  static VirtualScrollEdge? pinnedEdge(
    double pixels,
    double maxOffset, {
    bool overscrollCountsAsPinned = false,
  }) {
    if (pixels <= precisionErrorTolerance) return VirtualScrollEdge.min;
    final gap = maxOffset - pixels;
    if (overscrollCountsAsPinned ? gap <= precisionErrorTolerance : gap.abs() <= precisionErrorTolerance) {
      return VirtualScrollEdge.max;
    }
    return null;
  }

  /// thumb 轨道分数是否落在两端（0 / 1）。
  static bool isEdgeFraction(double fraction) =>
      fraction <= precisionErrorTolerance || fraction >= 1.0 - precisionErrorTolerance;

  /// thumb 轨道分数 → 滚动位置边缘；反轴时 0 分数对应 max 端。
  static VirtualScrollEdge? edgeForThumbFraction(double fraction, {required bool reversed}) {
    if (fraction <= precisionErrorTolerance) {
      return reversed ? VirtualScrollEdge.max : VirtualScrollEdge.min;
    }
    if (fraction >= 1.0 - precisionErrorTolerance) {
      return reversed ? VirtualScrollEdge.min : VirtualScrollEdge.max;
    }
    return null;
  }

  /// 视觉边缘 → 滚动位置边缘（反轴翻转）。
  static VirtualScrollEdge? edgeForDragEdge(ScrollbarDragEdge? edge, {required bool reversed}) {
    return switch (edge) {
      null => null,
      ScrollbarDragEdge.leading => reversed ? VirtualScrollEdge.max : VirtualScrollEdge.min,
      ScrollbarDragEdge.trailing => reversed ? VirtualScrollEdge.min : VirtualScrollEdge.max,
    };
  }

  /// thumb 轨道分数 → 内容偏移（clamp 到 [0, maxOffset]）。
  static double contentOffsetForFraction(double fraction, double maxOffset) {
    if (maxOffset <= precisionErrorTolerance) return 0.0;
    return (fraction.clamp(0.0, 1.0) * maxOffset).clamp(0.0, maxOffset).toDouble();
  }

  /// position.pixels → 内容坐标（反轴翻转）。
  static double contentFromPixels(double pixels, double maxOffset, {required bool reversed}) =>
      reversed ? maxOffset - pixels : pixels;

  /// 内容坐标 → position.pixels（反轴翻转，与 [contentFromPixels] 互逆）。
  static double pixelsFromContent(double content, double maxOffset, {required bool reversed}) =>
      reversed ? maxOffset - content : content;
}
