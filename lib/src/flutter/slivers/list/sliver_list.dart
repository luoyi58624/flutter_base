part of '../sliver.dart';

/// 自然尺寸列表，支持全量常驻、按需构建、复用以及按需分隔符。
abstract class ElSliverList extends Widget {
  /// 全量挂载和测量子项，滚动时只绘制可见内容。
  const factory ElSliverList({
    Key? key,
    required List<Widget> children,
    double spacing,
    bool center,
    bool stretch,
    bool addRepaintBoundaries,
    bool addSemanticIndexes,
  }) = _EagerList;

  /// 按缓存窗口构建，离开窗口后销毁未请求 KeepAlive 的子树。
  factory ElSliverList.builder({
    Key? key,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    double spacing,
    bool center,
    bool stretch,
    ChildIndexGetter? findChildIndexCallback,
    bool addAutomaticKeepAlives,
    bool addRepaintBoundaries,
    bool addSemanticIndexes,
  }) = _BuilderList;

  /// 按类型复用子树，构建器通过活索引监听条目换绑。
  const factory ElSliverList.recycler({
    Key? key,
    required int itemCount,
    required Widget Function(BuildContext, ValueListenable<int>) itemBuilder,
    double spacing,
    bool center,
    bool stretch,
    Object? Function(int)? itemType,
    int maxRecycledItems,
    ElSliverRecyclerController? controller,
    bool addRepaintBoundaries,
    bool addSemanticIndexes,
  }) = _RecyclerList;

  /// 按需构建条目与分隔符，间距由分隔符尺寸决定，末项后不添加分隔符。
  factory ElSliverList.separated({
    Key? key,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    required IndexedWidgetBuilder separatorBuilder,
    ChildIndexGetter? findItemIndexCallback,
    bool addAutomaticKeepAlives,
    bool addRepaintBoundaries,
    bool addSemanticIndexes,
  }) = _SeparatedList;

  /// 是否为每个条目隔离重绘，默认 true。
  bool get addRepaintBoundaries;

  /// 是否为条目提供业务语义索引，默认 true。
  bool get addSemanticIndexes;

  /// 默认构造的常驻子项，按需构造为空列表。
  List<Widget> get children;

  /// 当前条目数量，不包含 separated 的分隔符。
  int get itemCount;

  /// 复用模式的结构类型分组。
  Object? Function(int)? get itemType;

  /// 相邻条目的主轴间距，分隔符构造为零。
  double get spacing;

  /// 是否沿交叉轴居中。
  bool get center;

  /// 是否撑满交叉轴。
  bool get stretch;
}

class _RecyclerList extends _LazySliver implements ElSliverList {
  const _RecyclerList({
    super.key,
    required super.itemCount,
    required super.itemBuilder,
    double spacing = 0,
    super.center,
    super.stretch,
    super.itemType,
    super.maxRecycledItems,
    super.controller,
    super.addRepaintBoundaries,
    super.addSemanticIndexes,
  }) : assert(spacing >= 0 && spacing < double.infinity),
       super(mainAxisSpacing: spacing);
}

class _BuilderList extends _LazySliver implements ElSliverList {
  _BuilderList({
    super.key,
    required super.itemCount,
    required IndexedWidgetBuilder itemBuilder,
    double spacing = 0,
    super.center,
    super.stretch,
    ChildIndexGetter? findChildIndexCallback,
    super.addAutomaticKeepAlives,
    super.addRepaintBoundaries,
    super.addSemanticIndexes,
  }) : assert(spacing >= 0 && spacing < double.infinity),
       super(
         mainAxisSpacing: spacing,
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

class _SeparatedList extends _LazySliver implements ElSliverList {
  final int _itemCount;
  @override
  int get itemCount => _itemCount;

  _SeparatedList({
    super.key,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    required IndexedWidgetBuilder separatorBuilder,
    ChildIndexGetter? findItemIndexCallback,
    super.addAutomaticKeepAlives,
    super.addRepaintBoundaries,
    super.addSemanticIndexes,
  }) : _itemCount = itemCount,
       assert(itemCount >= 0),
       super(
         itemCount: math.max(0, itemCount * 2 - 1),
         itemType: (index) => index.isEven,
         delegate: SliverChildBuilderDelegate(
           (context, index) => index.isEven ? itemBuilder(context, index ~/ 2) : separatorBuilder(context, index ~/ 2),
           childCount: math.max(0, itemCount * 2 - 1),
           findChildIndexCallback: findItemIndexCallback == null
               ? null
               : (key) {
                   final index = findItemIndexCallback(key);
                   return index == null ? null : index * 2;
                 },
           addAutomaticKeepAlives: addAutomaticKeepAlives,
           addRepaintBoundaries: addRepaintBoundaries,
           addSemanticIndexes: addSemanticIndexes,
           semanticIndexCallback: (_, index) => index.isEven ? index ~/ 2 : null,
         ),
       );
}
