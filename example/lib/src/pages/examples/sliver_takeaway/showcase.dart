part of 'index.dart';

/// 首页内嵌的外卖场景，复用独立示例的数据、图片和回收卡片。
class TakeawayShowcase extends StatefulWidget {
  /// 创建可搜索、排序和管理购物车的演示。
  const TakeawayShowcase({super.key});
  @override
  State<TakeawayShowcase> createState() => _TakeawayShowcaseState();
}

class _TakeawayShowcaseState extends State<TakeawayShowcase> {
  final _controller = ScrollController(keepScrollOffset: false);
  final _stores = <int, _Store>{};
  final _photos = ValueNotifier(false);
  final _cart = ValueNotifier(<_Dish, int>{});
  final _recorder = FrameTimingRecorder();
  List<_StoreSummary>? _summaries;
  var _indices = List<int>.generate(10000, (i) => i);
  var _category = -1, _sort = '综合排序', _query = '';
  Timer? _debounce;

  _Store _storeAt(int position) => _stores.putIfAbsent(_indices[position], () => _Store.generate(_indices[position]));

  void _filter() {
    final query = _query.trim().toLowerCase();
    if (query.isNotEmpty || _sort != '综合排序') {
      _summaries ??= List.generate(10000, _StoreSummary.generate);
    }
    final indices = [
      for (var id = 0; id < 10000; id++)
        if ((_category < 0 || id % _cuisines.length == _category) &&
            (query.isEmpty ||
                _summaries![id].name.toLowerCase().contains(query) ||
                _dishNames[id % _cuisines.length].any((name) => name.contains(query))))
          id,
    ];
    if (_sort != '综合排序') {
      indices.sort((a, b) {
        final first = _summaries![a], second = _summaries![b];
        final order = switch (_sort) {
          '销量优先' => second.sales.compareTo(first.sales),
          '好评优先' => second.rating.compareTo(first.rating),
          _ => first.minutes.compareTo(second.minutes),
        };
        return order == 0 ? a.compareTo(b) : order;
      });
    }
    setState(() => _indices = indices);
    if (_controller.hasClients) _controller.jumpTo(0);
  }

  void _changeQuantity(_Dish dish, int quantity) {
    final next = {..._cart.value};
    if (quantity <= 0) {
      next.remove(dish);
    } else {
      next[dish] = quantity;
    }
    _cart.value = next;
  }

