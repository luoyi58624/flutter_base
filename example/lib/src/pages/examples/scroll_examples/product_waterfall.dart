import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../widgets/example_image.dart';
import '../../../widgets/example_scrollbar.dart';
import '../../example_page.dart';
import '../../../widgets/panel.dart';

/// 在相同的商品卡片上比较两列瀑布流与延迟的图片尺寸更新。
/// 两种内容 Sliver 都由 CustomScrollView 承载，图片尺寸在业务层延迟揭晓。
class RecyclerProductWaterfallPage extends StatefulWidget {
  /// 创建使用本地图片的瀑布流对照示例。
  // ignore: prefer_const_constructors_in_immutables
  RecyclerProductWaterfallPage({super.key});

  @override
  State<RecyclerProductWaterfallPage> createState() => _RecyclerProductWaterfallPageState();
}

enum _WaterfallMode { recycler, sliverGrid }

typedef _ProductAnchor = ({int index, double top});

class _RecyclerProductWaterfallPageState extends State<RecyclerProductWaterfallPage> {
  final _products = List.generate(1000, _Product.new, growable: false);
  final _knownSizes = <int>{};
  final _recyclerController = ScrollController(keepScrollOffset: false);
  final _flutterController = ScrollController(keepScrollOffset: false);
  final _viewport = GlobalKey();
  final _productContexts = <int, BuildContext>{};
  var _mode = _WaterfallMode.recycler;
  Timer? _pendingSizes;
  _ProductGridLayout? _grid;
  (double, double, bool)? _gridInputs;

  _ProductGeometry _geometryFor(int index) => _products[index].geometry(_knownSizes.contains(index));

  _ProductGridLayout _gridFor(double width, double caption, bool rtl) {
    final inputs = (width, caption, rtl);
    if (inputs != _gridInputs || _grid == null) {
      _gridInputs = inputs;
      _grid = _ProductGridLayout(width / 2, caption, rtl, _products.length, _geometryFor);
    }
    return _grid!;
  }

