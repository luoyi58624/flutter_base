import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 在同一个 CustomScrollView 中对照官方与 ElSliver 三种子项生命周期。
enum SliverExampleMode {
  /// 按类型复用子树，示例默认优先展示。
  recycler('ElSliverList.recycler'),

  /// 按缓存窗口构建与销毁子项。
  builder('ElSliverList.builder'),

  /// 全量挂载子项，仅绘制可见部分。
  children('ElSliverList'),

  /// 使用官方按需挂载的列表。
  official('SliverList');

  const SliverExampleMode(this.label);

  /// 所有滚动对照示例共用的初始模式。
  static const initial = recycler;

  /// 下拉菜单中显示的容器名称。
  final String label;

  /// 统一生成四种滚动模式，业务操作可追加到这组菜单项之后。
  List<CheckedPopupMenuItem<SliverExampleMode>> menuItems({
    String? keyPrefix,
    bool grid = false,
    bool masonry = false,
  }) => [
    for (final mode in values)
      CheckedPopupMenuItem<SliverExampleMode>(
        key: keyPrefix == null ? null : ValueKey('$keyPrefix-${mode.name}'),
        value: mode,
        checked: this == mode,
        child: Text(grid || masonry ? mode.gridLabel(masonry: masonry) : mode.label),
      ),
  ];

  /// 网格或瀑布流下拉显示实际使用的 Sliver 名称。
  String gridLabel({bool masonry = false}) => this == official
      ? 'SliverGrid'
      : label.replaceFirst('ElSliverList', masonry ? 'ElSliverMasonry' : 'ElSliverGrid');

  /// 各模式共用官方宿主与完全相同的滚动配置。
  CustomScrollView scrollView({
    Key? key,
    required ScrollController controller,
    required List<Widget> slivers,
    bool reverse = false,
    int? semanticChildCount,
    ScrollPhysics? physics,
    ScrollCacheExtent scrollCacheExtent = const ScrollCacheExtent.pixels(250),
  }) => CustomScrollView(
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
