import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_base/flutter_base.dart';

import '../../widgets/example_scrollbar.dart';
import '../example_page.dart';
import '../../widgets/panel.dart';

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
    final official = useState(false);
    final controller = useScrollController();
    final colors = Theme.of(context).colorScheme;
    final title = masonry ? '瀑布流示例' : '网格示例';

    Widget buildItem(BuildContext context, ValueListenable<int> index) => _RecordCard(index);

    return ExamplePage(
      title: title,
      backgroundColor: colors.surfaceContainerLowest,
      actions: [
        PopupMenuButton<bool>(
          key: ValueKey('grid-mode-menu'),
          tooltip: '切换内容 Sliver',
          onSelected: (value) => official.value = value,
          itemBuilder: (_) => [
            CheckedPopupMenuItem(value: false, checked: !official.value, child: Text('ElSliverRecyclerGrid')),
            CheckedPopupMenuItem(value: true, checked: official.value, child: Text('SliverGrid')),
          ],
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
        child: CustomScrollView(
          key: ValueKey(masonry ? 'sliver-masonry-scroll' : 'sliver-grid-scroll'),
          controller: controller,
          semanticChildCount: _itemCount,
          scrollCacheExtent: ScrollCacheExtent.pixels(240),
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
              sliver: official.value
                  ? SliverLayoutBuilder(
                      builder: (context, constraints) => SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns.value,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: _officialCardExtent(
                            context,
                            (constraints.crossAxisExtent - 12 * (columns.value - 1)) / columns.value,
                          ),
                        ),
                        itemCount: _itemCount,
                        itemBuilder: (context, index) => buildItem(context, AlwaysStoppedAnimation(index)),
                      ),
                    )
                  : masonry
                  ? ElSliverRecyclerGrid.masonry(
                      crossAxisCount: columns.value,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      itemCount: _itemCount,
                      itemBuilder: buildItem,
                    )
                  : ElSliverRecyclerGrid(
                      crossAxisCount: columns.value,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      itemCount: _itemCount,
                      itemBuilder: buildItem,
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

// 卡片外壳跟随槽位保留，换绑时由官方 Builder 读取最新记录。
class _RecordCard extends StatelessWidget {
  const _RecordCard(this.index);

  final ValueListenable<int> index;

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
      child: ValueListenableBuilder<int>(
        valueListenable: index,
        builder: (context, position, child) {
          final sample = _records[position % _records.length];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: sample.color,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(sample.icon, size: 32, color: Color(0xff334155)),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${sample.title} #${position + 1}', style: typography.titleSmall),
                    SizedBox(height: 8),
                    Text(sample.description, style: typography.bodyMedium?.copyWith(height: 1.5)),
                    SizedBox(height: 12),
                    Text(
                      '观察记录 ${position + 1}',
                      style: typography.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
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
