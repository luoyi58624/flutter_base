import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:faker/faker.dart' as fake;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show
        BoxConstraints,
        BoxHitTestEntry,
        PaintingContext,
        PipelineOwner,
        RenderBox,
        RenderParagraph,
        ScrollCacheExtent,
        ViewportOffset;
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter_base/flutter_base.dart';
// 临时连接官方视口；滚动壳替换后移除，直接复用现有平滑执行器。
// ignore: implementation_imports
import 'package:flutter_base/src/flutter/views/scroll/smooth_scroll/smooth_pointer_scroll.dart';

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

  Widget _sliverItem(BuildContext context, ValueListenable<int> index) =>
      _TakeawayCardHost(index: index, storeAt: _storeAt, photos: _photos, mode: _cardMode, onAdd: _add);

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
      child: _TakeawayScrollView(
        key: ValueKey('takeaway-sliver'),
        controller: _controller,
        // 与旧外卖示例关闭同步预取一致，滚动帧先只处理当前视口的复杂卡片。
        scrollCacheExtent: ScrollCacheExtent.pixels(0),
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

// 仅给当前示例接滚轮；监听放在官方 Scrollable 内部，避免默认直滚先消费事件。
class _TakeawayScrollView extends CustomScrollView {
  // ignore: prefer_const_constructors_in_immutables
  _TakeawayScrollView({super.key, required super.controller, required super.slivers, super.scrollCacheExtent});

  @override
  Widget buildViewport(BuildContext context, ViewportOffset offset, AxisDirection axisDirection, List<Widget> slivers) {
    final position = offset as ScrollPosition;
    final viewport = super.buildViewport(context, offset, axisDirection, slivers);
    return HookBuilder(
      builder: (context) {
        final smooth = useMemoized(
          () => SmoothPointerScrollController(
            position: () => position,
            targetOffsetForDelta: (delta, {from}) =>
                ((from ?? position.pixels) + delta).clamp(position.minScrollExtent, position.maxScrollExtent),
          ),
          [position],
        );
        // 结束活动会派发滚动通知；等宿主完成卸载或位置换绑后再释放。
        useEffect(
          () =>
              () => SchedulerBinding.instance.addPostFrameCallback((_) => smooth.dispose()),
          [smooth],
        );
        smooth.algorithm = ElViewProvider.smoothScrollOf(context);
        final modifiers = ScrollConfiguration.of(context).pointerAxisModifiers;
        return Listener(
          behavior: hitTestBehavior,
          onPointerDown: (_) => smooth.reset(),
          onPointerPanZoomStart: (_) => smooth.reset(),
          onPointerSignal: (event) {
            if (event is PointerScrollInertiaCancelEvent) {
              smooth.reset();
              return;
            }
            if (event is! PointerScrollEvent ||
                smooth.algorithm == null ||
                !position.hasPixels ||
                !position.hasContentDimensions ||
                !position.physics.shouldAcceptUserOffset(position)) {
              return;
            }
            final flip =
                event.kind == PointerDeviceKind.mouse &&
                HardwareKeyboard.instance.logicalKeysPressed.any(modifiers.contains);
            var delta = flip ? event.scrollDelta.dx : event.scrollDelta.dy;
            if (axisDirectionIsReversed(axisDirection)) delta = -delta;
            if (delta == 0 || !smooth.canConsumeDelta(delta)) return;
            GestureBinding.instance.pointerSignalResolver.register(event, (_) {
              if (!context.mounted || !smooth.canConsumeDelta(delta)) return;
              smooth.applyPointerScroll(event, delta);
              event.respond(allowPlatformDefault: false);
            });
          },
          child: viewport,
        );
      },
    );
  }
}

class _TakeawayCardHost extends HookWidget {
  // ignore: prefer_const_constructors_in_immutables
  _TakeawayCardHost({
    required this.index,
    required this.storeAt,
    required this.photos,
    required this.mode,
    required this.onAdd,
  });

  final ValueListenable<int> index;
  final _Store Function(int) storeAt;
  final _TakeawayPhotos photos;
  final ValueListenable<_TakeawayCardMode> mode;
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