  void _openCart(BuildContext context) => el.popup<void>(
    context,
    title: '已选商品',
    child: ValueListenableBuilder(
      valueListenable: _cart,
      builder: (context, items, _) => items.isEmpty
          ? ElEmpty(title: '购物车还是空的', description: '选几份喜欢的美食吧。')
          : Column(
              mainAxisSize: .min,
              children: [
                for (final item in items.entries)
                  Padding(
                    padding: .symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: .stretch,
                      spacing: 8,
                      children: [
                        Text(item.key.name, style: TextStyle(fontSize: 14, fontWeight: .w600)),
                        Row(
                          children: [
                            Expanded(
                              child: Text('¥${_money(item.key.cents)}', style: TextStyle(color: _orange)),
                            ),
                            SizedBox(
                              width: 128,
                              child: ElInputNumber(
                                value: item.value,
                                min: 0,
                                max: 99,
                                onChanged: (value) => _changeQuantity(item.key, value?.toInt() ?? 0),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    ),
    footer: Builder(
      builder: (context) => Row(
        spacing: 12,
        children: [
          ElButton(variant: .outline, child: '清空', onPressed: () => _cart.value = {}),
          Expanded(
            child: ElButton(child: '继续点餐', onPressed: () => Navigator.of(context).pop()),
          ),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _photos.dispose();
    _cart.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _metrics(BuildContext context) => el.popup(
    context,
    title: '滚动诊断',
    child: ListenableBuilder(
      listenable: _recorder,
      builder: (context, _) {
        final report = _recorder.report;
        String percentile(String key) =>
            report == null ? '—' : '${((report[key] as Map)['p99_ms'] as num).toStringAsFixed(1)} ms';
        return Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          spacing: 14,
          children: [
            Text('已生成商家：${_stores.length} / ${_indices.length}'),
            Text('UI 耗时 P99：${percentile('ui')}'),
            Text('光栅耗时 P99：${percentile('raster')}'),
            Text('Flutter 帧耗时；开始后关闭面板并滚动列表。', style: TextStyle(fontSize: 12)),
            ElButton(
              disabled: _recorder.isActive,
              child: _recorder.isActive ? '采样进行中' : '采样 5 秒',
              onPressed: () => _recorder.start(
                delay: Duration(seconds: 2),
                duration: Duration(seconds: 5),
                refreshRate: View.of(context).display.refreshRate,
                metadata: {'example': 'home-takeaway'},
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _header(BuildContext context, bool compact) {
    final brand = Row(
      mainAxisSize: .min,
      spacing: 7,
      children: [
        ElView(
          style: ElStyle(
            width: 35,
            height: 35,
            alignment: .center,
            backgroundColor: Color(0xffee6537),
            borderRadius: .circular(11),
          ),
          child: CustomPaint(size: Size(23, 23), painter: _MealMark()),
        ),
        Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            _foodText('饭点', size: 21, bold: true),
            Text('FÀN DIǍN', style: TextStyle(fontSize: 7, height: 1, letterSpacing: 1, color: _foodOrange)),
          ],
        ),
      ],
    );
    final location = Row(
      mainAxisSize: .min,
      spacing: 3,
      children: [
        Icon(Icons.location_on_outlined, size: compact ? 13 : 17, color: _foodInk),
        Flexible(child: _foodText('科技园 · 美食街', size: compact ? 10 : 14, bold: true)),
      ],
    );
    final metrics = ElButton(
      variant: .outline,
      semanticLabel: '滚动性能',
      onPressed: () => _metrics(context),
      style: ElStyle(
        width: 36,
        height: 36,
        minHeight: 36,
        padding: .zero,
        borderRadius: .circular(10),
        color: _foodInk,
        iconColor: _foodInk,
        backgroundColor: _foodCard,
        border: .all(borderColor: _foodLine),
      ),
      child: ElMobileIcons.sliders,
    );
    final search = ElInput(
      value: _query,
      semanticLabel: '搜索外卖商家或菜品',
      placeholder: '搜索商家或想吃的菜',
      clearable: true,
      prefix: ElMobileIcons.search,
      style: ElStyle(
        height: (compact ? 35 : 41) * (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 1.6),
        backgroundColor: Color(0xffefebe3),
        borderRadius: .circular(10),
      ),
      onChanged: (value) {
        _query = value;
        _debounce?.cancel();
        _debounce = Timer(Duration(milliseconds: 120), _filter);
      },
    );
    return ElView(
      style: ElStyle(
        padding: compact ? .fromLTRB(13, 8, 13, 9) : .symmetric(horizontal: 24, vertical: 15),
        backgroundColor: _foodPaper,
        border: ElBorder.only(borderBottom: ElBorderSide(borderColor: _foodLine)),
      ),
      child: compact
          ? Column(
              spacing: 7,
              children: [
                Row(
                  spacing: 7,
                  children: [
                    brand,
                    Expanded(
                      child: Align(alignment: .centerRight, child: location),
                    ),
                    metrics,
                  ],
                ),
                search,
              ],
            )
          : Row(
              spacing: 22,
              children: [
                brand,
                location,
                Expanded(child: search),
                metrics,
              ],
            ),
    );
  }

  Widget _feed(BuildContext context, bool compact) => Column(
    crossAxisAlignment: .stretch,
    children: [
      SingleChildScrollView(
        scrollDirection: .horizontal,
        child: Row(
          spacing: compact ? 5 : 7,
          children: [
            for (var i = -1; i < _cuisines.length; i++)
              ElButton.toggle(
                key: ValueKey('home-takeaway-category-$i'),
                value: _category == i,
                variant: .outline,
                onChanged: (_) {
                  _category = i;
                  _filter();
                },
                style: ElStyle(
                  minHeight: compact ? 33 : 39,
                  padding: .symmetric(horizontal: 8),
                  borderRadius: .circular(9),
                  color: _category == i ? Color(0xffac3717) : Color(0xff534a41),
                  iconColor: _category == i ? Color(0xffac3717) : Color(0xff534a41),
                  backgroundColor: _category == i ? Color(0xffffe5d7) : _foodCard,
                  border: .all(borderColor: _category == i ? Color(0xfff2baa4) : _foodLine),
                  fontSize: 12,
                ),
                child: Row(
                  mainAxisSize: .min,
                  spacing: 5,
                  children: [
                    ElView(
                      style: ElStyle(iconSize: 15),
                      child: i == -1
                          ? ElMobileIcons.grid
                          : i == 2
                          ? ElMobileIcons.spark
                          : ElMobileIcons.inbox,
                    ),
                    ElView(child: i < 0 ? '全部' : _cuisines[i]),
                  ],
                ),
              ),
          ],
        ),
      ),
      Padding(
        padding: .symmetric(vertical: 7),
        child: Row(
          spacing: 8,
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: .center,
                spacing: 8,
                children: [
                  _foodText('附近好店', size: compact ? 21 : 25, bold: true),
                  _foodText(
                    '${_indices.length == 10000 ? '10,000' : _indices.length} 家',
                    key: ValueKey('home-takeaway-count'),
                    size: 10,
                    color: _foodMuted,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 96,
              child: ElSelect<String>(
                value: _sort,
                style: ElStyle(
                  height: 33,
                  fontSize: 12,
                  padding: .symmetric(horizontal: 7),
                  backgroundColor: _foodCard,
                  borderRadius: .circular(9),
                  border: .all(borderColor: _foodLine),
                ),
                children: [
                  for (final label in ['综合排序', '配送最快', '好评优先']) ElMenuOption(label, label),
                ],
                onChanged: (value) {
                  _sort = value;
                  _filter();
                },
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: _indices.isEmpty
            ? Center(
                child: ElEmpty(title: '没找到相关商家', description: '试试其他关键词或分类'),
              )
            : ElScrollView.sliver(
                key: ValueKey('home-takeaway-list'),
                controller: _controller,
                scrollCacheExtent: ScrollCacheExtent.pixels(0),
                slivers: [
                  ElSliverRecyclerList(
                    itemCount: _indices.length,
                    itemBuilder: (context, index) => _ShowcaseStoreHost(
                      index: index,
                      storeAt: _storeAt,
                      photos: _photos,
                      onAdd: (dish) => _changeQuantity(dish, (_cart.value[dish] ?? 0) + 1),
                    ),
                  ),
                ],
              ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => ElComponentProvider(
    themeMode: ElThemeMode(brightness: .light),
    style: ElStyle(
      color: _foodInk,
      vars: {
        ElTokens.$primary: _foodOrange,
        ElTokens.$primaryText: Colors.white,
        ElTokens.$cardColor: _foodCard,
        ElTokens.$bgColor: _foodPaper,
        ElTokens.$fill: Color(0xffefebe3),
        ElTokens.$textColor: _foodInk,
        ElTokens.$textSecondary: _foodMuted,
        ElTokens.$borderColor: _foodLine,
      },
    ),
    child: Builder(
      builder: (context) => DefaultTextStyle.merge(
        style: TextStyle(color: _foodInk),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth <= 560;
            final wide = constraints.maxWidth > 850;
            return ElCard(
              style: ElStyle(
                height: (MediaQuery.sizeOf(context).height * .78).clamp(620, 780),
                padding: .zero,
                backgroundColor: Color(0xfff6f3ed),
                borderRadius: .circular(18),
                clipBehavior: .antiAlias,
                border: .all(borderColor: _foodLine),
              ),
              child: Column(
                children: [
                  _header(context, compact),
                  Expanded(
                    child: Padding(
                      padding: wide ? .fromLTRB(24, 22, 24, 0) : .fromLTRB(10, 8, 10, 0),
                      child: Row(
                        crossAxisAlignment: .start,
                        spacing: 30,
                        children: [
                          if (wide) SizedBox(width: 278, child: _FoodSidebar(photos: _photos)),
                          Expanded(child: _feed(context, compact)),
                        ],
                      ),
                    ),
                  ),
                  ElView(
                    style: ElStyle(
                      padding: .symmetric(horizontal: compact ? 11 : 20, vertical: 6),
                      backgroundColor: _foodPaper,
                      border: ElBorder.only(borderTop: ElBorderSide(borderColor: _foodLine)),
                    ),
                    child: Align(
                      alignment: .centerRight,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: compact ? double.infinity : 275),
                        child: ValueListenableBuilder(
                          valueListenable: _cart,
                          builder: (context, items, _) {
                            final count = items.values.fold(0, (a, b) => a + b),
                                cents = items.entries.fold(0, (sum, e) => sum + e.key.cents * e.value);
                            return ElButton(
                              key: ValueKey('home-takeaway-cart'),
                              onPressed: () => _openCart(context),
                              semanticLabel: '购物车，$count 份，合计 ${_money(cents)} 元',
                              style: ElStyle(
                                width: '100%',
                                minHeight: 45,
                                padding: .fromLTRB(5, 4, 11, 4),
                                borderRadius: .circular(15),
                                backgroundColor: Color(0xff30271f),
                                border: .only(),
                                color: Color(0xfffff4e6),
                                iconColor: Color(0xffffdfcb),
                              ),
                              child: Row(
                                spacing: 11,
                                children: [
                                  ElView(
                                    style: ElStyle(
                                      width: 37,
                                      height: 37,
                                      alignment: .center,
                                      borderRadius: .circular(11),
                                      backgroundColor: Color(0xff533727),
                                      iconSize: 20,
                                    ),
                                    child: ElMobileIcons.briefcase,
                                  ),
                                  Expanded(
                                    child: Wrap(
                                      spacing: 8,
                                      crossAxisAlignment: .center,
                                      children: [
                                        _foodText(
                                          '¥${_money(cents)}',
                                          key: ValueKey('home-takeaway-total'),
                                          size: 18,
                                          bold: true,
                                          color: Color(0xfffff4e6),
                                        ),
                                        _foodText(
                                          count == 0 ? '购物车' : '购物车 · $count 份',
                                          size: 11,
                                          color: Color(0xffffdfcb),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElView(style: ElStyle(iconSize: 16), child: ElMobileIcons.chevronRight),
                                ],
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
          },
        ),
      ),
    ),
  );
}
