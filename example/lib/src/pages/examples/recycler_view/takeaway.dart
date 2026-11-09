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
import 'package:flutter_base/recycler_view.dart' as rv;

import '../../../widgets/example_image.dart';
import '../../../widgets/plain_scroll.dart';
import '../../../widgets/example_scrollbar.dart';
import '../../example_page.dart';
import 'scroll_mode.dart';

part 'takeaway_data.dart';
part 'takeaway_card.dart';
part 'takeaway_photo.dart';
part 'takeaway_render_card.dart';
part 'takeaway_render_canvas.dart';
part 'takeaway_render_interaction.dart';

enum _TakeawayCardMode { widgets, renderObject }

/// 用密集商家信息、餐品图片和店内横向菜单对比长列表。
class RecyclerTakeawayPage extends StatefulWidget {
  /// 创建一万家商家的外卖示例，可指定初始使用网络图片。
  // ignore: prefer_const_constructors_in_immutables
  RecyclerTakeawayPage({super.key, this.networkPhotos = false});

  /// 初次进入页面时是否直接测试网络图片加载。
  final bool networkPhotos;

  @override
  State<RecyclerTakeawayPage> createState() => _RecyclerTakeawayPageState();
}

class _RecyclerTakeawayPageState extends State<RecyclerTakeawayPage> with SingleTickerProviderStateMixin {
  final _controller = ScrollController(keepScrollOffset: false);
  final _elController = ScrollController(keepScrollOffset: false);
  final _cart = ValueNotifier<(int, int)>((0, 0));
  final _cardMode = ValueNotifier(_TakeawayCardMode.widgets);
  final _stores = <int, _Store>{};
  late final _photos = _TakeawayPhotos(widget.networkPhotos, this);
  var _indices = List<int>.generate(10000, (index) => index);
  var _category = -1;
  RecyclerExampleScrollMode _mode = .recyclerView;
  late final _adapter = _StoreAdapter(this);
  late final _list = rv.RecyclerView(key: ValueKey('recycler-takeaway-list'), controller: _controller)
    // 商家卡片的同步预取曾占用近 5ms，纵向帧先只处理当前视口。
    ..setLayoutManager(rv.LinearLayoutManager()..setItemPrefetchEnabled(false))
    ..setAdapter(_adapter);

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
    _adapter.notifyDataSetChanged();
    _resetScroll();
  }

  void _resetScroll() {
    _list.scrollToPosition(0);
    final controller = _mode == .elScrollView || _mode == .plain ? _elController : _controller;
    if (controller.hasClients) controller.jumpTo(0);
  }

  void _choose(RecyclerExampleScrollMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    _list.scrollToPosition(0);
  }

  void _selectOption(Object option) {
    switch (option) {
      case RecyclerExampleScrollMode mode:
        _choose(mode);
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

  Widget _content() {
    if (_mode == .plain) {
      return ExamplePlainScroll(
        key: ValueKey('takeaway-plain-list'),
        controller: _elController,
        maxCount: _indices.length,
        revision: (_category, _indices.length),
        scrollbar: RecyclerExampleIosScrollbar(),
        itemBuilder: _row,
      );
    }
    if (_mode == .elScrollView) {
      return ElScrollView(
        key: ValueKey('el-takeaway-list'),
        controller: _elController,
        scrollbar: RecyclerExampleIosScrollbar(),
        children: [ElListView.builder(keepAlive: false, itemCount: _indices.length, itemBuilder: _row)],
      );
    }
    return RecyclerExampleScrollbar(
      controller: _controller,
      child: _mode == .recyclerView
          ? _list
          : ListView.builder(
              key: ValueKey('official-takeaway-list'),
              controller: _controller,
              itemCount: _indices.length,
              addAutomaticKeepAlives: false,
              itemBuilder: _row,
            ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _elController.dispose();
    _cart.dispose();
    _cardMode.dispose();
    _photos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: '外卖商家列表',
      actions: [
        PopupMenuButton<Object>(
          key: ValueKey('takeaway-menu'),
          tooltip: '列表选项',
          onSelected: _selectOption,
          itemBuilder: (context) => [
            for (final mode in RecyclerExampleScrollMode.values)
              CheckedPopupMenuItem<Object>(
                key: ValueKey('takeaway-mode-${mode.name}'),
                checked: _mode == mode,
                value: mode,
                child: Text(mode.label),
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

class _StoreAdapter extends rv.Adapter<_StoreHolder> {
  _StoreAdapter(this.page) {
    setHasStableIds(true);
  }
  final _RecyclerTakeawayPageState page;

  @override
  int getItemCount() => page._indices.length;

  @override
  int getItemId(int position) => page._indices[position];

  @override
  _StoreHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) =>
      _StoreHolder(page._photos, page._cardMode, page._add);

  @override
  void onBindViewHolder(_StoreHolder holder, int position, [List<Object> payloads = const []]) =>
      holder.store.value = page._storeAt(position);
}

class _StoreHolder extends rv.ViewHolder {
  _StoreHolder(_TakeawayPhotos photos, ValueListenable<_TakeawayCardMode> mode, ValueChanged<_Dish> onAdd)
    : this._(ValueNotifier<_Store?>(null), photos, mode, onAdd);
  _StoreHolder._(this.store, _TakeawayPhotos photos, ValueListenable<_TakeawayCardMode> mode, ValueChanged<_Dish> onAdd)
    : super(_TakeawayCardHost(store: store, photos: photos, mode: mode, onAdd: onAdd));
  final ValueNotifier<_Store?> store;
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
