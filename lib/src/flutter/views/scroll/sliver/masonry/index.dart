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

/// 沿最短列排列自然尺寸条目的瀑布流。
///
/// 列数四选一：[crossAxisCount] 固定数量，[itemWidth]、[minCrossAxisExtent]、
/// [maxCrossAxisExtent] 按可用宽度自适应。
abstract class ElSliverMasonry extends Widget {
  /// 全量挂载并测量，仅绘制可见条目。
  const factory ElSliverMasonry({
    Key? key,
    required List<Widget> children,
    int? crossAxisCount,
    double? itemWidth,
    double? minCrossAxisExtent,
    double? maxCrossAxisExtent,
    double? gap,
    double? mainAxisSpacing,
    double? crossAxisSpacing,
    bool addRepaintBoundaries,
    bool addSemanticIndexes,
  }) = _EagerMasonry;

  /// 按缓存窗口构建和销毁子项，保留实测尺寸索引。
  factory ElSliverMasonry.builder({
    Key? key,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    int? crossAxisCount,
    double? itemWidth,
    double? minCrossAxisExtent,
    double? maxCrossAxisExtent,
    double? gap,
    double? mainAxisSpacing,
    double? crossAxisSpacing,
    ChildIndexGetter? findChildIndexCallback,
    bool addAutomaticKeepAlives,
    bool addRepaintBoundaries,
    bool addSemanticIndexes,
  }) = _BuilderMasonry;

  /// 按类型复用子树，使用活索引更新内容。
  const factory ElSliverMasonry.recycler({
    Key? key,
    required int itemCount,
    required Widget Function(BuildContext, ValueListenable<int>) itemBuilder,
    int? crossAxisCount,
    double? itemWidth,
    double? minCrossAxisExtent,
    double? maxCrossAxisExtent,
    double? gap,
    double? mainAxisSpacing,
    double? crossAxisSpacing,
    Object? Function(int)? itemType,
    int maxRecycledItems,
    bool addRepaintBoundaries,
    bool addSemanticIndexes,
  }) = _RecyclerMasonry;

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
  /// 横向滚动时作为预估格高按可用高度取行数。
  double? get itemWidth;

  /// 自适应列数时单格交叉轴尺寸的下限：在不小于它的前提下排尽量多的列。
  double? get minCrossAxisExtent;

  /// 自适应列数时单格交叉轴尺寸的上限：在不超过它的前提下排尽量少的列。
  double? get maxCrossAxisExtent;

  /// 主轴上相邻条目的间距，未指定时取构造参数 gap，再缺省为零。
  double get mainAxisSpacing;

  /// 相邻列的间距，未指定时取构造参数 gap，再缺省为零。
  double get crossAxisSpacing;
}

// 三种生命周期共用的参数到规格的转换；参数校验集中在规格的构造断言里。
mixin _MasonryConfig {
  int? get crossAxisCount;
  double? get itemWidth;
  double? get minCrossAxisExtent;
  double? get maxCrossAxisExtent;
  double get mainAxisSpacing;
  double get crossAxisSpacing;

  SliverLayoutSpec get spec => _MasonrySpec(
    SliverTracks(
      count: crossAxisCount,
      itemExtent: itemWidth,
      minExtent: minCrossAxisExtent,
      maxExtent: maxCrossAxisExtent,
      spacing: crossAxisSpacing,
    ),
    mainAxisSpacing,
  );
}

class _EagerMasonry extends EagerSliver with _MasonryConfig implements ElSliverMasonry {
  const _EagerMasonry({
    super.key,
    required super.children,
    this.crossAxisCount,
    this.itemWidth,
    this.minCrossAxisExtent,
    this.maxCrossAxisExtent,
    double? gap,
    double? mainAxisSpacing,
    double? crossAxisSpacing,
    super.addRepaintBoundaries,
    super.addSemanticIndexes,
  }) : mainAxisSpacing = mainAxisSpacing ?? gap ?? 0,
       crossAxisSpacing = crossAxisSpacing ?? gap ?? 0;

  @override
  final int? crossAxisCount;
  @override
  final double? itemWidth;
  @override
  final double? minCrossAxisExtent;
  @override
  final double? maxCrossAxisExtent;
  @override
  final double mainAxisSpacing;
  @override
  final double crossAxisSpacing;
}

class _BuilderMasonry extends BuilderSliver with _MasonryConfig implements ElSliverMasonry {
  _BuilderMasonry({
    super.key,
    required this.itemCount,
    required IndexedWidgetBuilder itemBuilder,
    this.crossAxisCount,
    this.itemWidth,
    this.minCrossAxisExtent,
    this.maxCrossAxisExtent,
    double? gap,
    double? mainAxisSpacing,
    double? crossAxisSpacing,
    ChildIndexGetter? findChildIndexCallback,
    bool addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
  }) : assert(itemCount >= 0),
       mainAxisSpacing = mainAxisSpacing ?? gap ?? 0,
       crossAxisSpacing = crossAxisSpacing ?? gap ?? 0,
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
  final double mainAxisSpacing;
  @override
  final double crossAxisSpacing;
}

class _RecyclerMasonry extends RecyclerSliver with _MasonryConfig implements ElSliverMasonry {
  const _RecyclerMasonry({
    super.key,
    required super.itemCount,
    required super.itemBuilder,
    this.crossAxisCount,
    this.itemWidth,
    this.minCrossAxisExtent,
    this.maxCrossAxisExtent,
    double? gap,
    double? mainAxisSpacing,
    double? crossAxisSpacing,
    super.itemType,
    super.maxRecycledItems,
    super.addRepaintBoundaries,
    super.addSemanticIndexes,
  }) : mainAxisSpacing = mainAxisSpacing ?? gap ?? 0,
       crossAxisSpacing = crossAxisSpacing ?? gap ?? 0;

  @override
  final int? crossAxisCount;
  @override
  final double? itemWidth;
  @override
  final double? minCrossAxisExtent;
  @override
  final double? maxCrossAxisExtent;
  @override
  final double mainAxisSpacing;
  @override
  final double crossAxisSpacing;
}
