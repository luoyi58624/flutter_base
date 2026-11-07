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

Widget _storeWords(
  ValueListenable<_Store?> store,
  String Function(_Store) select, {
  Key? key,
  double size = 12,
  Color? color,
  bool bold = false,
  int lines = 1,
}) {
  return _StoreText(
    key: key,
    store: store,
    select: select,
    style: TextStyle(
      fontSize: size,
      color: color,
      fontWeight: bold ? .w700 : .w400,
      height: 1.22,
      letterSpacing: 0,
      leadingDistribution: .even,
    ),
    lines: lines,
  );
}

class _StoreText extends LeafRenderObjectWidget {
  const _StoreText({super.key, required this.store, required this.select, required this.style, required this.lines});

  final ValueListenable<_Store?> store;
  final String Function(_Store) select;
  final TextStyle style;
  final int lines;

  TextStyle _resolveStyle(BuildContext context) {
    var resolved = DefaultTextStyle.of(context).style.merge(style);
    if (MediaQuery.boldTextOf(context)) resolved = resolved.merge(TextStyle(fontWeight: .bold));
    return resolved;
  }

  @override
  _RenderStoreText createRenderObject(BuildContext context) => _RenderStoreText(
    store,
    select,
    _resolveStyle(context),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
    maxLines: lines,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderStoreText renderObject) {
    renderObject
      ..textDirection = Directionality.of(context)
      ..textScaler = MediaQuery.textScalerOf(context)
      ..locale = Localizations.maybeLocaleOf(context)
      ..maxLines = lines
      ..bind(store, select, _resolveStyle(context));
  }
}

// 换店时直接更新仍挂载的文字排版对象，静态字段不排入构建或布局队列。
class _RenderStoreText extends RenderParagraph {
  _RenderStoreText(
    this._store,
    this._select,
    TextStyle style, {
    required super.textDirection,
    required super.textScaler,
    required super.locale,
    required super.maxLines,
  }) : _style = style,
       super(
         TextSpan(text: _store.value == null ? '' : _select(_store.value!), style: style),
         overflow: .ellipsis,
       );

  ValueListenable<_Store?> _store;
  String Function(_Store) _select;
  TextStyle _style;

  void bind(ValueListenable<_Store?> store, String Function(_Store) select, TextStyle style) {
    if (!identical(_store, store)) {
      if (attached) _store.removeListener(_update);
      _store = store;
      if (attached) _store.addListener(_update);
    }
    _select = select;
    _style = style;
    _update();
  }

  void _update() {
    final record = _store.value;
    final value = record == null ? '' : _select(record);
    final current = text as TextSpan;
    if (current.text != value || current.style != _style) text = TextSpan(text: value, style: _style);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _store.addListener(_update);
    _update();
  }