  _ProductAnchor? _anchor() {
    if (_mode == .sliverGrid) {
      final grid = _grid;
      if (grid == null || !_flutterController.hasClients) return null;
      final pixels = _flutterController.offset;
      final index = grid.getMinChildIndexForScrollOffset(pixels);
      return (index: index, top: grid.start(index) - pixels);
    }
    final viewport = _viewport.currentContext?.findRenderObject();
    if (viewport is! RenderBox) return null;
    final top = viewport.localToGlobal(Offset.zero).dy;
    final bottom = top + viewport.size.height;
    _ProductAnchor? anchor;
    for (final entry in _productContexts.entries) {
      final context = entry.value;
      if (!context.mounted ||
          context.widget is! _ProductTile ||
          (context.widget as _ProductTile).product.id != entry.key) {
        continue;
      }
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y + box.size.height <= top || y >= bottom) continue;
      if (anchor == null || y - top < anchor.top) anchor = (index: entry.key, top: y - top);
    }
    return anchor;
  }

  void _switchMode(_WaterfallMode mode) {
    if (mode == _mode) return;
    final previous = _mode == .recycler ? _recyclerController : _flutterController;
    final pixels = previous.hasClients ? previous.offset : 0.0;
    setState(() => _mode = mode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _mode != mode) return;
      final next = mode == .recycler ? _recyclerController : _flutterController;
      if (next.hasClients) next.jumpTo(pixels.clamp(0.0, next.position.maxScrollExtent));
    });
  }

  void _queueImageSizes() {
    if (_pendingSizes != null || _knownSizes.length == _products.length) return;
    final start = _anchor()?.index ?? 0;
    final next = <int>[];
    for (var offset = 0; offset < _products.length && next.length < 12; offset++) {
      final index = (start + offset) % _products.length;
      if (!_knownSizes.contains(index)) next.add(index);
    }
    setState(() {
      // 固定延迟释放真实资源尺寸，隔离下载、解码和图片布局变化。
      _pendingSizes = Timer(Duration(milliseconds: 450), () => _applyImageSizes(next));
    });
  }

  void _applyImageSizes(List<int> indices) {
    final anchor = _anchor();
    setState(() {
      _pendingSizes = null;
      _knownSizes.addAll(indices);
      _grid = null;
    });
    if (_gridInputs case (final width, final caption, final rtl) when _mode == .sliverGrid && anchor != null) {
      final grid = _gridFor(width, caption, rtl);
      final position = _flutterController.position;
      final max = math.max(0.0, grid.extent - position.viewportDimension);
      final target = (grid.start(anchor.index) - anchor.top).clamp(0.0, max);
      // 本帧的新 SliverGrid 布局会消费修正后的偏移，现有拖动活动可以继续。
      position.correctBy(target - position.pixels);
    }
  }

  void _open(_Product product) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            key: ValueKey('product-waterfall-details'),
            appBar: AppBar(title: Text(product.name)),
            body: SafeArea(
              child: ListView(
                padding: .all(20),
                children: [
                  AspectRatio(
                    aspectRatio: product.sourceRatio,
                    child: Image.asset(
                      product.asset,
                      fit: .cover,
                      excludeFromSemantics: true,
                      frameBuilder: exampleImageFrame,
                      errorBuilder: exampleImageError,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(product.name, style: Theme.of(context).textTheme.headlineSmall),
                  Text(product.price, style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 8),
                  Text('自然影像系列 · ${product.number}。采用无酸纸印制，适合书桌和小型墙面陈列。'),
                  Text('图片原始尺寸 ${product.sourceSize}'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pendingSizes?.cancel();
    _recyclerController.dispose();
    _flutterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExamplePage(
    title: '商品瀑布流',
    actions: [
      PopupMenuButton<_WaterfallMode>(
        key: ValueKey('product-waterfall-mode'),
        tooltip: '切换滚动容器',
        onSelected: _switchMode,
        itemBuilder: (_) => [
          CheckedPopupMenuItem(
            key: ValueKey('product-waterfall-mode-recycler'),
            value: .recycler,
            checked: _mode == .recycler,
            child: Text('ElSliverRecyclerGrid'),
          ),
          CheckedPopupMenuItem(
            key: ValueKey('product-waterfall-mode-sliverGrid'),
            value: .sliverGrid,
            checked: _mode == .sliverGrid,
            child: Text('Flutter SliverGrid'),
          ),
        ],
      ),
    ],
    child: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: .new(maxWidth: 800),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              Padding(
                padding: .fromLTRB(12, 4, 12, 8),
                child: Wrap(
                  alignment: .spaceBetween,
                  crossAxisAlignment: .center,
                  spacing: 12,
                  children: [
                    Text('自然影像商店 · ${_products.length} 件商品'),
                    OutlinedButton.icon(
                      key: ValueKey('product-waterfall-reveal'),
                      onPressed: _pendingSizes == null && _knownSizes.length < _products.length
                          ? _queueImageSizes
                          : null,
                      icon: Icon(Icons.photo_size_select_actual_outlined, size: 18),
                      label: Text('延迟揭晓 12 张尺寸'),
                    ),
                    Text('已揭晓 ${_knownSizes.length} 张', key: ValueKey('product-waterfall-revealed')),
                  ],
                ),
              ),
              Expanded(
                child: SizedBox.expand(
                  key: _viewport,
                  child: _mode == .recycler
                      ? RecyclerExampleScrollbar(
                          controller: _recyclerController,
                          child: CustomScrollView(
                            key: ValueKey('product-recycler-waterfall'),
                            controller: _recyclerController,
                            slivers: [
                              ElSliverRecyclerGrid.masonry(
                                crossAxisCount: 2,
                                itemCount: _products.length,
                                itemBuilder: (context, index) => ValueListenableBuilder<int>(
                                  valueListenable: index,
                                  builder: (context, value, _) => _ProductTile(
                                    product: _products[value],
                                    geometry: _geometryFor(value),
                                    onOpen: _open,
                                    onBuild: (context) => _productContexts[value] = context,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final grid = _gridFor(
                              constraints.maxWidth,
                              _captionExtent(context),
                              Directionality.of(context) == .rtl,
                            );
                            return RecyclerExampleScrollbar(
                              controller: _flutterController,
                              child: CustomScrollView(
                                key: ValueKey('product-official-waterfall'),
                                controller: _flutterController,
                                scrollCacheExtent: ScrollCacheExtent.pixels(0),
                                slivers: [
                                  SliverGrid(
                                    gridDelegate: _ProductGridDelegate(grid),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) => _ProductTile(
                                        key: ValueKey(index),
                                        product: _products[index],
                                        geometry: _geometryFor(index),
                                        onOpen: _open,
                                      ),
                                      childCount: _products.length,
                                      addAutomaticKeepAlives: false,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

enum _ProductGeometry {
  wide(4 / 3),
  compact(1.6),
  square(1),
  portrait(520 / 521);

  const _ProductGeometry(this.ratio);
  final double ratio;
}

class _Product {
  _Product(this.id);
  final int id;
  bool get alternate => id % 4 >= 2;
  String get number => '#${(id + 1).toString().padLeft(4, '0')}';
  String get name => '${alternate ? '林间来客' : '夜色观察'} $number';
  String get price => '¥${29 + id % 7 * 10}';
  String get asset => 'assets/recycler_cards/${alternate ? 'owl-2.jpg' : 'owl.jpg'}';
  String get sourceSize => alternate ? '520 × 521' : '512 × 512';
  double get sourceRatio => geometry(true).ratio;

  _ProductGeometry geometry(bool measured) => measured
      ? alternate
            ? .portrait
            : .square
      : id.isEven
      ? .wide
      : .compact;
}

const _tilePadding = 5.0;

double _captionExtent(BuildContext context) => 70 + math.max(0.0, MediaQuery.textScalerOf(context).scale(14) - 14) * 5;

double _imageExtent(double slotWidth, _ProductGeometry geometry) =>
    math.max(0.0, slotWidth - 2 * _tilePadding) / geometry.ratio;

class _ProductTile extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _ProductTile({super.key, required this.product, required this.geometry, required this.onOpen, this.onBuild});

  final _Product product;
  final _ProductGeometry geometry;
  final ValueChanged<_Product> onOpen;
  final ValueChanged<BuildContext>? onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild?.call(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final colors = Theme.of(context).colorScheme;
        final caption = _captionExtent(context);
        final imageHeight = _imageExtent(constraints.maxWidth, geometry);
        final decodedWidth = (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(96, 520);
        return Padding(
          padding: .all(_tilePadding),
          child: ExamplePanel(
            style: ElStyle(backgroundColor: colors.surfaceContainer, borderRadius: .circular(14)),
            child: InkWell(
              onTap: () => onOpen(product),
              borderRadius: .circular(14),
              child: Column(
                crossAxisAlignment: .stretch,
                mainAxisSize: .min,
                children: [
                  ClipRRect(
                    borderRadius: .vertical(top: .circular(14)),
                    clipBehavior: .hardEdge,
                    child: Image.asset(
                      product.asset,
                      height: imageHeight,
                      cacheWidth: decodedWidth,
                      fit: .cover,
                      excludeFromSemantics: true,
                      frameBuilder: exampleImageFrame,
                      errorBuilder: (_, _, _) => SizedBox(height: imageHeight),
                    ),
                  ),
                  SizedBox(
                    height: caption,
                    child: Padding(
                      padding: .symmetric(horizontal: 9),
                      child: Column(
                        mainAxisAlignment: .center,
                        crossAxisAlignment: .start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: .ellipsis,
                            style: TextStyle(fontWeight: .w600),
                          ),
                          Text(
                            '自然影像 · 无酸艺术纸',
                            maxLines: 1,
                            overflow: .ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            product.price,
                            style: TextStyle(color: colors.primary, fontWeight: .w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProductGridDelegate extends SliverGridDelegate {
  const _ProductGridDelegate(this.layout);
  final _ProductGridLayout layout;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) => layout;

  @override
  bool shouldRelayout(_ProductGridDelegate oldDelegate) => !identical(oldDelegate.layout, layout);
}

// 官方 SliverGrid 仍负责挂载与绘制，只在尺寸变化时重新计算最短列几何。
class _ProductGridLayout extends SliverGridLayout {
  factory _ProductGridLayout(
    double slotWidth,
    double caption,
    bool rtl,
    int count,
    _ProductGeometry Function(int) geometryFor,
  ) {
    final columnEnds = [0.0, 0.0];
    final tiles = <SliverGridGeometry>[];
    final starts = <double>[];
    final maximumEnds = <double>[];
    for (var index = 0; index < count; index++) {
      final column = columnEnds[0] <= columnEnds[1] ? 0 : 1;
      final top = columnEnds[column];
      final height = _imageExtent(slotWidth, geometryFor(index)) + caption + _tilePadding * 2;
      tiles.add(
        SliverGridGeometry(
          scrollOffset: top,
          crossAxisOffset: (rtl ? 1 - column : column) * slotWidth,
          mainAxisExtent: height,
          crossAxisExtent: slotWidth,
        ),
      );
      columnEnds[column] += height;
      starts.add(top);
      maximumEnds.add(math.max(columnEnds[0], columnEnds[1]));
    }
    return _ProductGridLayout._(tiles, starts, maximumEnds);
  }

  const _ProductGridLayout._(this._tiles, this._starts, this._maximumEnds);
  final List<SliverGridGeometry> _tiles;
  final List<double> _starts;
  final List<double> _maximumEnds;

  double get extent => _maximumEnds.last;
  double start(int index) => _starts[index];

  int _countThrough(List<double> values, double offset) {
    var low = 0;
    var high = values.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (values[mid] <= offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) =>
      math.min(_countThrough(_maximumEnds, scrollOffset), _tiles.length - 1);

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) =>
      (_countThrough(_starts, scrollOffset) - 1).clamp(0, _tiles.length - 1);

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) => _tiles[index];

  @override
  double computeMaxScrollOffset(int childCount) => childCount == 0 ? 0 : _maximumEnds[childCount - 1];
}
