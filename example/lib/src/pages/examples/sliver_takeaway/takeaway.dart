import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:faker/faker.dart' as fake;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show BoxConstraints, BoxHitTestEntry, PaintingContext, PipelineOwner, RenderBox, RenderParagraph, ScrollCacheExtent;
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../widgets/example_image.dart';
import '../../../widgets/example_scrollbar.dart';
import '../../example_page.dart';

part 'takeaway_data.dart';
part 'takeaway_card.dart';
part 'takeaway_photo.dart';
part 'takeaway_render_card.dart';
part 'takeaway_render_canvas.dart';
part 'takeaway_render_interaction.dart';

enum _TakeawayCardMode { widgets, renderObject }

enum _SliverKind {
  list('ElSliverRecyclerList'),
  grid('ElSliverRecyclerGrid');

  const _SliverKind(this.label);

  final String label;
}

/// 用 ElSliver 回收列表和网格滚动同一批外卖商家卡片。
class TakeawaySliverPage extends StatefulWidget {
  /// 创建一万家商家的 Sliver 外卖示例，可指定初始使用网络图片。
  // ignore: prefer_const_constructors_in_immutables
  TakeawaySliverPage({super.key, this.networkPhotos = false});

  /// 初次进入页面时是否直接测试网络图片加载。
  final bool networkPhotos;

  @override
  State<TakeawaySliverPage> createState() => _TakeawaySliverPageState();
}

