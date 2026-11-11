part of 'index.dart';

Widget _words(String value, {Key? key, double size = 12, Color? color, bool bold = false}) => ElView(
  key: key,
  style: ElStyle(
    fontSize: size,
    color: color,
    fontWeight: bold ? .w700 : .w400,
    lineHeight: 1.22,
    maxLines: 1,
    textOverflow: .ellipsis,
  ),
  child: value,
);

Widget _storeWords(
  ValueListenable<_Store?> store,
  String Function(_Store) select, {
  Key? key,
  double size = 12,
  Color? color,
  bool bold = false,
}) => ElListenableBuilder<ValueListenable<_Store?>, String>(
  listenable: store,
  select: (source) => source.value == null ? '' : select(source.value!),
  builder: (_, _) =>
      _words(store.value == null ? '' : select(store.value!), key: key, size: size, color: color, bold: bold),
);

class _DiscoveryHeader extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _DiscoveryHeader({required this.category, required this.count, required this.onCategory});
  final int category;
  final int count;
  final ValueChanged<int> onCategory;

  @override
  Widget build(BuildContext context) => ElCard(
    style: ElStyle(padding: .symmetric(horizontal: 12, vertical: 8), borderRadius: BorderRadius.zero),
    child: Column(
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        Row(
          spacing: 6,
          children: [
            Icon(Icons.location_on_rounded, color: _orange, size: 16),
            Expanded(child: _words('科技园 · 美食街', size: 13, bold: true)),
            _words('$count 家', size: 11, color: _orange),
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
                  label: Text(index < 0 ? '全部' : _cuisines[index], maxLines: 1, softWrap: false),
                  avatar: index < 0 ? Icon(Icons.rice_bowl_rounded, size: 16, color: _orange) : null,
                  visualDensity: .compact,
                  materialTapTargetSize: .shrinkWrap,
                  padding: .symmetric(horizontal: 6, vertical: 2),
                  labelPadding: .symmetric(horizontal: 5),
                  shape: RoundedRectangleBorder(borderRadius: .circular(8)),
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
        Row(
          children: [
            Expanded(child: _words('红包天天领', size: 10, color: _orange)),
            Expanded(child: _words('附近好店', size: 10, color: _green)),
            Expanded(child: _words('免配送费', size: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ],
    ),
  );
}

class _StoreCard extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _StoreCard({required this.store, required this.photos, required this.onAdd});
  final ValueNotifier<_Store?> store;
  final ValueListenable<bool> photos;
  final ValueChanged<_Dish> onAdd;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: .fromLTRB(8, 8, 8, 0),
      child: Align(
        alignment: .topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 840),
          child: ElCard(
            key: ValueKey('takeaway-shop-card'),
            style: ElStyle(padding: .all(10), borderRadius: .circular(12)),
            child: Column(
              crossAxisAlignment: .stretch,
              spacing: 10,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 220;
                    final title = _storeWords(
                      store,
                      (record) => record.name,
                      key: ValueKey('takeaway-title'),
                      size: 15,
                      bold: true,
                    );
                    final details = Column(
                      crossAxisAlignment: .stretch,
                      spacing: 5,
                      children: [
                        if (!compact) title,
                        _storeWords(
                          store,
                          (record) => '月售${record.sales}+  起送¥${record.minimum}',
                          size: 11,
                          color: muted,
                        ),
                        Row(
                          spacing: 6,
                          children: [
                            _words('免配送费', size: 11, color: _orange, bold: true),
                            Expanded(
                              child: _storeWords(
                                store,
                                (record) => '${record.minutes}–${record.minutes + 10}分钟  ${record.distance}km',
                                size: 10,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                        _StoreTag(
                          _storeWords(store, (record) => '${record.rating}分  ·  ${record.tags.first}', color: _orange),
                        ),
                      ],
                    );
                    final logo = _StorePhoto(store: store, photos: photos, size: compact ? 44 : 64);
                    return compact
                        ? Column(
                            crossAxisAlignment: .stretch,
                            spacing: 6,
                            children: [
                              Row(
                                spacing: 6,
                                children: [
                                  logo,
                                  Expanded(child: title),
                                ],
                              ),
                              details,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: .start,
                            spacing: 10,
                            children: [
                              logo,
                              Expanded(child: details),
                            ],
                          );
                  },
                ),
                Row(
                  spacing: 5,
                  children: [
                    Expanded(child: _StoreTag(_words('堂食店', size: 10, color: _green), outlined: true)),
                    Expanded(child: _StoreTag(_words('明厨亮灶', size: 10, color: muted), outlined: true)),
                    Expanded(
                      flex: 2,
                      child: _StoreTag(
                        _storeWords(store, (record) => '${record.coupon}元店铺红包', size: 10, color: _orange),
                      ),
                    ),
                  ],
                ),
                ValueListenableBuilder<_Store?>(
                  valueListenable: store,
                  builder: (context, record, _) =>
                      record == null ? SizedBox.shrink() : _MenuStrip(store: record, photos: photos, onAdd: onAdd),
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
  _StoreTag(this.child, {this.outlined = false});
  final Widget child;
  final bool outlined;

  @override
  Widget build(BuildContext context) => ElView(
    style: ElStyle(
      padding: .symmetric(horizontal: 4, vertical: 2),
      borderRadius: .circular(3),
      backgroundColor: _orange.withValues(alpha: outlined ? 0 : .08),
      border: outlined ? ElBorder.all(borderWidth: 1, borderColor: Theme.of(context).dividerColor) : null,
    ),
    child: child,
  );
}

double _menuHeight(BuildContext context) => 172 + math.max(0.0, MediaQuery.textScalerOf(context).scale(16) - 16) * 4;

class _MenuStrip extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _MenuStrip({required this.store, required this.photos, required this.onAdd});
  final _Store store;
  final ValueListenable<bool> photos;
  final ValueChanged<_Dish> onAdd;

  @override
  State<_MenuStrip> createState() => _MenuStripState();
}

class _MenuStripState extends State<_MenuStrip> {
  late final _controller = ScrollController(initialScrollOffset: widget.store.menuOffset, keepScrollOffset: false);
  late final _store = ValueNotifier<_Store?>(widget.store);
  late final _dishCount = ValueNotifier(widget.store.dishes.length);
  late final _coupon = _CouponTile(store: _store);
  final _tiles = <int, Widget>{};
  (double, ScrollBehavior)? _configuration;
  Widget? _frame;
  var _restoring = false;

  @override
  void didUpdateWidget(_MenuStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store.id == widget.store.id) return;
    // 店铺换绑时保留菜单宿主，结束旧手势后恢复当前店铺的横向位置。
    _restoring = true;
    try {
      if (_controller.hasClients) {
        final position = _controller.position;
        final offset = widget.store.menuOffset;
        if (!position.hasContentDimensions) {
          if (position.pixels != offset) position.correctPixels(offset);
        } else if (position.pixels != offset || position.isScrollingNotifier.value) {
          position.jumpTo(offset);
        }
        if (position is ScrollPositionWithSingleContext) position.goIdle();
      }
    } finally {
      _restoring = false;
    }
    _store.value = widget.store;
    _dishCount.value = widget.store.dishes.length;
  }

  @override
  void dispose() {
    _controller.dispose();
    _store.dispose();
    _dishCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = _menuHeight(context);
    final behavior = ScrollConfiguration.of(context);
    final configuration = (height, behavior);
    if (_configuration == configuration && _frame != null) return _frame!;
    _configuration = configuration;
    // 每个商品共享一个高度约束，字号改变时统一增加空间，文案长短不影响高度。
    return _frame = SizedBox(
      key: ValueKey('takeaway-menu-frame'),
      height: height,
      child: Row(
        crossAxisAlignment: .stretch,
        children: [
          _coupon,
          SizedBox(width: 8),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (!_restoring && notification.depth == 0) widget.store.menuOffset = notification.metrics.pixels;
                return true;
              },
              child: ScrollConfiguration(
                behavior: behavior.copyWith(scrollbars: false, dragDevices: PointerDeviceKind.values.toSet()),
                child: ElListenableBuilder<ValueListenable<_Store?>, int?>(
                  listenable: _store,
                  select: (source) => source.value?.id,
                  builder: (context, child) => Semantics(identifier: 'takeaway-menu-${_store.value!.id}', child: child),
                  child: ValueListenableBuilder<int>(
                    valueListenable: _dishCount,
                    builder: (context, count, _) => ListView.builder(
                      controller: _controller,
                      scrollDirection: .horizontal,
                      itemCount: count,
                      itemExtent: 112,
                      scrollCacheExtent: ScrollCacheExtent.pixels(0),
                      addAutomaticKeepAlives: false,
                      itemBuilder: (context, index) => _tiles.putIfAbsent(
                        index,
                        () => Padding(
                          padding: .only(right: 8),
                          child: _DishTile(
                            store: _store,
                            photos: widget.photos,
                            index: index,
                            onAdd: (dish) => widget.onAdd(dish),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DishTile extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _DishTile({required this.store, required this.photos, required this.index, required this.onAdd});
  final ValueListenable<_Store?> store;
  final ValueListenable<bool> photos;
  final int index;
  final ValueChanged<_Dish> onAdd;

  _Dish? _dish(_Store? record) => record != null && index < record.dishes.length ? record.dishes[index] : null;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ElCard(
      key: ValueKey('takeaway-dish-card'),
      style: ElStyle(padding: .zero, borderRadius: .circular(6)),
      // ElCard 的内容槽按自然高度排列，显式约束正文才能让底部价格对齐。
      child: SizedBox(
        height: _menuHeight(context),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            _StorePhoto(store: store, photos: photos, dishIndex: index, size: 104),
            SizedBox(height: 6),
            _storeWords(store, (record) => _dish(record)?.name ?? '', key: ValueKey('takeaway-dish-name')),
            Spacer(),
            Row(
              children: [
                Expanded(
                  child: _storeWords(
                    store,
                    (record) => '¥${_money(_dish(record)?.cents ?? 0)}',
                    key: ValueKey('takeaway-dish-price'),
                    size: 16,
                    color: _orange,
                    bold: true,
                  ),
                ),
                IconButton(
                  tooltip: '加入购物车',
                  visualDensity: .compact,
                  padding: .zero,
                  style: IconButton.styleFrom(tapTargetSize: .shrinkWrap, minimumSize: Size(28, 28), padding: .zero),
                  constraints: BoxConstraints.tightFor(width: 28, height: 28),
                  onPressed: () {
                    final dish = _dish(store.value);
                    if (dish != null) onAdd(dish);
                  },
                  icon: Icon(Icons.add_circle_rounded, color: _orange, size: 25),
                ),
              ],
            ),
            _storeWords(store, (record) => '门店价 ¥${_money((_dish(record)?.cents ?? 0) + 400)}', size: 10, color: muted),
          ],
        ),
      ),
    );
  }
}

class _CouponTile extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _CouponTile({required this.store});
  final ValueListenable<_Store?> store;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 56,
    child: ElCard(
      key: ValueKey('takeaway-coupon'),
      style: ElStyle(
        padding: .symmetric(horizontal: 4, vertical: 8),
        borderRadius: .circular(8),
        backgroundColor: _orange.withValues(alpha: .12),
      ),
      child: SizedBox(
        height: _menuHeight(context) - 16,
        child: Column(
          mainAxisAlignment: .spaceBetween,
          children: [
            Icon(Icons.local_activity_rounded, color: _orange, size: 20),
            _words('店铺红包', size: 10, color: _orange),
            FittedBox(
              fit: .scaleDown,
              child: _storeWords(store, (record) => '¥${record.coupon}', size: 24, color: _orange, bold: true),
            ),
            _words('进店领券', size: 10, color: _orange),
          ],
        ),
      ),
    ),
  );
}
