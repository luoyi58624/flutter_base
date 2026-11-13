import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ViewportOffset;
import 'package:flutter_base/flutter_base.dart';

import 'feed.dart';

const _smallCardsPerBatch = 6;
const _initialBatches = 2;
const _loadDelay = Duration(milliseconds: 100);

/// 记录各频道共用的本地推荐批次，刷新时废弃仍在等待的追加。
class BibiCardPages extends ChangeNotifier {
  int _count = _initialBatches;
  Timer? _load;

  /// 已经加载的批次数。
  int get count => _count;

  /// 是否正在等待下一批。
  bool get isLoading => _load != null;

  /// 到达末尾时追加一批，合并同一批次的重复触底通知。
  void loadMore() {
    if (isLoading) return;
    _load = Timer(_loadDelay, () {
      _load = null;
      _count++;
      notifyListeners();
    });
    notifyListeners();
  }

  /// 清除待追加批次并恢复初始两批。
  void reset() {
    _load?.cancel();
    _load = null;
    _count = _initialBatches;
    notifyListeners();
  }

  /// 刷新开始时取消待追加的旧数据。
  void cancelLoad() {
    if (!isLoading) return;
    _load!.cancel();
    _load = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _load?.cancel();
    super.dispose();
  }
}

/// 每批复用一个通栏轮播槽和一个包含六张视频卡片的双列网格槽。
class BibiCards extends StatelessWidget {
  /// 构建指定刷新代次的分页推荐流。
  const BibiCards({required this.pages, required this.generation});

  final BibiCardPages pages;
  final int generation;

  @override
  Widget build(BuildContext context) => ElListenableBuilder(
    listenable: pages,
    select: (pages) => pages.count,
    builder: (context, _) => ElSliverList.recycler(
      key: ValueKey('bibi-cards-$generation'),
      stretch: true,
      itemCount: pages.count * 2,
      itemType: (index) => index.isEven,
      itemBuilder: (context, index) => ValueListenableBuilder<int>(
        valueListenable: index,
        builder: (context, index, _) {
          final batch = index ~/ 2;
          if (index.isEven) {
            return buildBibiBanner(
              context,
              generation + batch,
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
                      buildBibiVideoCard(batch * _smallCardsPerBatch + i, generation, aspectRatio: 5 / 4),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
