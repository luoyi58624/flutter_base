import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'axis_geometry.dart';

/// 网格的轴无关声明，独立布局和滚动段共同使用。
final class GridLayoutGeometry {
  /// 创建共享网格声明；三种轨道数量规则互斥。
  const GridLayoutGeometry({
    this.crossAxisCount,
    this.minCrossAxisExtent,
    this.maxCrossAxisExtent,
    this.mainAxisExtent,
    this.aspectRatio = 1,
    this.rowGap = 0,
    this.columnGap = 0,
  }) : assert(crossAxisCount == null || crossAxisCount > 0),
       assert(minCrossAxisExtent == null || minCrossAxisExtent > 0 && minCrossAxisExtent < double.infinity),
       assert(maxCrossAxisExtent == null || maxCrossAxisExtent > 0 && maxCrossAxisExtent < double.infinity),
       assert(mainAxisExtent == null || mainAxisExtent >= 0 && mainAxisExtent < double.infinity),
       assert(aspectRatio > 0 && aspectRatio < double.infinity),
       assert(rowGap >= 0 && rowGap < double.infinity),
       assert(columnGap >= 0 && columnGap < double.infinity),
       assert(
         (crossAxisCount == null ? 0 : 1) +
                 (minCrossAxisExtent == null ? 0 : 1) +
                 (maxCrossAxisExtent == null ? 0 : 1) <=
             1,
       );

  /// 固定交叉轴轨道数。
  final int? crossAxisCount;

  /// 自动轨道的最小目标尺寸。
  final double? minCrossAxisExtent;

  /// 自动轨道的最大目标尺寸。
  final double? maxCrossAxisExtent;

  /// 固定主轴格尺寸；省略时由物理宽高比推导。
  final double? mainAxisExtent;

  /// 物理宽度与高度之比。
  final double aspectRatio;

  /// 物理纵向间距。
  final double rowGap;

  /// 物理横向间距。
  final double columnGap;

  /// 在交叉轴约束确定时一次算出最终几何，无需构建或测量格子。
  ResolvedGridGeometry resolve({required Axis axis, required double crossExtent, required int itemCount}) {
    assert(itemCount >= 0);
    final mainGap = axis == Axis.vertical ? rowGap : columnGap;
    final crossGap = axis == Axis.vertical ? columnGap : rowGap;
    var cross = crossExtent;
    if (!cross.isFinite && itemCount == 0) cross = 0;
    if (!cross.isFinite) {
      final canResolve = crossAxisCount != null && mainAxisExtent != null;
      assert(canResolve, 'ElGridView 交叉轴无界时必须指定 crossAxisCount 与 mainAxisExtent。');
      if (!canResolve) throw StateError('ElGridView 缺少有限交叉轴尺寸。');
      final cell = axis == Axis.vertical ? mainAxisExtent! * aspectRatio : mainAxisExtent! / aspectRatio;
      cross = crossAxisCount! * cell + (crossAxisCount! - 1) * crossGap;
    }
    cross = math.max(0, cross);
    final tracks =
        crossAxisCount ??
        (minCrossAxisExtent != null
            ? math.max(1, ((cross + crossGap) / (minCrossAxisExtent! + crossGap)).floor())
            : maxCrossAxisExtent != null
            ? math.max(1, ((cross + crossGap) / (maxCrossAxisExtent! + crossGap)).ceil())
            : 1);
    final cellCross = math.max(0.0, (cross - (tracks - 1) * crossGap) / tracks);
    final cellMain = mainAxisExtent ?? (axis == Axis.vertical ? cellCross / aspectRatio : cellCross * aspectRatio);
    return ResolvedGridGeometry(
      axis: axis,
      itemCount: itemCount,
      trackCount: tracks,
      crossExtent: cross,
      cellMainExtent: cellMain,
      cellCrossExtent: cellCross,
      mainGap: mainGap,
      crossGap: crossGap,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GridLayoutGeometry &&
      crossAxisCount == other.crossAxisCount &&
      minCrossAxisExtent == other.minCrossAxisExtent &&
      maxCrossAxisExtent == other.maxCrossAxisExtent &&
      mainAxisExtent == other.mainAxisExtent &&
      aspectRatio == other.aspectRatio &&
      rowGap == other.rowGap &&
      columnGap == other.columnGap;

  @override
  int get hashCode => Object.hash(
    crossAxisCount,
    minCrossAxisExtent,
    maxCrossAxisExtent,
    mainAxisExtent,
    aspectRatio,
    rowGap,
    columnGap,
  );
}

/// 固定网格的最终几何；存储量与条目数量无关。
final class ResolvedGridGeometry {
  /// 创建已解析的网格几何。
  const ResolvedGridGeometry({
    required this.axis,
    required this.itemCount,
    required this.trackCount,
    required this.crossExtent,
    required this.cellMainExtent,
    required this.cellCrossExtent,
    required this.mainGap,
    required this.crossGap,
  });

  /// 布局轴。
  final Axis axis;

  /// 业务条目数。
  final int itemCount;

  /// 交叉轴轨道数。
  final int trackCount;

  /// 完整交叉轴尺寸。
  final double crossExtent;

  /// 单格主轴尺寸。
  final double cellMainExtent;

  /// 单格交叉轴尺寸。
  final double cellCrossExtent;

  /// 相邻带主轴间距。
  final double mainGap;

  /// 相邻轨道交叉轴间距。
  final double crossGap;

  /// 带数，最后不足一带的条目计入一带。
  int get bandCount => (itemCount + trackCount - 1) ~/ trackCount;

  /// 完整主轴尺寸，末尾不额外添加 gap。
  double get mainExtent => bandCount == 0 ? 0 : bandCount * cellMainExtent + (bandCount - 1) * mainGap;

  /// 单格的物理宽高。
  Size get cellSize => AxisGeometry(axis).size(cellMainExtent, cellCrossExtent);

  /// 整段的物理宽高。
  Size get size => AxisGeometry(axis).size(mainExtent, crossExtent);

  /// 条目的正向主轴起点。
  double mainStart(int index) => (index ~/ trackCount) * (cellMainExtent + mainGap);

  /// 条目的正向交叉轴起点。
  double crossStart(int index) => (index % trackCount) * (cellCrossExtent + crossGap);

  /// 主轴坐标所在带，间距归属于前一带。
  int bandAt(double offset) {
    final stride = cellMainExtent + mainGap;
    return bandCount == 0 || stride <= 0 ? 0 : (offset / stride).floor().clamp(0, bandCount - 1);
  }
}
