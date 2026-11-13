import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../../layout/example_page.dart';

/// 展示无限滚动的刷新、分页和自定义状态。
class InfiniteScrollPage extends HookWidget {
  /// 创建无限滚动演示页。
  // ignore: prefer_const_constructors_in_immutables
  InfiniteScrollPage({super.key});

  @override
  Widget build(BuildContext context) {
    final grid = useState(false);
    final source = useState(_Source.normal);
    final products = useMemoized(() => _Products(source.value), [source.value]);
    final scrollBehavior = ScrollConfiguration.of(context);

    return ExamplePage(
      title: 'InfiniteScroll 无限滚动',
      child: Padding(
        padding: .fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: .stretch,
          spacing: 12,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ElButtonGroup<bool>.single(
                  modelValue: grid,
                  mandatory: true,
                  semanticLabel: '内容布局',
                  children: [
                    ElButtonGroupItem(value: false, child: Text('列表')),
                    ElButtonGroupItem(value: true, child: Text('网格')),
                  ],
                ),
                ElButtonGroup<_Source>.single(
                  modelValue: source,
                  mandatory: true,
                  semanticLabel: '数据源',
                  children: [
                    for (final value in _Source.values) ElButtonGroupItem(value: value, child: Text(value.label)),
                  ],
                ),
              ],
            ),
            Text(
              '在顶部下拉刷新，距底部 ${_loadDistance.toInt()} 逻辑像素时自动加载下一页。',
              style: TextStyle(color: context.elTheme.textSecondary),
            ),
            Expanded(
              child: ElCard(
                style: ElStyle(
                  padding: .zero,
                  backgroundColor: context.elTheme.cardColor,
                  border: .all(borderColor: context.elTheme.borderColor),
                  borderRadius: .circular(12),
                  clipBehavior: .antiAlias,
                ),
                child: ScrollConfiguration(
                  behavior: scrollBehavior.copyWith(
                    dragDevices: {...scrollBehavior.dragDevices, PointerDeviceKind.mouse},
                  ),
                  child: ElInfiniteScroll<_Product, int>(
                    key: ValueKey(source.value),
                    firstPageKey: 1,
                    loadDistance: _loadDistance,
                    onLoadPage: products.load,
                    sliverBuilder: (context, items) => SliverPadding(
                      padding: .all(12),
                      sliver: grid.value
                          ? SliverGrid.builder(
                              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 240,
                                mainAxisExtent: 96,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                              ),
                              itemCount: items.length,
                              itemBuilder: (_, index) => _ProductCard(product: items[index]),
                            )
                          : ElSliverList.builder(
                              spacing: 8,
                              itemCount: items.length,
                              itemBuilder: (_, index) =>
                                  SizedBox(height: 80, child: _ProductCard(product: items[index])),
                            ),
                    ),
                    emptyBuilder: (context) => Text('暂无商品，可以下拉刷新。'),
                    loadingBuilder: (context) => Center(
                      child: Padding(
                        padding: .all(16),
                        child: Text('正在加载商品…', style: TextStyle(color: context.elTheme.textSecondary)),
                      ),
                    ),
                    errorBuilder: (context, _, retry) => Padding(
                      padding: .all(12),
                      child: Center(
                        child: ElButton(variant: .outline, onPressed: retry, child: Text('加载失败，点击重试')),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _loadDistance = 160.0;

enum _Source {
  normal('正常'),
  empty('空数据'),
  failOnce('模拟失败');

  const _Source(this.label);

  final String label;
}

class _Product {
  _Product({required this.id, required this.title, required this.price});

  final int id;
  final String title;
  final int price;
}

class _Products {
  _Products(this.source);

  static const _pageSize = 12;
  static const _lastPage = 3;
  static const _titles = ['陶瓷马克杯', '亚麻收纳袋', '实木托盘', '玻璃花瓶', '棉麻靠垫', '黄铜书签'];

  final _Source source;
  var _failed = false;
  var _refreshCount = 0;

  Future<ElInfiniteScrollPage<_Product, int>> load(int page) async {
    await Future<void>.delayed(Duration(milliseconds: 420));
    if (source == .empty) return ElInfiniteScrollPage(items: []);
    if (source == .failOnce && page == 2 && !_failed) {
      _failed = true;
      throw StateError('模拟分页请求失败');
    }
    if (page == 1) _refreshCount++;
    return ElInfiniteScrollPage(
      items: List.generate(_pageSize, (index) {
        final id = (page - 1) * _pageSize + index + 1;
        return _Product(id: id, title: _titles[(id + _refreshCount - 2) % _titles.length], price: 18 + id * 3);
      }),
      nextPageKey: page < _lastPage ? page + 1 : null,
    );
  }
}

class _ProductCard extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _ProductCard({required this.product});

  final _Product product;

  @override
  Widget build(BuildContext context) => ElCard(
    style: ElStyle(padding: .all(12), backgroundColor: context.elTheme.fill, borderRadius: .circular(8)),
    child: Column(
      crossAxisAlignment: .stretch,
      mainAxisAlignment: .center,
      mainAxisSize: .min,
      spacing: 4,
      children: [
        Text('商品 ${product.id} · ${product.title}', maxLines: 2, overflow: .ellipsis),
        Text('¥${product.price}', style: TextStyle(color: context.elTheme.textSecondary)),
      ],
    ),
  );
}
