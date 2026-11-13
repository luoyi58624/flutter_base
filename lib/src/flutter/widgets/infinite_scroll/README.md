# ElInfiniteScroll

在 `Expanded`、`SizedBox` 等提供有限高度的布局中放入 `ElInfiniteScroll`。组件管理分页数据，`sliverBuilder` 决定内容布局。

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

Widget buildProductGrid(
  Future<ElInfiniteScrollPage<Map<String, String>, int>> Function(int) loadProducts,
) {
  return ElInfiniteScroll<Map<String, String>, int>(
    firstPageKey: 1,
    onLoadPage: loadProducts,
    loadDistance: 160,
    sliverBuilder: (context, items) => SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
      itemCount: items.length,
      itemBuilder: (context, index) => Center(child: Text(items[index]['name'] ?? '')),
    ),
    emptyBuilder: (context) => const Text('暂无商品'),
    loadingBuilder: (context) => const Padding(
      padding: EdgeInsets.all(12),
      child: Center(child: Text('正在加载商品…')),
    ),
  );
}
```

- 第一个泛型参数是条目类型，例如 `Map<String, String>` 或 `Product`。第二个是请求键类型，例如页码 `int` 或游标 `String`。
- `onLoadPage` 返回 `ElInfiniteScrollPage(items: records, nextPageKey: key)`。省略 `nextPageKey` 结束分页。下一页键须在本轮分页中唯一。
- 首次进入与下拉刷新都从 `firstPageKey` 请求，成功后替换数据。后续页按键追加，距离底部进入 `loadDistance` 后自动补页，默认 200 逻辑像素。
- `sliverBuilder` 接收只读条目快照，可以返回 `SliverList.builder`、`ElSliverList.builder`、网格或由多个 Sliver 组成的 `SliverMainAxisGroup`。
- `refresher` 自定义下拉刷新器。省略时沿用 `ElSliverRefresh` 的平台默认实现。`emptyBuilder`、`loadingBuilder` 和 `errorBuilder` 都返回普通 Widget。默认提供空态文案、对应平台的刷新指示器和重试按钮。
- 请求失败时保留已加载条目，并暂停自动请求。`errorBuilder` 收到异常和重试回调。刷新优先于正在进行的追加请求。
- 改变 `firstPageKey` 会重新分页。筛选条件变化且第一页键相同时，可以用 `ValueKey` 为新的数据源重建组件。