class _TakeawaySliverPageState extends State<TakeawaySliverPage> with SingleTickerProviderStateMixin {
  final _controller = ScrollController(keepScrollOffset: false);
  final _cart = ValueNotifier<(int, int)>((0, 0));
  final _cardMode = ValueNotifier(_TakeawayCardMode.widgets);
  final _stores = <int, _Store>{};
  late final _photos = _TakeawayPhotos(widget.networkPhotos, this);
  var _indices = List<int>.generate(10000, (index) => index);
  var _category = -1;
  var _kind = _SliverKind.list;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_photos.network.value || _cardMode.value == .renderObject) _photos.atlas.resolve(context);
  }

  _Store _storeAt(int position) => _stores.putIfAbsent(_indices[position], () => _Store.generate(_indices[position]));

  void _add(_Dish dish) => _cart.value = (_cart.value.$1 + 1, _cart.value.$2 + dish.cents);

  void _filter(int category) {
    if (_category == category) return;
    setState(() {
      _category = category;
      _indices = [
        for (var id = 0; id < 10000; id++)
          if (category < 0 || id % _cuisines.length == category) id,
      ];
    });
    _resetScroll();
  }

  void _resetScroll() {
    if (_controller.hasClients) _controller.jumpTo(0);
  }

  void _choose(_SliverKind kind) {
    if (_kind == kind) return;
    setState(() => _kind = kind);
    _resetScroll();
  }

  void _selectOption(Object option) {
    switch (option) {
      case _SliverKind kind:
        _choose(kind);
      case _TakeawayCardMode mode:
        if (mode == .renderObject) _photos.atlas.resolve(context);
        _cardMode.value = mode;
      case bool network:
        if (!network) _photos.atlas.resolve(context);
        _photos.network.value = network;
    }
  }

  Widget _row(BuildContext context, int index) => _OfficialStoreRow(
    key: ValueKey(_indices[index]),
    store: _storeAt(index),
    photos: _photos,
    mode: _cardMode,
    onAdd: _add,
  );

  Widget _sliverItem(BuildContext context, ValueListenable<int> index) =>
      ValueListenableBuilder<int>(valueListenable: index, builder: (context, value, _) => _row(context, value));

  Widget _content() {
    final sliver = _kind == .list
        ? ElSliverRecyclerList(itemCount: _indices.length, itemBuilder: _sliverItem)
        : ElSliverRecyclerGrid(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            itemCount: _indices.length,
            itemBuilder: _sliverItem,
          );
    return RecyclerExampleScrollbar(
      controller: _controller,
      child: CustomScrollView(
        key: ValueKey('takeaway-sliver'),
        controller: _controller,
        scrollCacheExtent: ScrollCacheExtent.pixels(250),
        slivers: [SliverPadding(padding: .all(_kind == .grid ? 8 : 0), sliver: sliver)],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _cart.dispose();
    _cardMode.dispose();
    _photos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: '外卖商家 · ElSliver',
      actions: [
        PopupMenuButton<Object>(
          key: ValueKey('takeaway-sliver-menu'),
          tooltip: '列表选项',
          onSelected: _selectOption,
          itemBuilder: (context) => [
            for (final kind in _SliverKind.values)
              CheckedPopupMenuItem<Object>(
                key: ValueKey('takeaway-sliver-${kind.name}'),
                checked: _kind == kind,
                value: kind,
                child: Text(kind.label),
              ),
            PopupMenuDivider(),
            CheckedPopupMenuItem<Object>(
              key: ValueKey('takeaway-render-card-mode'),
              checked: _cardMode.value == .renderObject,
              value: _cardMode.value == .renderObject ? _TakeawayCardMode.widgets : _TakeawayCardMode.renderObject,
              child: Text('纯 RenderObject 卡片'),
            ),
            CheckedPopupMenuItem<Object>(
              key: ValueKey('takeaway-network-photos'),
              checked: _cardMode.value == .widgets && _photos.network.value,
              enabled: _cardMode.value == .widgets,
              value: !_photos.network.value,
              child: Text('网络图片'),
            ),
          ],
        ),
      ],
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _DiscoveryHeader(category: _category, count: _indices.length, onCategory: _filter),
            Expanded(child: _content()),
            ValueListenableBuilder<(int, int)>(
              valueListenable: _cart,
              builder: (context, cart, child) => ElCard(
                style: ElStyle(padding: .symmetric(horizontal: 12, vertical: 6), borderRadius: BorderRadius.zero),
                child: Row(
                  spacing: 8,
                  children: [
                    Badge(
                      isLabelVisible: cart.$1 > 0,
                      label: Text('${cart.$1}'),
                      child: Icon(Icons.shopping_bag_outlined, size: 26, color: _orange),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        crossAxisAlignment: .center,
                        children: [
                          _words('已选 ${cart.$1} 份', key: ValueKey('takeaway-cart-count'), size: 12),
                          _words(
                            '¥${_money(cart.$2)}',
                            key: ValueKey('takeaway-cart-total'),
                            size: 18,
                            color: _orange,
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      key: ValueKey('takeaway-cart-clear'),
                      style: TextButton.styleFrom(
                        tapTargetSize: .shrinkWrap,
                        minimumSize: Size(40, 30),
                        padding: .symmetric(horizontal: 8),
                      ),
                      onPressed: cart.$1 == 0 ? null : () => _cart.value = (0, 0),
                      child: Text('清空'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfficialStoreRow extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _OfficialStoreRow({super.key, required this.store, required this.photos, required this.mode, required this.onAdd});
  final _Store store;
  final _TakeawayPhotos photos;
  final ValueListenable<_TakeawayCardMode> mode;
  final ValueChanged<_Dish> onAdd;

  @override
  State<_OfficialStoreRow> createState() => _OfficialStoreRowState();
}

class _OfficialStoreRowState extends State<_OfficialStoreRow> {
  late final _store = ValueNotifier<_Store?>(widget.store);

  @override
  void didUpdateWidget(_OfficialStoreRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _store.value = widget.store;
  }

  @override
  Widget build(BuildContext context) =>
      _TakeawayCardHost(store: _store, photos: widget.photos, mode: widget.mode, onAdd: widget.onAdd);
}

class _TakeawayCardHost extends HookWidget {
  // ignore: prefer_const_constructors_in_immutables
  _TakeawayCardHost({required this.store, required this.photos, required this.mode, required this.onAdd});

  final ValueNotifier<_Store?> store;
  final _TakeawayPhotos photos;
  final ValueListenable<_TakeawayCardMode> mode;
  final ValueChanged<_Dish> onAdd;

  @override
  Widget build(BuildContext context) {
    // 切换卡片时保留 holder 和数据，只在条目离开元素树时释放绑定。
    useEffect(() => store.dispose, [store]);
    return ValueListenableBuilder<_TakeawayCardMode>(
      valueListenable: mode,
      child: _StoreCard(store: store, photos: photos, onAdd: onAdd),
      builder: (context, mode, widgetCard) => mode == .widgets
          ? widgetCard!
          : _TakeawayRenderCard(key: ValueKey('takeaway-render-card'), store: store, atlas: photos.atlas, onAdd: onAdd),
    );
  }
}

class _TakeawayPhotos {
  _TakeawayPhotos(bool network, TickerProvider vsync) : network = ValueNotifier(network), atlas = _FoodAtlas(vsync);

  final ValueNotifier<bool> network;
  final _FoodAtlas atlas;

  void dispose() {
    network.dispose();
    atlas.dispose();
  }
}
