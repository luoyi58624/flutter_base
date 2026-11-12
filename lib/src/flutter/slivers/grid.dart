part of 'sliver.dart';

/// 每行以最高条目确定行高的自然尺寸网格。
abstract class ElSliverGrid extends Widget {
  /// 是否为每个条目隔离重绘，默认 true。
  bool get addRepaintBoundaries;

  /// 是否为条目提供业务语义索引，默认 true。
  bool get addSemanticIndexes;

  /// 当前条目数量。
  int get itemCount;

  /// 交叉轴上的列数，横向滚动时表示行数。
  int get crossAxisCount;

  /// 主轴条目或网格行的间距。
  double get mainAxisSpacing;

  /// 相邻列的间距。
  double get crossAxisSpacing;

  /// 全量挂载并测量，仅绘制可见条目。
  const factory ElSliverGrid({
    Key? key,
    required List<Widget> children,
    required int crossAxisCount,
    double mainAxisSpacing,
    double crossAxisSpacing,
    bool addRepaintBoundaries,
    bool addSemanticIndexes,
  }) = _EagerGrid;

  /// 按缓存窗口构建和销毁子项，保留实测尺寸索引。
  factory ElSliverGrid.builder({
    Key? key,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    required int crossAxisCount,
    double mainAxisSpacing,
    double crossAxisSpacing,
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
    required int crossAxisCount,
    double mainAxisSpacing,
    double crossAxisSpacing,
    Object? Function(int)? itemType,
    int maxRecycledItems,
    bool addRepaintBoundaries,
    bool addSemanticIndexes,
  }) = _RecyclerGrid;
}

/// 沿最短列排列自然尺寸条目的瀑布流。
abstract class ElSliverMasonry extends Widget {
  /// 是否为每个条目隔离重绘，默认 true。
  bool get addRepaintBoundaries;

  /// 是否为条目提供业务语义索引，默认 true。
  bool get addSemanticIndexes;

  /// 当前条目数量。
  int get itemCount;

  /// 交叉轴上的列数，横向滚动时表示行数。
  int get crossAxisCount;

  /// 主轴条目或网格行的间距。
  double get mainAxisSpacing;

  /// 相邻列的间距。
  double get crossAxisSpacing;

  /// 全量挂载并测量，仅绘制可见条目。
  const factory ElSliverMasonry({
    Key? key,
    required List<Widget> children,
    required int crossAxisCount,
    double mainAxisSpacing,
    double crossAxisSpacing,
    bool addRepaintBoundaries,
    bool addSemanticIndexes,
  }) = _EagerGrid.masonry;

  /// 按缓存窗口构建和销毁子项，保留实测尺寸索引。
  factory ElSliverMasonry.builder({
    Key? key,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    required int crossAxisCount,
    double mainAxisSpacing,
    double crossAxisSpacing,
    ChildIndexGetter? findChildIndexCallback,
    bool addAutomaticKeepAlives,
    bool addRepaintBoundaries,
    bool addSemanticIndexes,
  }) = _BuilderGrid.masonry;

  /// 按类型复用子树，使用活索引更新内容。
  const factory ElSliverMasonry.recycler({
    Key? key,
    required int itemCount,
    required Widget Function(BuildContext, ValueListenable<int>) itemBuilder,
    required int crossAxisCount,
    double mainAxisSpacing,
    double crossAxisSpacing,
    Object? Function(int)? itemType,
    int maxRecycledItems,
    bool addRepaintBoundaries,
    bool addSemanticIndexes,
  }) = _RecyclerGrid.masonry;
}

class _RecyclerGrid extends _LazySliver implements ElSliverGrid, ElSliverMasonry {
  const _RecyclerGrid({
    super.key,
    required super.itemCount,
    required super.itemBuilder,
    required int crossAxisCount,
    super.mainAxisSpacing,
    super.crossAxisSpacing,
    super.itemType,
    super.maxRecycledItems,
    super.addRepaintBoundaries,
    super.addSemanticIndexes,
  }) : assert(crossAxisCount > 0),
       super(columns: crossAxisCount);
  const _RecyclerGrid.masonry({
    super.key,
    required super.itemCount,
    required super.itemBuilder,
    required int crossAxisCount,
    super.mainAxisSpacing,
    super.crossAxisSpacing,
    super.itemType,
    super.maxRecycledItems,
    super.addRepaintBoundaries,
    super.addSemanticIndexes,
  }) : assert(crossAxisCount > 0),
       super(columns: crossAxisCount, masonry: true);
}

class _BuilderGrid extends _LazySliver implements ElSliverGrid, ElSliverMasonry {
  _BuilderGrid({
    super.key,
    required super.itemCount,
    required IndexedWidgetBuilder itemBuilder,
    required int crossAxisCount,
    super.mainAxisSpacing,
    super.crossAxisSpacing,
    ChildIndexGetter? findChildIndexCallback,
    super.addAutomaticKeepAlives,
    super.addRepaintBoundaries,
    super.addSemanticIndexes,
  }) : assert(crossAxisCount > 0),
       super(
         columns: crossAxisCount,
         delegate: SliverChildBuilderDelegate(
           itemBuilder,
           childCount: itemCount,
           findChildIndexCallback: findChildIndexCallback,
           addAutomaticKeepAlives: addAutomaticKeepAlives,
           addRepaintBoundaries: addRepaintBoundaries,
           addSemanticIndexes: addSemanticIndexes,
         ),
       );
  _BuilderGrid.masonry({
    super.key,
    required super.itemCount,
    required IndexedWidgetBuilder itemBuilder,
    required int crossAxisCount,
    super.mainAxisSpacing,
    super.crossAxisSpacing,
    ChildIndexGetter? findChildIndexCallback,
    super.addAutomaticKeepAlives,
    super.addRepaintBoundaries,
    super.addSemanticIndexes,
  }) : assert(crossAxisCount > 0),
       super(
         columns: crossAxisCount,
         masonry: true,
         delegate: SliverChildBuilderDelegate(
           itemBuilder,
           childCount: itemCount,
           findChildIndexCallback: findChildIndexCallback,
           addAutomaticKeepAlives: addAutomaticKeepAlives,
           addRepaintBoundaries: addRepaintBoundaries,
           addSemanticIndexes: addSemanticIndexes,
         ),
       );
}
