part of 'takeaway.dart';

Widget _words(String value, {Key? key, double size = 12, Color? color, bool bold = false, int lines = 1}) => ElView(
  key: key,
  style: ElStyle(
    fontSize: size,
    color: color,
    fontWeight: bold ? .w700 : .w400,
    lineHeight: 1.22,
    maxLines: lines,
    textOverflow: .ellipsis,
  ),
  child: value,
);

class _DiscoveryHeader extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _DiscoveryHeader({required this.category, required this.count, required this.onCategory});
  final int category;
  final int count;
  final ValueChanged<int> onCategory;

  @override
  Widget build(BuildContext context) => ElCard(
    style: ElStyle(padding: .symmetric(horizontal: 12, vertical: 6), borderRadius: BorderRadius.zero),
    child: Column(
      crossAxisAlignment: .stretch,
      spacing: 6,
      children: [
        Row(
          spacing: 6,
          children: [
            _words('送至', size: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
            Icon(Icons.location_on_rounded, color: _orange, size: 14),
            Expanded(child: _words('科技园 · 美食街', size: 12, bold: true)),
            _words('$count 家', size: 10, color: _orange),
          ],
        ),
        SingleChildScrollView(
          scrollDirection: .horizontal,
          child: Row(
            spacing: 6,
            children: [
              for (var index = -1; index < _cuisines.length; index++)
                ChoiceChip(
                  key: ValueKey('takeaway-category-$index'),
                  label: Text(index < 0 ? '全部' : _cuisines[index]),
                  avatar: index < 0 ? Icon(Icons.rice_bowl_rounded, size: 14, color: _orange) : null,
                  visualDensity: .compact,
                  materialTapTargetSize: .shrinkWrap,
                  padding: .symmetric(horizontal: 4, vertical: 0),
                  labelPadding: .symmetric(horizontal: 5),
                  shape: RoundedRectangleBorder(borderRadius: .circular(6)),
                  selected: category == index,
                  showCheckmark: false,
                  selectedColor: _orange.withValues(alpha: .12),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    height: 1.1,
                    color: category == index ? _orange : null,
                    fontWeight: category == index ? .w700 : .w400,
                  ),
                  side: BorderSide(color: category == index ? _orange.withValues(alpha: .3) : Colors.transparent),
                  onSelected: (_) => onCategory(index),
                ),
            ],
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 2,
          children: [
            _words('红包天天领', size: 10, color: _orange),
            _words('附近门店 · 现点现做', size: 10, color: _green),
            _words('免配送费', size: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ],
    ),
  );
}

class _StoreCard extends HookWidget {
  // ignore: prefer_const_constructors_in_immutables
  _StoreCard({required this.store, required this.onAdd});
  final ValueNotifier<_Store?> store;
  final ValueChanged<_Dish> onAdd;

  @override
  Widget build(BuildContext context) {
    // 池中保持订阅与已挂载结构，真正卸载时才释放此 holder 的模型。
    useEffect(() => store.dispose, [store]);
    final record = useValueListenable(store);
    if (record == null) return SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final muted = colors.onSurfaceVariant;
    return Padding(
      padding: .fromLTRB(8, 6, 8, 0),
      child: Align(
        alignment: .topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 840),
          child: ElCard(
            key: ValueKey('takeaway-shop-card'),
            style: ElStyle(padding: .all(8), borderRadius: .circular(10)),
            child: Column(
              crossAxisAlignment: .stretch,
              spacing: 4,
              children: [
                Row(
                  crossAxisAlignment: .start,
                  spacing: 8,
                  children: [
                    SizedBox(
                      key: ValueKey('takeaway-shop-logo'),
                      width: 52,
                      child: Column(
                        spacing: 2,
                        children: [
                          _RandomPhoto(url: record.photo, size: 52),
                          _words('品牌好店', size: 9, color: _orange),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .stretch,
                        spacing: 2,
                        children: [
                          Row(
                            spacing: 6,
                            children: [
                              Expanded(
                                child: _words(record.name, key: ValueKey('takeaway-title'), size: 14, bold: true),
                              ),
                              _StoreTag('准时达', outlined: true),
                            ],
                          ),
                          Wrap(
                            alignment: .spaceBetween,
                            spacing: 8,
                            runSpacing: 2,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 2,
                                children: [
                                  _words('${record.rating} 分', size: 12, color: _orange, bold: true),
                                  _words('月售 ${record.sales}+', size: 10, color: muted),
                                  _words('起送 ¥${record.minimum}', size: 10, color: muted),
                                ],
                              ),
                              Wrap(
                                spacing: 4,
                                runSpacing: 2,
                                children: [
                                  _words('${record.minutes}–${record.minutes + 10}分钟', size: 11, color: _green),
                                  _words('${record.distance}km', size: 10, color: muted),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            spacing: 6,
                            children: [
                              _words('免配送费', size: 10, color: _orange),
                              Expanded(
                                child: Align(
                                  alignment: .centerRight,
                                  child: _words(record.address, size: 9.5, color: muted),
                                ),
                              ),
                            ],
                          ),
                          Wrap(spacing: 4, runSpacing: 3, children: [for (final tag in record.tags) _StoreTag(tag)]),
                          Wrap(
                            spacing: 4,
                            runSpacing: 3,
                            children: [
                              _StoreTag('${record.coupon}元店铺红包', outlined: true),
                              _StoreTag('满35减5', outlined: true),
                              _StoreTag('支持自取', outlined: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                _words(record.description, size: 11, color: muted, lines: 3),
                Row(
                  crossAxisAlignment: .start,
                  spacing: 4,
                  children: [
                    Icon(Icons.format_quote_rounded, size: 12, color: _orange),
                    Expanded(child: _words(record.review, size: 10, color: muted, lines: 2)),
                  ],
                ),
                _MenuStrip(key: ValueKey('takeaway-dishes-${record.id}'), store: record, onAdd: onAdd),
                Row(
                  spacing: 4,
                  children: [
                    Icon(Icons.verified_user_outlined, size: 11, color: _green),
                    Expanded(child: _words('明厨亮灶 · 独立封签 · 售后有保障', size: 9.5, color: muted)),
                    _words('门店 #${record.id + 1}', size: 9.5, color: muted),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreTag extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _StoreTag(this.label, {this.outlined = false});
  final String label;
  final bool outlined;

  @override
  Widget build(BuildContext context) => ElView(
    style: ElStyle(
      padding: .symmetric(horizontal: 4, vertical: 1),
      borderRadius: .circular(4),
      backgroundColor: _orange.withValues(alpha: outlined ? .025 : .09),
      border: outlined ? ElBorder.all(borderWidth: 1, borderColor: _orange.withValues(alpha: .25)) : null,
    ),
    child: _words(label, size: 9.5, color: _orange),
  );
}

class _MenuStrip extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _MenuStrip({super.key, required this.store, required this.onAdd});
  final _Store store;
  final ValueChanged<_Dish> onAdd;

  @override
  State<_MenuStrip> createState() => _MenuStripState();
}

class _MenuStripState extends State<_MenuStrip> {
  late final _controller = ScrollController(initialScrollOffset: widget.store.menuOffset, keepScrollOffset: false);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontDelta = math.max(0.0, MediaQuery.textScalerOf(context).scale(14) - 14);
    final width = 94 + fontDelta * 3;
    return SizedBox(
      height: 184 + fontDelta * 8,
      child: Row(
        crossAxisAlignment: .stretch,
        children: [
          _CouponTile(amount: widget.store.coupon, width: 52),
          SizedBox(width: 8),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.depth == 0) widget.store.menuOffset = notification.metrics.pixels;
                // 店内横向通知不交给外层纵向滚动条和 AppBar。
                return true;
              },
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: false, dragDevices: PointerDeviceKind.values.toSet()),
                child: ListView.separated(
                  key: ValueKey('takeaway-menu-list-${widget.store.id}'),
                  controller: _controller,
                  scrollDirection: .horizontal,
                  itemCount: widget.store.dishes.length,
                  separatorBuilder: (context, index) => SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final dish = widget.store.dishes[index];
                    return SizedBox(
                      width: width,
                      child: ElCard(
                        key: ValueKey('takeaway-dish-card'),
                        style: ElStyle(padding: EdgeInsets.zero, borderRadius: .circular(6)),
                        child: Column(
                          crossAxisAlignment: .stretch,
                          spacing: 3,
                          children: [
                            _RandomPhoto(url: dish.photo, size: width),
                            _words(dish.name, size: 12, lines: 2),
                            _words(dish.subtitle, size: 9.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            _words(
                              '月售${dish.sales} · 好评${dish.praise}%',
                              size: 9.5,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            Row(
                              children: [
                                Expanded(child: _words('¥${_money(dish.cents)}', size: 16, color: _orange, bold: true)),
                                IconButton(
                                  key: ValueKey('takeaway-add-${widget.store.id}-$index'),
                                  tooltip: '加入${dish.name}',
                                  visualDensity: .compact,
                                  padding: .zero,
                                  style: IconButton.styleFrom(
                                    tapTargetSize: .shrinkWrap,
                                    minimumSize: Size(26, 26),
                                    padding: .zero,
                                  ),
                                  constraints: BoxConstraints.tightFor(width: 28, height: 26),
                                  onPressed: () => widget.onAdd(dish),
                                  icon: Icon(Icons.add_circle_rounded, color: _orange, size: 22),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponTile extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _CouponTile({required this.amount, required this.width});
  final int amount;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: ElCard(
      key: ValueKey('takeaway-coupon'),
      style: ElStyle(padding: .all(4), borderRadius: .circular(6)),
      child: Column(
        mainAxisAlignment: .center,
        spacing: 6,
        children: [
          Icon(Icons.local_activity_rounded, color: _orange, size: 20),
          _words('店铺红包', size: 10, color: _orange, lines: 2),
          FittedBox(
            fit: .scaleDown,
            child: _words('¥$amount', size: 22, color: _orange, bold: true),
          ),
          _words('进店领好价', size: 9, color: _orange, lines: 2),
        ],
      ),
    ),
  );
}

class _RandomPhoto extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _RandomPhoto({required this.url, required this.size});
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: _orange.withValues(alpha: .07),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.restaurant_rounded, color: _orange.withValues(alpha: .6), size: size * .35),
      ),
    );
    return ClipRRect(
      borderRadius: .circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: .cover,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(1, 600),
        excludeFromSemantics: true,
        frameBuilder: (context, child, frame, synchronous) => frame == null ? placeholder : child,
        errorBuilder: (context, error, stack) => placeholder,
      ),
    );
  }
}
