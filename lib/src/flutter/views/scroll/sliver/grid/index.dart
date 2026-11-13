import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../internal/builder.dart';
import '../internal/eager.dart';
import '../internal/extent_index.dart';
import '../internal/layout.dart';
import '../internal/recycler.dart';

part 'layout.dart';

/// 自然尺寸网格：默认每行以最高条目确定行高，指定 [mainAxisExtent] 或 [aspectRatio] 后改为固定格尺寸。
///
/// 列数四选一：[crossAxisCount] 固定数量，[itemWidth]、[minCrossAxisExtent]、
/// [maxCrossAxisExtent] 按可用宽度自适应。
abstract class ElSliverGrid extends Widget {
  /// 全量挂载并测量，仅绘制可见条目。
  const factory ElSliverGrid({
    Key? key,
    required List<Widget> children,
    int? crossAxisCount,
    double? itemWidth,
    double? minCrossAxisExtent,
    double? maxCrossAxisExtent,
    double? mainAxisExtent,
    double? aspectRatio,
    double? spacing,
    double? mainAxisSpacing,
    double? crossAxisSpacing,
    bool addRepaintBoundaries,
    bool addSemanticIndexes,
  }) = _EagerGrid;

  /// 按缓存窗口构建和销毁子项，保留实测尺寸索引。
  factory ElSliverGrid.builder({
    Key? key,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    int? crossAxisCount,
    double? itemWidth,
    double? minCrossAxisExtent,
    double? maxCrossAxisExtent,
    double? mainAxisExtent,
    double? aspectRatio,
    double? spacing,
    double? mainAxisSpacing,
    double? crossAxisSpacing,
    ChildIndexGetter? findChildIndexCallback,
    bool addAutomaticKeepAlives,
    bool addRepaintBoundaries,
    bool addSemanticIndexes,
  }) = _BuilderGrid;

  /// 按类型复用子树，使用活索引更新内容。
  const factory ElSliverGrid.recycler({
    Key? key,
    required int itemCount,
    required Widget Function(BuildContext, ValueListenable<int>) itemBuilder,
    int? crossAxisCount,
    double? itemWidth,
    double? minCrossAxisExtent,
    double? maxCrossAxisExtent,
    double? mainAxisExtent,
    double? aspectRatio,
    double? spacing,
    double? mainAxisSpacing,
    double? crossAxisSpacing,
    Object? Function(int)? itemType,
    int maxRecycledItems,
    bool addRepaintBoundaries,
    bool addSemanticIndexes,
  }) = _RecyclerGrid;

  /// 是否为每个条目隔离重绘，默认 true。
  bool get addRepaintBoundaries;

  /// 是否为条目提供业务语义索引，默认 true。
  bool get addSemanticIndexes;

  /// 当前条目数量。
  int get itemCount;

  /// 固定的交叉轴格数：纵向为列数，横向为行数。
  int? get crossAxisCount;

  /// 预估格宽：按可用宽度向下取列数，再扣除间距均分剩余空间，容器变窄时至少保留一列。
  ///
  /// 例如可用宽度 400、itemWidth 为 150 时排 2 列，无间距时每格宽 200。
  /// 横向滚动时先按 [aspectRatio] 换算成格高，再按可用高度取行数。
  double? get itemWidth;

  /// 自适应列数时单格交叉轴尺寸的下限：在不小于它的前提下排尽量多的列。
  double? get minCrossAxisExtent;

  /// 自适应列数时单格交叉轴尺寸的上限：在不超过它的前提下排尽量少的列。
  double? get maxCrossAxisExtent;

  /// 固定主轴格尺寸：纵向为格高，横向为格宽；指定后条目不再按内容测量。
  double? get mainAxisExtent;

  /// 格子的物理宽高比，仅未指定 [mainAxisExtent] 时用于推导主轴尺寸；两者都省略时按内容自然测量。
  double? get aspectRatio;

  /// 主轴上相邻行的间距，未指定时取构造参数 spacing，再缺省为零。
  double get mainAxisSpacing;

  /// 相邻列的间距，未指定时取构造参数 spacing，再缺省为零。
  double get crossAxisSpacing;
}

