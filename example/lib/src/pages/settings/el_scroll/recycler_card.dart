part of 'index.dart';

class _RecyclerShopCard extends HookWidget {
  const _RecyclerShopCard(this.index);

  final ValueListenable<int> index;

  static String _shopTitle(int index) => 'Title - ${index + 1}';

  Widget _text(String Function(int) label, TextStyle style) => ValueListenableBuilder<int>(
    valueListenable: index,
    builder: (context, index, _) => ElText(label(index), style: style, maxLines: 1, overflow: .ellipsis),
  );

  Widget _photo({int? productIndex}) => ValueListenableBuilder<int>(
    valueListenable: index,
    builder: (context, index, _) {
      final seed = productIndex == null ? 'shop-$index' : 'shop-$index-product-$productIndex';
      return ElImageView('https://picsum.photos/seed/el-scroll-$seed/160/160', fit: .cover);
    },
  );

  @override
  Widget build(BuildContext context) {
    final controller = useScrollController(keepScrollOffset: false);
    useEffect(() {
      var boundIndex = index.value;
      void resetOffset() {
        if (boundIndex == index.value) return;
        boundIndex = index.value;
        // 保留横向滚动容器，换绑时结束上一条目的滚动并从起点展示。
        if (!controller.hasClients) return;
        final position = controller.position;
        if (position.pixels != 0 || position.isScrollingNotifier.value) position.jumpTo(0);
      }

      index.addListener(resetOffset);
      return () => index.removeListener(resetOffset);
    }, [index, controller]);

    return ElView(
      style: ElStyle(
        backgroundColor: Colors.white,
        margin: .only(bottom: 8),
        padding: .only(top: 8, left: 8, bottom: 8),
      ).withShadow(),
      child: Column(
        spacing: 10,
        children: [
          Row(
            crossAxisAlignment: .start,
            spacing: 8,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: ClipRRect(borderRadius: .circular(6), child: _photo()),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    _text(_shopTitle, TextStyle(fontWeight: .w500, fontSize: 13)),
                    Row(
                      children: [
                        Flexible(child: _text((index) => '${_shopTitle(index)} ' * 3, TextStyle(fontSize: 12))),
                        ElText('最快30分钟送达', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    _text(_shopTitle, TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(
            height: 100,
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 100,
                  child: ClipRRect(borderRadius: .circular(6), child: _photo()),
                ),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                    child: ElScrollView.sliver(
                      axis: .horizontal,
                      controller: controller,
                      slivers: [
                        SliverList.builder(
                          itemCount: 10,
                          itemBuilder: (context, productIndex) => Padding(
                            padding: .only(left: 8),
                            child: SizedBox(
                              width: 80,
                              child: Column(
                                crossAxisAlignment: .stretch,
                                children: [
                                  Expanded(child: _photo(productIndex: productIndex)),
                                  _text(
                                    (index) => '${_shopTitle(index)} · ${productIndex + 1}',
                                    TextStyle(fontSize: 12),
                                  ),
                                  ElText('¥${productIndex + 1}', style: TextStyle(fontSize: 12, color: Colors.red)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
