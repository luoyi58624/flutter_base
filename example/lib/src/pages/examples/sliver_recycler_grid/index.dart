import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../widgets/example_scrollbar.dart';
import '../../../layout/example_page.dart';
import '../../../widgets/panel.dart';
import '../scroll_examples/scroll_mode.dart';

/// 用相同的自然高度卡片展示网格与瀑布流。
class ElSliverRecyclerGridExamplePage extends HookWidget {
  /// 创建按行排列的网格示例。
  const ElSliverRecyclerGridExamplePage({super.key}) : masonry = false;

  /// 创建优先填充最短列的瀑布流示例。
  const ElSliverRecyclerGridExamplePage.masonry({super.key}) : masonry = true;

  /// 是否使用瀑布流排列。
  final bool masonry;

  static const _itemCount = 1000;

  @override
  Widget build(BuildContext context) {
    final columns = useState(2);
    final mode = useState(SliverExampleMode.initial);
    final controller = useScrollController();
    final officialExtent = useMemoized(_OfficialCardExtentCache.new);
    final colors = Theme.of(context).colorScheme;
    final title = masonry ? '瀑布流示例' : '网格示例';

    Widget buildItem(BuildContext context, ValueListenable<int> index) => _RecordCard(index);

    return ExamplePage(
      title: title,
      backgroundColor: colors.surfaceContainerLowest,
      actions: [
        PopupMenuButton<SliverExampleMode>(
          key: ValueKey('grid-mode-menu'),
          tooltip: '切换内容 Sliver',
          onSelected: (value) => mode.value = value,
          itemBuilder: (_) => [...mode.value.menuItems(grid: true, masonry: masonry)],
        ),
        PopupMenuButton<int>(
          tooltip: '选择列数',
          onSelected: (value) => columns.value = value,
          itemBuilder: (_) => [
            for (final count in [2, 3, 4])
              CheckedPopupMenuItem(value: count, checked: columns.value == count, child: Text('$count 列')),
          ],
          icon: Icon(Icons.view_column_outlined),
        ),
      ],
      child: RecyclerExampleScrollbar(
        controller: controller,
        child: mode.value.scrollView(
          key: ValueKey(masonry ? 'sliver-masonry-scroll' : 'sliver-grid-scroll'),
          controller: controller,
          semanticChildCount: _itemCount,
          scrollCacheExtent: ScrollCacheExtent.pixels(250),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('日常观察', style: Theme.of(context).textTheme.headlineSmall),
                    SizedBox(height: 8),
                    Text(
                      masonry ? '不同长度的记录，沿每列自然接续。' : '每行从同一个位置开始，卡片保留各自的内容高度。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '$_itemCount 条记录 · ${columns.value} 列',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.primary),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: mode.value.grid(
                context,
                itemCount: _itemCount,
                crossAxisCount: columns.value,
                masonry: masonry,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                itemBuilder: (context, index) => buildItem(context, AlwaysStoppedAnimation(index)),
                recycledItemBuilder: buildItem,
                officialSliver: SliverLayoutBuilder(
                  builder: (context, constraints) =>
                      officialExtent.build(context, constraints.crossAxisExtent, columns.value),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('所有记录已展示', style: Theme.of(context).textTheme.bodySmall)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfficialCardExtentCache {
  Object? _environment;
  double _extent = 0;
  Object? _geometry;
  Widget? _grid;

  Widget build(BuildContext context, double crossExtent, int columns) {
    final extent = measure(context, (crossExtent - 12 * (columns - 1)) / columns, columns);
    final geometry = (crossExtent, columns, extent, Directionality.of(context));
    // 滚动只改变视口约束；保留 delegate 避免重新配置仍可见的全部卡片。
    if (_geometry != geometry) {
      _geometry = geometry;
      _grid = SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: extent,
        ),
        itemCount: ElSliverRecyclerGridExamplePage._itemCount,
        itemBuilder: (_, index) => _RecordCard(AlwaysStoppedAnimation(index)),
      );
    }
    return _grid!;
  }

  double measure(BuildContext context, double width, int columns) {
    final defaults = DefaultTextStyle.of(context);
    final environment = (
      width,
      columns,
      Theme.of(context).textTheme,
      defaults.style,
      defaults.textAlign,
      defaults.softWrap,
      defaults.overflow,
      defaults.maxLines,
      defaults.textWidthBasis,
      defaults.textHeightBehavior,
      MediaQuery.textScalerOf(context),
      MediaQuery.boldTextOf(context),
      Localizations.maybeLocaleOf(context),
      Directionality.of(context),
    );
    // 滚动约束会不断触发布局，只在宽度或实际文字排版环境改变时重新测量。
    if (_environment != environment) {
      _extent = _officialCardExtent(context, width);
      _environment = environment;
    }
    return _extent;
  }
}

// 官方等高网格按这组有限文案预留完整高度，回收分支仍直接测量自然尺寸。
double _officialCardExtent(BuildContext context, double width) {
  final typography = Theme.of(context).textTheme;
  final defaults = DefaultTextStyle.of(context);
  double height(String text, TextStyle? style) {
    var resolved = defaults.style.merge(style);
    if (MediaQuery.boldTextOf(context)) resolved = resolved.merge(TextStyle(fontWeight: .bold));
    final painter = TextPainter(
      text: TextSpan(text: text, style: resolved),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      textHeightBehavior: defaults.textHeightBehavior,
    )..layout(maxWidth: math.max(1, width - 24));
    final result = painter.height.ceilToDouble();
    painter.dispose();
    return result;
  }

  return 72 +
      24 +
      8 +
      12 +
      _records
          .map(
            (record) =>
                height('${record.title} #1000', typography.titleSmall) +
                height(record.description, typography.bodyMedium?.copyWith(height: 1.5)) +
                height('观察记录 1000', typography.labelSmall),
          )
          .reduce(math.max);
}

// 卡片结构跟随槽位保留，换绑时只更新变化的内容叶子。
class _RecordCard extends StatelessWidget {
  const _RecordCard(this.index);

  final ValueListenable<int> index;

  Widget _field<T>(
    BuildContext context, {
    required T Function(ValueListenable<int>) select,
    required TransitionBuilder builder,
    Widget? child,
  }) {
    // 官方创建的行不会换绑，不增加无效监听节点。
    if (index is AlwaysStoppedAnimation<int>) return builder(context, child);
    return ElListenableBuilder(listenable: index, select: select, builder: builder, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final typography = Theme.of(context).textTheme;
    return ExamplePanel(
      style: ElStyle(
        backgroundColor: colors.surface,
        borderRadius: .circular(16),
        border: .all(borderColor: colors.outlineVariant),
        clipBehavior: .antiAlias,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            context,
            select: (source) => _records[source.value % _records.length].color,
            builder: (context, child) => ColoredBox(color: _records[index.value % _records.length].color, child: child),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _field(
                  context,
                  select: (source) => _records[source.value % _records.length].icon,
                  builder: (context, child) =>
                      Icon(_records[index.value % _records.length].icon, size: 32, color: Color(0xff334155)),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field(
                  context,
                  select: (source) => source.value,
                  builder: (context, child) => Text(
                    '${_records[index.value % _records.length].title} #${index.value + 1}',
                    style: typography.titleSmall,
                  ),
                ),
                SizedBox(height: 8),
                _field(
                  context,
                  select: (source) => _records[source.value % _records.length].description,
                  builder: (context, child) => Text(
                    _records[index.value % _records.length].description,
                    style: typography.bodyMedium?.copyWith(height: 1.5),
                  ),
                ),
                SizedBox(height: 12),
                _field(
                  context,
                  select: (source) => source.value,
                  builder: (context, child) => Text(
                    '观察记录 ${index.value + 1}',
                    style: typography.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _records = [
  (title: '林间漫步', description: '清晨的树影落在小路上。', icon: Icons.forest_outlined, color: Color(0xffdcebdc)),
  (
    title: '沿河骑行',
    description: '沿着河岸慢慢骑行，经过一座旧桥和几间刚开门的小店。停下来买一杯热饮，再继续今天没有目的地的旅程。',
    icon: Icons.directions_bike_outlined,
    color: Color(0xffdce8f4),
  ),
  (
    title: '街角咖啡',
    description: '在熟悉的街角找到一个靠窗的位置。翻几页书，看行人从窗外经过，让周末的时间慢一点。',
    icon: Icons.local_cafe_outlined,
    color: Color(0xfff0e3d5),
  ),
  (title: '落日时分', description: '天空从浅蓝变成橘色，城市的灯光一点点亮起来。', icon: Icons.wb_twilight_outlined, color: Color(0xfff7dfcf)),
  (
    title: '雨天读书',
    description: '雨声落在窗台。读到喜欢的句子，顺手记在纸上。一本书、一盏灯，还有暂时不用赶路的下午，让平常的一天也变得值得记录。',
    icon: Icons.auto_stories_outlined,
    color: Color(0xffe7dff2),
  ),
  (title: '菜市场', description: '带回一束鲜花和晚餐的食材。', icon: Icons.local_florist_outlined, color: Color(0xfff3e9c9)),
];