  @override
  void detach() {
    _store.removeListener(_update);
    super.detach();
  }
}

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
                          _RandomPhoto(store: store, url: (record) => record.photo, size: 52),
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
                                child: _storeWords(
                                  store,
                                  (record) => record.name,
                                  key: ValueKey('takeaway-title'),
                                  size: 14,
                                  bold: true,
                                ),
                              ),
                              _StoreTag(_words('准时达', size: 9.5, color: _orange), outlined: true),
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
                                  _storeWords(store, (record) => '${record.rating} 分', color: _orange, bold: true),
                                  _storeWords(store, (record) => '月售 ${record.sales}+', size: 10, color: muted),
                                  _storeWords(store, (record) => '起送 ¥${record.minimum}', size: 10, color: muted),
                                ],
                              ),
                              Wrap(
                                spacing: 4,
                                runSpacing: 2,
                                children: [
                                  _storeWords(
                                    store,
                                    (record) => '${record.minutes}–${record.minutes + 10}分钟',
                                    size: 11,
                                    color: _green,
                                  ),
                                  _storeWords(store, (record) => '${record.distance}km', size: 10, color: muted),
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
                                  child: _storeWords(store, (record) => record.address, size: 9.5, color: muted),
                                ),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 4,
                            runSpacing: 3,
                            children: [
                              for (var index = 0; index < 3; index++)
                                _StoreTag(
                                  _storeWords(store, (record) => record.tags[index], size: 9.5, color: _orange),
                                ),
                            ],
                          ),
                          Wrap(
                            spacing: 4,
                            runSpacing: 3,
                            children: [
                              _StoreTag(
                                _storeWords(store, (record) => '${record.coupon}元店铺红包', size: 9.5, color: _orange),
                                outlined: true,
                              ),
                              _StoreTag(_words('满35减5', size: 9.5, color: _orange), outlined: true),
                              _StoreTag(_words('支持自取', size: 9.5, color: _orange), outlined: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                _storeWords(store, (record) => record.description, size: 11, color: muted, lines: 3),
                Row(
                  crossAxisAlignment: .start,
                  spacing: 4,
                  children: [
                    Icon(Icons.format_quote_rounded, size: 12, color: _orange),
                    Expanded(child: _storeWords(store, (record) => record.review, size: 10, color: muted, lines: 2)),
                  ],
                ),
                ValueListenableBuilder<_Store?>(
                  valueListenable: store,
                  builder: (context, record, _) =>
                      record == null ? SizedBox.shrink() : _MenuStrip(store: record, onAdd: onAdd),
                ),
                Row(
                  spacing: 4,
                  children: [
                    Icon(Icons.verified_user_outlined, size: 11, color: _green),
                    Expanded(child: _words('明厨亮灶 · 独立封签 · 售后有保障', size: 9.5, color: muted)),
                    _storeWords(store, (record) => '门店 #${record.id + 1}', size: 9.5, color: muted),
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
  _StoreTag(this.child, {this.outlined = false});
  final Widget child;
  final bool outlined;

  @override
  Widget build(BuildContext context) => ElView(
    style: ElStyle(
      padding: .symmetric(horizontal: 4, vertical: 1),
      borderRadius: .circular(4),
      backgroundColor: _orange.withValues(alpha: outlined ? .025 : .09),
      border: outlined ? ElBorder.all(borderWidth: 1, borderColor: _orange.withValues(alpha: .25)) : null,
    ),
    child: child,
  );
}

class _MenuStrip extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _MenuStrip({required this.store, required this.onAdd});
  final _Store store;
  final ValueChanged<_Dish> onAdd;

  @override
  State<_MenuStrip> createState() => _MenuStripState();
}

class _MenuStripState extends State<_MenuStrip> {
  late final _controller = ScrollController(initialScrollOffset: widget.store.menuOffset, keepScrollOffset: false);
  late final _store = ValueNotifier<_Store?>(widget.store);
  late final _coupon = _CouponTile(store: _store, width: 52);
  final _tiles = <int, Widget>{};
  double? _tileWidth;
  (double, int, ScrollBehavior)? _configuration;
  Widget? _frame;
  var _restoring = false;

  @override
  void didUpdateWidget(_MenuStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store.id == widget.store.id) return;
    // 保留滚动宿主和餐品槽位；换店时停止旧活动，再恢复新店自己的位置。
    _restoring = true;
    try {
      if (_controller.hasClients) {
        final position = _controller.position;
        final offset = widget.store.menuOffset;
        if (!position.hasContentDimensions) {
          // 已 attach 但尚未布局时只校正初始偏移，jumpTo 的弹性计算会读取空滚动范围。
          if (position.pixels != offset) position.correctPixels(offset);
        } else if (position.pixels != offset || position.isScrollingNotifier.value) {
          position.jumpTo(offset);
        }
        // 按住但未拖动时也有活动，换店必须结束上一家的手势。
        if (position is ScrollPositionWithSingleContext) position.goIdle();
      }
    } finally {
      _restoring = false;
    }
    _store.value = widget.store;
  }

  @override
  void dispose() {
    _controller.dispose();
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontDelta = math.max(0.0, MediaQuery.textScalerOf(context).scale(14) - 14);
    final width = 94 + fontDelta * 3;
    final behavior = ScrollConfiguration.of(context);
    final count = widget.store.dishes.length;
    final configuration = (fontDelta, count, behavior);
    if (_configuration == configuration && _frame != null) return _frame!;
    _configuration = configuration;
    if (_tileWidth != width) {
      _tileWidth = width;
      _tiles.clear();
    }
    return _frame = SizedBox(
      height: 184 + fontDelta * 8,
      child: Row(
        crossAxisAlignment: .stretch,
        children: [
          _coupon,
          SizedBox(width: 8),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (!_restoring && notification.depth == 0) widget.store.menuOffset = notification.metrics.pixels;
                // 店内横向通知不交给外层纵向滚动条和 AppBar。
                return true;
              },
              child: ScrollConfiguration(
                behavior: behavior.copyWith(scrollbars: false, dragDevices: PointerDeviceKind.values.toSet()),
                child: ValueListenableBuilder<_Store?>(
                  valueListenable: _store,
                  builder: (context, record, child) =>
                      Semantics(identifier: 'takeaway-menu-${record!.id}', child: child),
                  child: ListView.builder(
                    controller: _controller,
                    scrollDirection: .horizontal,
                    itemCount: count,
                    // 数量变化时更新尺寸回调，让复用的列表刷新最大滚动范围。
                    itemExtentBuilder: (index, dimensions) => index < count ? width + 6 : null,
                    scrollCacheExtent: ScrollCacheExtent.pixels(0),
                    addAutomaticKeepAlives: false,
                    itemBuilder: (context, index) => _tiles.putIfAbsent(
                      index,
                      () => Padding(
                        padding: .only(right: 6),
                        child: _DishTile(
                          store: _store,
                          index: index,
                          width: width,
                          onAdd: (dish) => widget.onAdd(dish),
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
  _DishTile({required this.store, required this.index, required this.width, required this.onAdd});
  final ValueListenable<_Store?> store;
  final int index;
  final double width;
  final ValueChanged<_Dish> onAdd;

  // 菜单数量变少时，旧尾项会在本次布局移除，通知叶子时先容忍这个过渡。
  _Dish? _dish(_Store? record) => record != null && index < record.dishes.length ? record.dishes[index] : null;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ElCard(
      key: ValueKey('takeaway-dish-card'),
      style: ElStyle(padding: EdgeInsets.zero, borderRadius: .circular(6)),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 3,
        children: [
          _RandomPhoto(store: store, url: (record) => _dish(record)?.photo ?? '', size: width),
          _storeWords(store, (record) => _dish(record)?.name ?? '', lines: 2),
          _storeWords(store, (record) => _dish(record)?.subtitle ?? '', size: 9.5, color: muted),
          _storeWords(
            store,
            (record) {
              final dish = _dish(record);
              return dish == null ? '' : '月售${dish.sales} · 好评${dish.praise}%';
            },
            size: 9.5,
            color: muted,
          ),
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
                style: IconButton.styleFrom(tapTargetSize: .shrinkWrap, minimumSize: Size(26, 26), padding: .zero),
                constraints: BoxConstraints.tightFor(width: 28, height: 26),
                onPressed: () {
                  final dish = _dish(store.value);
                  if (dish != null) onAdd(dish);
                },
                icon: Icon(Icons.add_circle_rounded, color: _orange, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CouponTile extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _CouponTile({required this.store, required this.width});
  final ValueListenable<_Store?> store;
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
            child: _storeWords(store, (record) => '¥${record.coupon}', size: 22, color: _orange, bold: true),
          ),
          _words('进店领好价', size: 9, color: _orange, lines: 2),
        ],
      ),
    ),
  );
}

class _RandomPhoto extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _RandomPhoto({required this.store, required this.url, required this.size});
  final ValueListenable<_Store?> store;
  final String Function(_Store) url;
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
    final cacheWidth = (size * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(1, 600);
    return ClipRRect(
      borderRadius: .circular(8),
      child: ValueListenableBuilder<_Store?>(
        valueListenable: store,
        child: placeholder,
        builder: (context, record, fallback) {
          final source = record == null ? '' : url(record);
          if (source.isEmpty) return fallback!;
          return Image.network(
            source,
            width: size,
            height: size,
            fit: .cover,
            cacheWidth: cacheWidth,
            excludeFromSemantics: true,
            frameBuilder: (context, child, frame, synchronous) => frame == null ? fallback! : child,
            errorBuilder: (context, error, stack) => fallback!,
          );
        },
      ),
    );
  }
}
