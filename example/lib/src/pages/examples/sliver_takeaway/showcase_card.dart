part of 'index.dart';

const _foodPaper = Color(0xfffaf7f1),
    _foodCard = Color(0xfffffdf9),
    _foodInk = Color(0xff251f1a),
    _foodMuted = Color(0xff72675c),
    _foodOrange = Color(0xffe65225),
    _foodLine = Color(0xffebe4d9),
    _foodGreen = Color(0xff30765b);

Widget _foodText(
  String text, {
  Key? key,
  double size = 12,
  bool bold = false,
  Color color = _foodInk,
  int? lines = 1,
}) => Text(
  text,
  key: key,
  maxLines: lines,
  overflow: lines == null ? null : .ellipsis,
  style: TextStyle(fontSize: size, height: 1.3, color: color, fontWeight: bold ? .w700 : .w400),
);

class _ShowcaseStoreHost extends HookWidget {
  const _ShowcaseStoreHost({required this.index, required this.storeAt, required this.photos, required this.onAdd});
  final ValueListenable<int> index;
  final _Store Function(int) storeAt;
  final ValueListenable<bool> photos;
  final ValueChanged<_Dish> onAdd;
  @override
  Widget build(BuildContext context) {
    useValueListenable(index);
    final store = storeAt(index.value);
    final model = useMemoized(() => ValueNotifier<_Store?>(store));
    useEffect(() => model.dispose, []);
    model.value = store;
    final scroll = useScrollController(initialScrollOffset: store.menuOffset, keys: [store.id]);
    useEffect(() {
      void save() {
        store.menuOffset = scroll.offset;
      }

      scroll.addListener(save);
      return () => scroll.removeListener(save);
    }, [store, scroll]);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth <= 560;
        final small = constraints.maxWidth <= 350;
        final textScale = (MediaQuery.textScalerOf(context).scale(12) / 12).clamp(1.0, 1.6);
        final size = (compact ? 91.0 : 98.0) * textScale;
        final height =
            (compact ? 331.0 : 347.0) + (store.id % 3) * 20 + (MediaQuery.textScalerOf(context).scale(12) - 12) * 22;
        Widget photo(double dimension, [int? dish]) =>
            _StorePhoto(store: model, photos: photos, size: dimension, dishIndex: dish);
        return Padding(
          padding: .only(bottom: 12),
          child: ElCard(
            style: ElStyle(
              height: height,
              padding: .all(
                small
                    ? 10
                    : compact
                    ? 12
                    : 15,
              ),
              borderRadius: .circular(compact ? 16 : 19),
              backgroundColor: _foodCard,
              border: .all(borderColor: Color(0xffeee6db)),
              boxShadow: [BoxShadow(color: Color(0x0a3d241d), offset: Offset(0, 2), blurRadius: 3)],
            ),
            child: Column(
              crossAxisAlignment: .stretch,
              spacing: 8,
              children: [
                Row(
                  crossAxisAlignment: .start,
                  spacing: 8,
                  children: [
                    photo(
                      small
                          ? 41
                          : compact
                          ? 48
                          : 56,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .stretch,
                        spacing: 5,
                        children: [
                          _foodText(
                            store.name,
                            size: small
                                ? 15
                                : compact
                                ? 16
                                : 19,
                            bold: true,
                          ),
                          _foodText(
                            '★ ${store.rating} · 月售 ${store.sales}+ · ¥${store.minimum} 起送',
                            size: compact ? 11 : 12,
                            color: _foodMuted,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: .end,
                      spacing: 4,
                      children: [
                        _foodText('${store.minutes} 分钟', size: 12, bold: true, color: _foodGreen),
                        _foodText('${store.distance} km', size: 11, color: _foodMuted),
                      ],
                    ),
                  ],
                ),
                _foodText(store.description, size: compact ? 11 : 13, lines: store.id % 3 == 0 ? 1 : 2),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    for (final entry in ['${store.coupon}元店铺红包', '满30减4', '免配送费'].asMap().entries)
                      ElView(
                        style: ElStyle(
                          padding: .symmetric(horizontal: 5, vertical: 2),
                          borderRadius: .circular(5),
                          fontSize: 10,
                          color: entry.key == 2 ? _foodGreen : Color(0xffa44826),
                          backgroundColor: entry.key == 2 ? Color(0xffedf4ea) : Color(0xfffff0e5),
                        ),
                        child: entry.value,
                      ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scroll,
                    scrollDirection: .horizontal,
                    child: Row(
                      crossAxisAlignment: .start,
                      spacing: compact ? 7 : 9,
                      children: [
                        ElCard(
                          style: ElStyle(
                            width: (compact ? 67 : 79) * textScale,
                            height: 149 + (MediaQuery.textScalerOf(context).scale(12) - 12) * 5,
                            padding: .symmetric(horizontal: 3, vertical: 8),
                            borderRadius: .circular(11),
                            backgroundColor: Color(0xfffff0e7),
                            border: .all(borderColor: Color(0xffeeb8a2), borderStyle: .dashed),
                          ),
                          child: Column(
                            mainAxisAlignment: .center,
                            spacing: 5,
                            children: [
                              _foodText('店铺红包', size: 11, color: Color(0xffb74420)),
                              _foodText('¥${store.coupon}', size: 23, bold: true, color: Color(0xffb74420)),
                              _foodText('满额可用', size: 10, color: Color(0xff9a553a)),
                            ],
                          ),
                        ),
                        for (var i = 0; i < store.dishes.length; i++)
                          SizedBox(
                            width: size,
                            child: Column(
                              crossAxisAlignment: .stretch,
                              children: [
                                photo(size, i),
                                SizedBox(height: 5),
                                _foodText(store.dishes[i].name, size: 12, bold: true),
                                SizedBox(height: 2),
                                _foodText('当季新品 · 月售${store.dishes[i].sales}', size: 10, color: _foodMuted),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _foodText(
                                        '¥${_money(store.dishes[i].cents)}',
                                        size: 15,
                                        bold: true,
                                        color: Color(0xffba3e18),
                                      ),
                                    ),
                                    ElButton(
                                      key: ValueKey('home-dish-${store.id}-$i'),
                                      semanticLabel: '添加${store.dishes[i].name}',
                                      onPressed: () => onAdd(store.dishes[i]),
                                      style: ElStyle(
                                        width: 27,
                                        height: 27,
                                        minHeight: 27,
                                        padding: .zero,
                                        borderRadius: .circular(14),
                                        backgroundColor: Color(0xffef6a3b),
                                        iconSize: 20,
                                      ),
                                      child: ElMobileIcons.add,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                ElView(
                  style: ElStyle(
                    padding: .only(top: 7),
                    border: ElBorder.only(borderTop: ElBorderSide(borderColor: Color(0xfff0e9df))),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _foodText('明厨亮灶 · 独立封签', size: 10, color: _foodGreen)),
                      _foodText('门店 #${store.id + 1}', size: 10, color: _foodMuted),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FoodSidebar extends StatelessWidget {
  const _FoodSidebar({required this.photos});
  final ValueListenable<bool> photos;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    spacing: 18,
    children: [
      ElCard(
        style: ElStyle(height: 296, padding: .zero, clipBehavior: .antiAlias, borderRadius: .circular(25)),
        child: Stack(
          fit: .expand,
          children: [
            _StorePhoto(store: AlwaysStoppedAnimation(_Store.generate(0)), photos: photos, size: 296),
            ElView(
              style: ElStyle(
                gradient: LinearGradient(
                  begin: .topCenter,
                  end: .bottomCenter,
                  colors: [Colors.transparent, Color(0xdd251f1a)],
                ),
              ),
            ),
            Positioned(
              left: 22,
              bottom: 22,
              right: 22,
              child: Column(
                crossAxisAlignment: .start,
                spacing: 10,
                children: [
                  _foodText('● 邻里饭桌', color: Colors.white),
                  _foodText('附近的好味道', size: 25, bold: true, color: Colors.white),
                  _foodText('街坊常点的店，今天也开着。', color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
      ElCard(
        style: ElStyle(
          padding: .all(17),
          borderRadius: .circular(18),
          backgroundColor: _foodCard,
          border: .all(borderColor: _foodLine),
        ),
        child: Row(
          spacing: 12,
          children: [
            ElView(
              style: ElStyle(iconColor: _foodOrange),
              child: ElMobileIcons.inbox,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                spacing: 5,
                children: [
                  _foodText('店铺好价', size: 16, bold: true),
                  _foodText('优惠和起送价在商家卡片里', size: 11, color: _foodMuted),
                ],
              ),
            ),
          ],
        ),
      ),
      _foodText('外卖列表演示 · 模拟商家与餐品', size: 11, color: _foodMuted),
    ],
  );
}

class _MealMark extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = Colors.white
      ..style = .stroke
      ..strokeWidth = 1.5
      ..strokeCap = .round;
    canvas.drawPath(
      Path()
        ..moveTo(4, 12)
        ..lineTo(20, 12)
        ..quadraticBezierTo(19, 21, 12, 21)
        ..quadraticBezierTo(5, 21, 4, 12),
      paint,
    );
    for (final x in [9.0, 13.0, 17.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, 4)
          ..cubicTo(x - 3, 6, x, 7, x - 3, 9),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MealMark oldDelegate) => false;
}
