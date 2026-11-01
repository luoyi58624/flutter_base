import 'package:flutter/widgets.dart';

import '../geometry/grid_geometry.dart';
import '../layout_view.dart';

/// Grid 排列布局；普通构造全量挂载，builder 仅能直接接入 ElScrollView。
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
    List<Widget> this.children = const <Widget>[],
  }) : itemCount = null,
       keepAlive = false,
       itemBuilder = null,
       findChildIndexCallback = null,
       assert(gap == null || rowGap == null && columnGap == null, 'gap 与 rowGap/columnGap 不能同时设置。'),
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

  /// 创建虚拟布局，上级必须为 ElScrollView 的直接内容槽。
  const ElGridView.builder({
    super.key,
    required int this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    this.keepAlive = false,
    this.findChildIndexCallback,
    this.crossAxisCount,
    this.itemWidth,
    this.minCrossAxisExtent,
    this.maxCrossAxisExtent,
    this.mainAxisExtent,
    this.aspectRatio = 1,
    double? gap,
    double? rowGap,
    double? columnGap,
  }) : children = null,
       assert(itemCount >= 0),

       assert(gap == null || rowGap == null && columnGap == null, 'gap 与 rowGap/columnGap 不能同时设置。'),
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

  /// 普通构造的全部条目，builder 模式为 null。
  final List<Widget>? children;

  /// builder 的业务条目数量，不包含分隔项。
  final int? itemCount;

  /// 按业务索引构建条目。
  final IndexedWidgetBuilder? itemBuilder;

  /// 根据业务 key 返回重排后的业务索引。
  final ChildIndexGetter? findChildIndexCallback;

  /// 保留已构建条目的状态，默认关闭；不会提前构建未访问条目。
  final bool keepAlive;
  @override
  bool get layoutKeepAlive => keepAlive;
  @override
  List<Widget>? get layoutChildren => children;
  @override
  int get layoutItemCount => children?.length ?? itemCount!;
  @override
  IndexedWidgetBuilder? get layoutItemBuilder => itemBuilder;
  @override
  ChildIndexGetter? get layoutFindChildIndex => findChildIndexCallback;
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
