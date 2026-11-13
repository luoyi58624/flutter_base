import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ViewportOffset;
import 'package:flutter_base/flutter_base.dart';

import 'feed.dart';

const _smallCardsPerBatch = 6;

/// 每批复用一个通栏轮播槽和一个包含六张视频卡片的双列网格槽。
class BibiCards extends StatelessWidget {
  /// 构建指定刷新代次的分页推荐流。
  const BibiCards({required this.count, required this.generation, required this.seed});

  final int count;
  final int generation;
  final int seed;

  @override
  Widget build(BuildContext context) => ElSliverList.recycler(
    key: ValueKey('bibi-cards-$generation'),
    stretch: true,
    itemCount: count * 2,
    itemType: (index) => index.isEven,
    itemBuilder: (context, index) => ValueListenableBuilder<int>(
      valueListenable: index,
      builder: (context, index, _) {
        final batch = index ~/ 2;
        if (index.isEven) {
          return buildBibiBanner(
            context,
            seed + batch,
            key: ValueKey('bibi-banner-$batch'),
            aspectRatio: 5 / 3,
            maxHeight: 230,
          );
        }
        return Padding(
          padding: .fromLTRB(8, 4, 8, 5),
          // 网格只测量当前槽位的六张卡片，滚动位置由外层列表管理。
          child: ShrinkWrappingViewport(
            offset: ViewportOffset.zero(),
            slivers: [
              ElSliverGrid(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 9,
                children: [
                  for (var i = 0; i < _smallCardsPerBatch; i++)
                    buildBibiVideoCard(batch * _smallCardsPerBatch + i, seed, aspectRatio: 5 / 4),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}
