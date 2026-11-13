import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../layout/example_page.dart';
import '../bibi/feed.dart';
import '../scroll_examples/scroll_mode.dart';
import '../../../widgets/panel.dart';

/// Sliver 对照与性能测试共用的自然尺寸负载。
enum ElSliverRecyclerExampleContent {
  /// 高密度纯色矩形。
  rectangles('矩形色块'),

  /// 单行纯文本。
  text('纯文本'),

  /// Bibi 首页使用的视频卡片。
  videoCards('Bibi 视频卡片'),

  /// 包含图片、标签、元数据和操作的观察记录卡片。
  complex('复杂子项');

  const ElSliverRecyclerExampleContent(this.label);

  /// 用于下拉菜单与测试报告的负载名称。
  final String label;

  /// 创建一个可复用子项，[index] 会随回收重绑变化。
  ///
  /// 构建器只负责创建结构；变化的内容监听 [index]，事件回调执行时读取它的当前值。
  Widget buildItem(BuildContext context, ValueListenable<int> index) => switch (this) {
    .rectangles => SizedBox(
      height: 32,
      child: ElListenableBuilder<ValueListenable<int>, Color>(
        listenable: index,
        select: (source) => _rectangleColors[source.value % _rectangleColors.length],
        builder: (_, _) => ColoredBox(color: _rectangleColors[index.value % _rectangleColors.length]),
      ),
    ),
    .text => Align(
      alignment: .centerLeft,
      child: ValueListenableBuilder<int>(
        valueListenable: index,
        builder: (_, position, _) => Text('Item - ${position + 1}', maxLines: 1, overflow: .ellipsis),
      ),
    ),
    .videoCards => Padding(
      padding: .symmetric(horizontal: 10, vertical: 4),
      child: Center(
        child: SizedBox(
          width: 244,
          child: ValueListenableBuilder<int>(
            valueListenable: index,
            builder: (_, position, _) => buildBibiVideoCard(position, 0),
          ),
        ),
      ),
    ),
    .complex => _ObservationCard(index),
  };
}

/// 用同一组自然尺寸子项对照复用列表与原生 Sliver 列表。
class ElSliverRecyclerExamplePage extends HookWidget {
  /// 创建可切换容器与负载的千条列表。
  // ignore: prefer_const_constructors_in_immutables
  ElSliverRecyclerExamplePage({super.key, this.initialContent = .rectangles});

  /// 初次进入时显示的负载。
  final ElSliverRecyclerExampleContent initialContent;

  static const _itemCount = 1000;

  @override
  Widget build(BuildContext context) {
    final mode = useState(SliverExampleMode.initial);
    final content = useState(initialContent);
    final controller = useScrollController(keepScrollOffset: false);
    final workload = content.value;

    return ExamplePage(
      title: 'SliverRecycler 滚动对照',
      actions: [
        PopupMenuButton<Enum>(
          tooltip: '${mode.value.label} · ${workload.label}',
          onSelected: (selection) {
            if (selection == mode.value || selection == content.value) return;
            final active = controller;
            if (active.hasClients) active.jumpTo(0);
            switch (selection) {
              case final SliverExampleMode value:
                mode.value = value;
              case final ElSliverRecyclerExampleContent value:
                content.value = value;
            }
          },
          itemBuilder: (_) => [
            ...mode.value.menuItems(),
            PopupMenuDivider(),
            for (final option in ElSliverRecyclerExampleContent.values)
              CheckedPopupMenuItem(value: option, checked: option == workload, child: Text(option.label)),
          ],
        ),
      ],
      child: mode.value.scrollView(
        controller: controller,
        physics: ClampingScrollPhysics(),
        semanticChildCount: _itemCount,
        scrollCacheExtent: ScrollCacheExtent.pixels(250),
        slivers: [
          KeyedSubtree(
            key: ValueKey(workload),
            child: mode.value.list(
              context,
              itemCount: _itemCount,
              itemBuilder: (context, index) => workload.buildItem(context, AlwaysStoppedAnimation(index)),
              recycledItemBuilder: workload.buildItem,
            ),
          ),
        ],
      ),
    );
  }
}

