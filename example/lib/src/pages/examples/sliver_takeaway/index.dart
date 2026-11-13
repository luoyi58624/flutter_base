import 'dart:math' as math;
import 'dart:async';

import 'package:faker/faker.dart' as fake;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

import '../../../widgets/example_scrollbar.dart';
import '../../../layout/example_page.dart';
import '../../../utils/frame_timing_recorder.dart';
import '../scroll_examples/scroll_mode.dart';

part 'takeaway_data.dart';
part 'takeaway_card.dart';
part 'takeaway_photo.dart';
part 'showcase.dart';
part 'showcase_card.dart';

enum _SliverKind {
  list('列表布局'),
  grid('网格布局');

  const _SliverKind(this.label);

  final String label;
}

/// 用 ElSliver 回收列表和网格滚动同一批外卖商家卡片。
class TakeawaySliverPage extends StatefulWidget {
  /// 创建一千家商家的 Sliver 外卖示例，可指定初始使用网络图片。
  // ignore: prefer_const_constructors_in_immutables
  TakeawaySliverPage({super.key, this.networkPhotos = false});

  /// 初次进入页面时是否直接测试网络图片加载。
  final bool networkPhotos;

  @override
  State<TakeawaySliverPage> createState() => _TakeawaySliverPageState();
}

class _TakeawaySliverPageState extends State<TakeawaySliverPage> {
  final _controller = ScrollController(keepScrollOffset: false);
  final _cart = ValueNotifier<(int, int)>((0, 0));
  final _stores = <int, _Store>{};
  late final _photos = ValueNotifier(widget.networkPhotos);
  var _indices = List<int>.generate(1000, (index) => index);
  var _category = -1;
  var _kind = _SliverKind.list;
  var _mode = SliverExampleMode.initial;

  _Store _storeAt(int position) => _stores.putIfAbsent(_indices[position], () => _Store.generate(_indices[position]));

  void _add(_Dish dish) => _cart.value = (_cart.value.$1 + 1, _cart.value.$2 + dish.cents);

  void _filter(int category) {
    if (_category == category) return;
    setState(() {
      _category = category;
      _indices = [
        for (var id = 0; id < 1000; id++)
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
      case final SliverExampleMode mode:
        setState(() => _mode = mode);
        _resetScroll();
      case _SliverKind kind:
        _choose(kind);
      case bool network:
        _photos.value = network;
    }
  }

  Widget _sliverItem(BuildContext context, ValueListenable<int> index) =>
      _TakeawayCardHost(index: index, storeAt: _storeAt, photos: _photos, onAdd: _add);

  Widget _content() {
    Widget officialItem(BuildContext context, int index) => _sliverItem(context, AlwaysStoppedAnimation(index));
    final sliver = _kind == .list
        ? _mode.list(context, itemCount: _indices.length, itemBuilder: officialItem, recycledItemBuilder: _sliverItem)
        : _mode.grid(
            context,
            itemCount: _indices.length,
            itemBuilder: officialItem,
            recycledItemBuilder: _sliverItem,
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            officialSliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                mainAxisExtent: 360 + math.max(0.0, MediaQuery.textScalerOf(context).scale(16) - 16) * 10,
              ),
              itemCount: _indices.length,
              itemBuilder: officialItem,
            ),
          );
    return RecyclerExampleScrollbar(
      controller: _controller,
      child: CustomScrollView(
        key: ValueKey('takeaway-sliver'),
        controller: _controller,
        // 所有对照模式使用相同的预布局范围。
        scrollCacheExtent: ScrollCacheExtent.pixels(250),
        slivers: [SliverPadding(padding: .all(_kind == .grid ? 8 : 0), sliver: sliver)],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _cart.dispose();
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
            ..._mode.menuItems(keyPrefix: 'takeaway-mode', grid: _kind != .list),
            PopupMenuDivider(),
            for (final kind in _SliverKind.values)
              CheckedPopupMenuItem<Object>(
                key: ValueKey('takeaway-sliver-${kind.name}'),
                checked: _kind == kind,
                value: kind,
                child: Text(kind.label),
              ),
            PopupMenuDivider(),
            CheckedPopupMenuItem<Object>(
              key: ValueKey('takeaway-network-photos'),
              checked: _photos.value,
              value: !_photos.value,
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
            Expanded(
              child: ColoredBox(
                color: Theme.of(context).brightness == .dark ? Color(0xff17191c) : Color(0xfff3f5f7),
                child: _content(),
              ),
            ),
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

class _TakeawayCardHost extends HookWidget {
  // ignore: prefer_const_constructors_in_immutables
  _TakeawayCardHost({required this.index, required this.storeAt, required this.photos, required this.onAdd});

  final ValueListenable<int> index;
  final _Store Function(int) storeAt;
  final ValueListenable<bool> photos;
  final ValueChanged<_Dish> onAdd;

  @override
  Widget build(BuildContext context) {
    // 卡片属于可复用槽位；换店只更新数据，不重建整卡或按商家 ID 更换 Key。
    final store = useMemoized(() => ValueNotifier<_Store?>(null));
    useEffect(() => store.dispose, [store]);
    useEffect(() {
      // 分类重排可以保留相同序号，每次通知都必须重新取当前记录。
      void bind() => store.value = storeAt(index.value);
      bind();
      index.addListener(bind);
      return () => index.removeListener(bind);
    }, [index, storeAt, store]);

    return useMemoized(() => _StoreCard(store: store, photos: photos, onAdd: onAdd), [store, photos, onAdd]);
  }
}
