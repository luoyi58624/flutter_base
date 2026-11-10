import 'package:flutter/widgets.dart';

import '../geometry/grid_geometry.dart';
import '../layout_view.dart';

/// Grid 排列布局；全量挂载，虚拟网格使用 ElScroll 中的 Sliver。
class ElGridView extends LayoutView {
  /// 创建全量布局，方向跟随所属滚动容器，独立使用时默认垂直。
  const ElGridView({
    super.key,
    this.crossAxisCount,
    this.itemWidth,
    this.minCrossAxisExtent,
    this.maxCrossAxisExtent,
    this.mainAxisExtent,
    this.aspectRatio = 1,
    double? gap,
    double? rowGap,
    double? columnGap,
    super.children,
  }) : assert(gap == null || rowGap == null && columnGap == null, 'gap 与 rowGap/columnGap 不能同时设置。'),
       rowGap = rowGap ?? gap ?? 0,
       columnGap = columnGap ?? gap ?? 0,
       assert(crossAxisCount == null || crossAxisCount > 0),
       assert(itemWidth == null || itemWidth > 0 && itemWidth < double.infinity),
       assert(
         itemWidth == null || minCrossAxisExtent == null && maxCrossAxisExtent == null,
         'itemWidth 与 minCrossAxisExtent/maxCrossAxisExtent 不能同时设置。',
       ),
       assert(minCrossAxisExtent == null || minCrossAxisExtent > 0 && minCrossAxisExtent < double.infinity),
       assert(maxCrossAxisExtent == null || maxCrossAxisExtent > 0 && maxCrossAxisExtent < double.infinity),
       assert(mainAxisExtent == null || mainAxisExtent >= 0 && mainAxisExtent < double.infinity),
       assert(aspectRatio > 0 && aspectRatio < double.infinity),
       assert(gap == null || gap >= 0 && gap < double.infinity),
       assert(rowGap == null || rowGap >= 0 && rowGap < double.infinity),
       assert(columnGap == null || columnGap >= 0 && columnGap < double.infinity),
       assert(
         (crossAxisCount == null ? 0 : 1) +
                 (minCrossAxisExtent == null ? 0 : 1) +
                 (maxCrossAxisExtent == null ? 0 : 1) <=
             1,
         'crossAxisCount、minCrossAxisExtent、maxCrossAxisExtent 三选一。',
       );

  /// 固定交叉轴格数：纵向为列数，横向为行数。
  final int? crossAxisCount;

  /// 预估格宽，按可用宽度向下取列数，再扣除间距并均分剩余空间。
  ///
  /// 例如可用宽度 400、itemWidth 为 150 时排 2 列，无间距时每格宽 200。
  /// 横向布局先按 aspectRatio 换算预估格高，再按可用高度取行数。
  /// crossAxisCount 优先；与 minCrossAxisExtent/maxCrossAxisExtent 互斥。
  final double? itemWidth;

  /// 自动排布时单格交叉轴尺寸的最小目标。
  final double? minCrossAxisExtent;

  /// 自动排布时单格交叉轴尺寸的最大目标。
  final double? maxCrossAxisExtent;

  /// 固定主轴格尺寸：纵向为格高，横向为格宽。
  final double? mainAxisExtent;

  /// 物理宽/高，仅未声明 mainAxisExtent 时推导主轴尺寸。
  final double aspectRatio;

  /// 物理纵向间距。
  final double rowGap;

  /// 物理横向间距。
  final double columnGap;

  /// 行列间距相同时返回共同值。
  double? get gap => rowGap == columnGap ? rowGap : null;

  @override
  GridLayoutGeometry get gridGeometry => GridLayoutGeometry(
    crossAxisCount: crossAxisCount,
    itemWidth: itemWidth,
    minCrossAxisExtent: minCrossAxisExtent,
    maxCrossAxisExtent: maxCrossAxisExtent,
    mainAxisExtent: mainAxisExtent,
    aspectRatio: aspectRatio,
    rowGap: rowGap,
    columnGap: columnGap,
  );
  @override
  ElRenderGridView createRenderObject(BuildContext context) {
    final render = ElRenderGridView();
    configureRenderObject(context, render);
    return render;
  }
}

/// Grid 条目的布局偏移。
class ElGridParentData extends LayoutParentData {}

/// 使用共享 Grid 算法的渲染宿主。
class ElRenderGridView extends RenderLayoutView {
  @override
  LayoutParentData createParentData() => ElGridParentData();
}