final _rectangleColors = [Color(0xff81b8eb), Color(0xffb8dbcd), Color(0xfff9c589), Color(0xffd0b7ed)];

final _photoPaths = ['assets/recycler_cards/owl.jpg', 'assets/recycler_cards/owl-2.jpg'];
final _locations = ['松林北坡', '石桥溪谷', '湖畔步道', '城郊保护区'];

class _ObservationCard extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _ObservationCard(this.index);

  final ValueListenable<int> index;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final typography = Theme.of(context).textTheme;
    return Padding(
      padding: .symmetric(horizontal: 10, vertical: 4),
      child: Align(
        alignment: .topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 440),
          child: ExamplePanel(
            style: ElStyle(
              backgroundColor: colors.surface,
              borderRadius: .circular(16),
              border: .all(borderWidth: 1, borderColor: colors.outlineVariant),
            ),
            child: Padding(
              padding: .all(12),
              child: Column(
                crossAxisAlignment: .stretch,
                mainAxisSize: .min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.eco_outlined, color: colors.primary, size: 18),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text('自然观察手记', style: typography.labelLarge, maxLines: 1, overflow: .ellipsis),
                      ),
                      _ObservationTag('已核验', colors.tertiaryContainer, colors.onTertiaryContainer),
                    ],
                  ),
                  SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: .circular(10),
                    child: SizedBox(
                      height: 116,
                      child: ElListenableBuilder<ValueListenable<int>, String>(
                        listenable: index,
                        select: (source) => _photoPaths[source.value % _photoPaths.length],
                        builder: (_, _) => Image.asset(
                          _photoPaths[index.value % _photoPaths.length],
                          cacheWidth: 960,
                          fit: .cover,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: .start,
                    mainAxisSize: .min,
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: index,
                        builder: (_, position, _) => Text(
                          '${position.isEven ? '林缘的猫头鹰' : '树梢的夜行者'} · #${position + 1}',
                          style: typography.titleMedium,
                          maxLines: 1,
                          overflow: .ellipsis,
                        ),
                      ),
                      Text('暮色里记录到一次短暂的停栖，随后飞入林间。', style: typography.bodySmall, maxLines: 2, overflow: .ellipsis),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.place_outlined, size: 15, color: colors.primary),
                          SizedBox(width: 4),
                          Expanded(
                            child: ElListenableBuilder<ValueListenable<int>, String>(
                              listenable: index,
                              select: (source) => _locations[source.value % _locations.length],
                              builder: (_, _) => Text(
                                _locations[index.value % _locations.length],
                                style: typography.labelMedium,
                                maxLines: 1,
                                overflow: .ellipsis,
                              ),
                            ),
                          ),
                          Icon(Icons.schedule, size: 15, color: colors.onSurfaceVariant),
                          SizedBox(width: 4),
                          ElListenableBuilder<ValueListenable<int>, int>(
                            listenable: index,
                            select: (source) => source.value % 24,
                            builder: (_, _) =>
                                Text('${6 + index.value % 24} 分钟', style: typography.labelMedium, maxLines: 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text('鸟类 · 夜行观察', style: typography.labelMedium, maxLines: 1)),
                      ElButtonView(
                        onPressed: () {
                          final position = index.value;
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            SnackBar(
                              content: Text('记录 #${position + 1} · ${_locations[position % _locations.length]}'),
                            ),
                          );
                        },
                        style: ElStyle(
                          backgroundColor: colors.primaryContainer,
                          borderRadius: .circular(8),
                          padding: .symmetric(horizontal: 10, vertical: 6),
                        ),
                        child: Text('查看记录', style: typography.labelMedium?.copyWith(color: colors.onPrimaryContainer)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ObservationTag extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _ObservationTag(this.label, this.background, this.foreground);

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: background, borderRadius: .circular(20)),
    child: Padding(
      padding: .symmetric(horizontal: 8, vertical: 4),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground)),
    ),
  );
}
