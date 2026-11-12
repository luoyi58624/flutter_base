import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

/// 示例同时对照官方宿主与 ElScrollView 的三种子项生命周期。
enum SliverExampleMode {
  /// 使用官方按需挂载的列表。
  official('SliverList'),

  /// 使用按类型复用结构的回收列表。
  recycler('ElSliverList.recycler'),

  /// ElScrollView 全量挂载子项，仅绘制可见部分。
  children('ElScrollView · children'),

  /// ElScrollView 按缓存窗口构建与销毁子项。
  builder('ElScrollView · builder'),

  /// ElScrollView 按类型复用子树。
  elRecycler('ElScrollView · recycler');

  const SliverExampleMode(this.label);

  /// 下拉菜单中显示的容器名称。
  final String label;

  /// 是否使用 ElScrollView 宿主。
  bool get usesElScrollView => this == children || this == builder || this == elRecycler;

  /// 在完全相同的滚动配置下切换宿主。
  Widget scrollView({
    Key? key,
    required ScrollController controller,
    required List<Widget> slivers,
    bool reverse = false,
    int? semanticChildCount,
    ScrollPhysics? physics,
    ScrollCacheExtent scrollCacheExtent = const ScrollCacheExtent.pixels(250),
  }) => usesElScrollView
      ? ElScrollView.sliver(
          key: key,
          controller: controller,
          reverse: reverse,
          physics: physics,
          semanticChildCount: semanticChildCount,
          scrollCacheExtent: scrollCacheExtent,
          slivers: slivers,
        )
      : CustomScrollView(
          key: key,
          controller: controller,
          reverse: reverse,
          physics: physics,
          semanticChildCount: semanticChildCount,
          scrollCacheExtent: scrollCacheExtent,
          slivers: slivers,
        );

  /// 使用同一业务工厂切换列表生命周期。
  Widget list(
    BuildContext context, {
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    Widget Function(BuildContext, ValueListenable<int>)? recycledItemBuilder,
    Object? Function(int)? itemType,
    ChildIndexGetter? findChildIndexCallback,
    ElSliverRecyclerController? controller,
  }) => switch (this) {
    children => ElSliverList(stretch: true, children: List.generate(itemCount, (i) => itemBuilder(context, i))),
    builder => ElSliverList.builder(
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      findChildIndexCallback: findChildIndexCallback,
      addAutomaticKeepAlives: false,
    ),
    official => SliverList(
      delegate: SliverChildBuilderDelegate(
        itemBuilder,
        childCount: itemCount,
        findChildIndexCallback: findChildIndexCallback,
        addAutomaticKeepAlives: false,
      ),
    ),
    _ => ElSliverList.recycler(
      itemCount: itemCount,
      itemType: itemType,
      controller: controller,
      itemBuilder:
          recycledItemBuilder ??
          (context, index) => ValueListenableBuilder<int>(
            valueListenable: index,
            builder: (context, value, _) => itemBuilder(context, value),
          ),
    ),
  };

  /// 使用同一业务工厂切换网格或瀑布流生命周期。
  Widget grid(
    BuildContext context, {
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    required Widget Function(BuildContext, ValueListenable<int>) recycledItemBuilder,
    required int crossAxisCount,
    required Widget officialSliver,
    bool masonry = false,
    double mainAxisSpacing = 0,
    double crossAxisSpacing = 0,
  }) {
    if (this == official) return officialSliver;
    if (this == children) {
      final items = List.generate(itemCount, (i) => itemBuilder(context, i));
      return masonry
          ? ElSliverMasonry(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: mainAxisSpacing,
              crossAxisSpacing: crossAxisSpacing,
              children: items,
            )
          : ElSliverGrid(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: mainAxisSpacing,
              crossAxisSpacing: crossAxisSpacing,
              children: items,
            );
    }
    if (this == builder) {
      return masonry
          ? ElSliverMasonry.builder(
              itemCount: itemCount,
              itemBuilder: itemBuilder,
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: mainAxisSpacing,
              crossAxisSpacing: crossAxisSpacing,
              addAutomaticKeepAlives: false,
            )
          : ElSliverGrid.builder(
              itemCount: itemCount,
              itemBuilder: itemBuilder,
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: mainAxisSpacing,
              crossAxisSpacing: crossAxisSpacing,
              addAutomaticKeepAlives: false,
            );
    }
    return masonry
        ? ElSliverMasonry.recycler(
            itemCount: itemCount,
            itemBuilder: recycledItemBuilder,
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: mainAxisSpacing,
            crossAxisSpacing: crossAxisSpacing,
          )
        : ElSliverGrid.recycler(
            itemCount: itemCount,
            itemBuilder: recycledItemBuilder,
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: mainAxisSpacing,
            crossAxisSpacing: crossAxisSpacing,
          );
  }
}