// 三种生命周期共用的参数到规格的转换；参数校验集中在规格的构造断言里。
mixin _GridConfig {
  int? get crossAxisCount;
  double? get itemWidth;
  double? get minCrossAxisExtent;
  double? get maxCrossAxisExtent;
  double? get mainAxisExtent;
  double? get aspectRatio;
  double get mainAxisSpacing;
  double get crossAxisSpacing;

  SliverLayoutSpec get spec => _GridSpec(
    SliverTracks(
      count: crossAxisCount,
      itemExtent: itemWidth,
      minExtent: minCrossAxisExtent,
      maxExtent: maxCrossAxisExtent,
      spacing: crossAxisSpacing,
    ),
    mainAxisSpacing,
    mainAxisExtent,
    aspectRatio,
  );
}

class _EagerGrid extends EagerSliver with _GridConfig implements ElSliverGrid {
  const _EagerGrid({
    super.key,
    required super.children,
    this.crossAxisCount,
    this.itemWidth,
    this.minCrossAxisExtent,
    this.maxCrossAxisExtent,
    this.mainAxisExtent,
    this.aspectRatio,
    double? spacing,
    double? mainAxisSpacing,
    double? crossAxisSpacing,
    super.addRepaintBoundaries,
    super.addSemanticIndexes,
  }) : mainAxisSpacing = mainAxisSpacing ?? spacing ?? 0,
       crossAxisSpacing = crossAxisSpacing ?? spacing ?? 0;

  @override
  final int? crossAxisCount;
  @override
  final double? itemWidth;
  @override
  final double? minCrossAxisExtent;
  @override
  final double? maxCrossAxisExtent;
  @override
  final double? mainAxisExtent;
  @override
  final double? aspectRatio;
  @override
  final double mainAxisSpacing;
  @override
  final double crossAxisSpacing;
}

class _BuilderGrid extends BuilderSliver with _GridConfig implements ElSliverGrid {
  _BuilderGrid({
    super.key,
    required this.itemCount,
    required IndexedWidgetBuilder itemBuilder,
    this.crossAxisCount,
    this.itemWidth,
    this.minCrossAxisExtent,
    this.maxCrossAxisExtent,
    this.mainAxisExtent,
    this.aspectRatio,
    double? spacing,
    double? mainAxisSpacing,
    double? crossAxisSpacing,
    ChildIndexGetter? findChildIndexCallback,
    bool addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
  }) : assert(itemCount >= 0),
       mainAxisSpacing = mainAxisSpacing ?? spacing ?? 0,
       crossAxisSpacing = crossAxisSpacing ?? spacing ?? 0,
       super(
         childCount: itemCount,
         delegate: SliverChildBuilderDelegate(
           itemBuilder,
           childCount: itemCount,
           findChildIndexCallback: findChildIndexCallback,
           addAutomaticKeepAlives: addAutomaticKeepAlives,
           addRepaintBoundaries: addRepaintBoundaries,
           addSemanticIndexes: addSemanticIndexes,
         ),
       );

  @override
  final int itemCount;
  @override
  final bool addRepaintBoundaries;
  @override
  final bool addSemanticIndexes;
  @override
  final int? crossAxisCount;
  @override
  final double? itemWidth;
  @override
  final double? minCrossAxisExtent;
  @override
  final double? maxCrossAxisExtent;
  @override
  final double? mainAxisExtent;
  @override
  final double? aspectRatio;
  @override
  final double mainAxisSpacing;
  @override
  final double crossAxisSpacing;
}

class _RecyclerGrid extends RecyclerSliver with _GridConfig implements ElSliverGrid {
  const _RecyclerGrid({
    super.key,
    required super.itemCount,
    required super.itemBuilder,
    this.crossAxisCount,
    this.itemWidth,
    this.minCrossAxisExtent,
    this.maxCrossAxisExtent,
    this.mainAxisExtent,
    this.aspectRatio,
    double? spacing,
    double? mainAxisSpacing,
    double? crossAxisSpacing,
    super.itemType,
    super.maxRecycledItems,
    super.addRepaintBoundaries,
    super.addSemanticIndexes,
  }) : mainAxisSpacing = mainAxisSpacing ?? spacing ?? 0,
       crossAxisSpacing = crossAxisSpacing ?? spacing ?? 0;

  @override
  final int? crossAxisCount;
  @override
  final double? itemWidth;
  @override
  final double? minCrossAxisExtent;
  @override
  final double? maxCrossAxisExtent;
  @override
  final double? mainAxisExtent;
  @override
  final double? aspectRatio;
  @override
  final double mainAxisSpacing;
  @override
  final double crossAxisSpacing;
}
