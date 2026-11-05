import 'package:flutter_base/dart.dart' show $absent;
import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';

/// 使用列表配置 声明构建虚拟滚动测试宿主。
Widget buildVirtualTestView({
  Key? key,
  required List<Widget> children,
  ScrollController? controller,
  ScrollController? horizontalController,
  ScrollPhysics? physics,
  Object? smoothScroll = $absent,
  ElScrollbar? scrollbar,
  Axis? axis = Axis.vertical,
  bool reverse = false,
  Clip clipBehavior = Clip.hardEdge,
  ScrollViewKeyboardDismissBehavior keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
  double? dragStartDistance,
  double cacheExtent = 250.0,
  EdgeInsets padding = EdgeInsets.zero,
  double gap = 0.0,
  ValueChanged<ElVisibleRange>? onVisibleRangeChanged,
  bool? dragOptimize,
  ElEvent? event,
  ElScrollDeltaInterceptor? deltaInterceptor,
  ElRefresher? refresher,
  Future<void> Function()? onRefresh,
  ElRefreshEdge refreshEdge = ElRefreshEdge.leading,
}) {
  final gapPadding = axis == Axis.horizontal ? EdgeInsets.only(right: gap) : EdgeInsets.only(bottom: gap);
  final items = <Widget>[
    for (var index = 0; index < children.length; index++)
      Padding(
        key: ValueKey<Object>(children[index].key ?? index),
        padding: index + 1 < children.length ? gapPadding : EdgeInsets.zero,
        child: children[index],
      ),
  ];
  return ElScrollView(
    key: key,
    controller: controller,
    horizontalController: horizontalController,
    physics: physics,
    smoothScroll: smoothScroll,
    scrollbar: scrollbar,
    axis: axis,
    reverse: reverse,
    clipBehavior: clipBehavior,
    keyboardDismissBehavior: keyboardDismissBehavior,
    dragStartDistance: dragStartDistance,
    cacheExtent: cacheExtent,
    padding: padding,
    onVisibleRangeChanged: onVisibleRangeChanged,
    dragOptimize: dragOptimize,
    event: event,
    deltaInterceptor: deltaInterceptor,
    refresher: refresher,
    onRefresh: onRefresh,
    refreshEdge: refreshEdge,
    children: [_listItems(items, crossAxisAlignment: axis == Axis.horizontal ? .start : .stretch)],
  );
}

/// 使用 `ElListView` 构建惰性虚拟滚动测试宿主。
Widget buildVirtualTestViewBuilder({
  Key? key,
  required int itemCount,
  required IndexedWidgetBuilder itemBuilder,
  ScrollController? controller,
  ScrollController? horizontalController,
  ScrollPhysics? physics,
  Object? smoothScroll = $absent,
  ElScrollbar? scrollbar,
  Axis? axis = Axis.vertical,
  bool reverse = false,
  Clip clipBehavior = Clip.hardEdge,
  ScrollViewKeyboardDismissBehavior keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
  double? dragStartDistance,
  double cacheExtent = 250.0,
  EdgeInsets padding = EdgeInsets.zero,
  double gap = 0.0,
  ValueChanged<ElVisibleRange>? onVisibleRangeChanged,
  bool? dragOptimize,
  ElEvent? event,
  ElScrollDeltaInterceptor? deltaInterceptor,
  ElRefresher? refresher,
  Future<void> Function()? onRefresh,
  ElRefreshEdge refreshEdge = ElRefreshEdge.leading,
}) {
  assert(gap == 0.0, 'ElListView 不接受隐式 gap；请在 itemBuilder 返回值中声明间距。');
  return ElScrollView(
    key: key,
    controller: controller,
    horizontalController: horizontalController,
    physics: physics,
    smoothScroll: smoothScroll,
    scrollbar: scrollbar,
    axis: axis,
    reverse: reverse,
    clipBehavior: clipBehavior,
    keyboardDismissBehavior: keyboardDismissBehavior,
    dragStartDistance: dragStartDistance,
    cacheExtent: cacheExtent,
    padding: padding,
    onVisibleRangeChanged: onVisibleRangeChanged,
    dragOptimize: dragOptimize,
    event: event,
    deltaInterceptor: deltaInterceptor,
    refresher: refresher,
    onRefresh: onRefresh,
    refreshEdge: refreshEdge,
    children: [
      ElListView.builder(
        itemCount: itemCount,
        itemBuilder: itemBuilder,
        crossAxisAlignment: axis == Axis.horizontal ? .start : .stretch,
      ),
    ],
  );
}

/// 构建可直接放入 `ElScrollView.children` 的虚拟网格 Sliver。
Widget buildVirtualGrid({
  int? crossAxisCount,
  double? itemWidth,
  double? itemHeight,
  double aspectRatio = 1.0,
  double? gap,
  double? rowGap,
  double? columnGap,
  required int itemCount,
  required IndexedWidgetBuilder itemBuilder,
}) {
  assert(gap == null || (rowGap == null && columnGap == null));
  return ElGridView.builder(
    crossAxisCount: crossAxisCount,
    maxCrossAxisExtent: crossAxisCount == null ? itemWidth : null,
    mainAxisExtent: itemHeight,
    aspectRatio: aspectRatio,
    rowGap: rowGap,
    columnGap: columnGap,
    gap: gap,
    itemCount: itemCount,
    itemBuilder: itemBuilder,
  );
}

// 将已构造的测试条目接入列表配置，并保留按 key 重排的索引回查。
ElListView _listItems(
  List<Widget> children, {
  bool fixedSize = false,
  CrossAxisAlignment crossAxisAlignment = .stretch,
}) {
  final indices = <Key, int>{for (var index = 0; index < children.length; index++) ?children[index].key: index};
  return ElListView.builder(
    itemCount: children.length,
    itemBuilder: (context, index) => children[index],
    fixedSize: fixedSize,
    crossAxisAlignment: crossAxisAlignment,
    findChildIndexCallback: (key) => indices[key],
  );
}
