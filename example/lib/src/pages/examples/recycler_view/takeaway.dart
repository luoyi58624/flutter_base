import 'dart:math' as math;

import 'package:faker/faker.dart' as fake;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/recycler_view.dart' as rv;

import '../../../widgets/example_scrollbar.dart';
import '../../example_page.dart';
import 'scroll_mode.dart';

part 'takeaway_data.dart';
part 'takeaway_card.dart';

/// 用密集商家信息、随机图片和店内横向菜单对比三种长列表。
class RecyclerTakeawayPage extends StatefulWidget {
  /// 创建一万家商家的外卖示例，数据和图片按商家身份稳定生成。
  // ignore: prefer_const_constructors_in_immutables
  RecyclerTakeawayPage({super.key});

  @override
  State<RecyclerTakeawayPage> createState() => _RecyclerTakeawayPageState();
}

class _RecyclerTakeawayPageState extends State<RecyclerTakeawayPage> {
  final _controller = ScrollController(keepScrollOffset: false);
  final _elController = ScrollController(keepScrollOffset: false);
  final _cart = ValueNotifier<(int, int)>((0, 0));
  final _stores = <int, _Store>{};
  var _indices = List<int>.generate(10000, (index) => index);
  var _category = -1;
  RecyclerExampleScrollMode _mode = .recyclerView;
  late final _adapter = _StoreAdapter(this);
  late final _list = rv.RecyclerView(key: ValueKey('recycler-takeaway-list'), controller: _controller)
    ..setLayoutManager(rv.LinearLayoutManager())
    ..setAdapter(_adapter);

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
    final controller = _mode == .elScrollView ? _elController : _controller;
    if (controller.hasClients) controller.jumpTo(0);
  }

  void _choose(RecyclerExampleScrollMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    _list.scrollToPosition(0);
  }

  Widget _row(BuildContext context, int index) =>
      _OfficialStoreRow(key: ValueKey(_indices[index]), store: _storeAt(index), onAdd: _add);

  Widget _content() {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: '外卖商家列表',
      actions: [
        PopupMenuButton<RecyclerExampleScrollMode>(
          key: ValueKey('takeaway-menu'),
          tooltip: '列表选项',
          onSelected: _choose,
          itemBuilder: (context) => [
            for (final mode in RecyclerExampleScrollMode.values)
              CheckedPopupMenuItem(
                key: ValueKey('takeaway-mode-${mode.name}'),
                checked: _mode == mode,
                value: mode,
                child: Text(mode.label),
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
  _StoreHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) => _StoreHolder(page._add);

  @override
  void onBindViewHolder(_StoreHolder holder, int position, [List<Object> payloads = const []]) =>
      holder.store.value = page._storeAt(position);
}

class _StoreHolder extends rv.ViewHolder {
  _StoreHolder(ValueChanged<_Dish> onAdd) : this._(ValueNotifier<_Store?>(null), onAdd);
  _StoreHolder._(this.store, ValueChanged<_Dish> onAdd) : super(_StoreCard(store: store, onAdd: onAdd));
  final ValueNotifier<_Store?> store;
}

class _OfficialStoreRow extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _OfficialStoreRow({super.key, required this.store, required this.onAdd});
  final _Store store;
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
  Widget build(BuildContext context) => _StoreCard(store: _store, onAdd: widget.onAdd);
}
