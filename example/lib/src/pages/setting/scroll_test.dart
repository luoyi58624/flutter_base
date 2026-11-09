import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_base/desktop.dart';

/// 用 ElSliverRecyclerList 滚动一列可复用的 ElView。
class ScrollTestPage extends HookWidget {
  /// 创建纵向回收列表。
  ScrollTestPage({super.key});

  static const _itemCount = 1000;
  static const _cacheExtent = 250.0;

  @override
  Widget build(BuildContext context) {
    final controller = useScrollController(keepScrollOffset: false);
    return Scaffold(
      backgroundColor: context.elTheme.fill,
      appBar: AppBar(title: Text('滚动测试')),
      body: CustomScrollView(
        controller: controller,
        physics: ClampingScrollPhysics(),
        scrollCacheExtent: ScrollCacheExtent.pixels(_cacheExtent),
        semanticChildCount: _itemCount,
        slivers: [
          SliverPadding(
            padding: .all(16),
            sliver: ElSliverRecyclerList(itemCount: _itemCount, itemBuilder: (context, index) => _Child(index)),
          ),
        ],
      ),
    );
  }
}

class _Child extends StatelessWidget {
  _Child(this.index);

  /// 槽位序号。滚动换绑时由列表通知，ElView 直接订阅并更新文本。
  final ValueListenable<int> index;

  @override
  Widget build(BuildContext context) {
    return ElView(
      style: ElStyle(
        width: 200,
        height: 50,
        fontSize: 16,
        margin: .only(bottom: 8),
        backgroundColor: Colors.grey,
        onTap: ElStyle(fontSize: 20),
      ),
      child: index,
    );
  }
}
