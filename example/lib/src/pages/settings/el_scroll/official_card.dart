part of 'index.dart';

class _OfficialShopCard extends StatelessWidget {
  const _OfficialShopCard(this.index);

  final int index;

  Widget _text(String label, TextStyle style) => ElText(label, style: style, maxLines: 1, overflow: .ellipsis);

  Widget _photo({int? productIndex}) {
    final seed = productIndex == null ? 'shop-$index' : 'shop-$index-product-$productIndex';
    return ElImageView('https://picsum.photos/seed/el-scroll-$seed/160/160', fit: .cover);
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Title - ${index + 1}';
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
                    _text(title, TextStyle(fontWeight: .w500, fontSize: 13)),
                    Row(
                      children: [
                        Flexible(child: _text('$title ' * 3, TextStyle(fontSize: 12))),
                        ElText('最快30分钟送达', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    _text(title, TextStyle(fontSize: 12)),
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
                    child: CustomScrollView(
                      scrollDirection: .horizontal,
                      primary: false,
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
                                  _text('$title · ${productIndex + 1}', TextStyle(fontSize: 12)),
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
