import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_base/desktop.dart';

part 'official_card.dart';
part 'recycler_card.dart';

/// 对照官方滚动和 ElScrollView 回收列表的店铺示例。
class ElScrollPage extends HookWidget {
  /// 创建可切换滚动实现的测试页。
  const ElScrollPage({super.key});

  static const _itemCount = 1000;
  static const _cacheExtent = ScrollCacheExtent.viewport(2.0);

  @override
  Widget build(BuildContext context) {
    final official = useState(true);
    return Scaffold(
      appBar: AppBar(
        title: Text('ElScrollView 测试'),
        actions: [
          Row(
            mainAxisSize: .min,
            children: [
              Text('官方滚动'),
              Switch(value: official.value, onChanged: (value) => official.value = value),
            ],
          ),
        ],
      ),
      body: official.value
          ? CustomScrollView(
              scrollCacheExtent: _cacheExtent,
              slivers: [
                SliverPadding(
                  padding: .all(8),
                  sliver: SliverList.builder(
                    itemCount: _itemCount,
                    itemBuilder: (context, index) => _OfficialShopCard(index),
                  ),
                ),
              ],
            )
          : ElScrollView.sliver(
              scrollCacheExtent: _cacheExtent,
              slivers: [
                ElSliverRefresh(onRefresh: () async {}),
                SliverPadding(
                  padding: .all(8),
                  sliver: ElSliverRecyclerList(
                    itemCount: _itemCount,
                    itemBuilder: (context, index) => _RecyclerShopCard(index),
                  ),
                ),
              ],
            ),
    );
  }
}
