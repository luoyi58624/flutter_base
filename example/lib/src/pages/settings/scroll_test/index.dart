import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_base/desktop.dart';

/// 用同一列 ElView 对照 ElSliverList 与官方 SliverList。
class ScrollTestPage extends HookWidget {
  /// 创建可切换官方列表的纵向滚动页。
  ScrollTestPage({super.key});

  static const _itemCount = 1000;
  static const _cacheExtent = 250.0;

  @override
  Widget build(BuildContext context) {
    final official = useState(false);
    final controller = useScrollController(keepScrollOffset: false);
    return Scaffold(
      backgroundColor: context.elTheme.fill,
      appBar: AppBar(
        title: Text('滚动测试'),
        actions: [
          Row(
            mainAxisSize: .min,
            children: [
              Text('SliverList'),
              Switch(
                key: ValueKey('scroll-test-official-switch'),
                value: official.value,
                onChanged: (value) {
                  if (controller.hasClients) controller.jumpTo(0);
                  official.value = value;
                },
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        controller: controller,
        physics: ClampingScrollPhysics(),
        scrollCacheExtent: ScrollCacheExtent.pixels(_cacheExtent),
        semanticChildCount: _itemCount,
        slivers: [
          SliverPadding(
            padding: .all(16),
            sliver: official.value
                ? SliverList.builder(
                    itemCount: _itemCount,
                    addAutomaticKeepAlives: false,
                    itemBuilder: (context, index) => _Child(index),
                  )
                : ElSliverList.recycler(itemCount: _itemCount, itemBuilder: (context, index) => _Child(index)),
          ),
        ],
      ),
    );
  }
}

class _Child extends StatelessWidget {
  _Child(this.index);

  /// 回收列表传入序号监听；SliverList 传入整数。
  final Object index;

  @override
  Widget build(BuildContext context) {
    final source = index;
    final label = source is ValueListenable<int> ? source.value : source;
    ElLog.i('build - $label');
    return RepaintBoundary(
      child: ElView(
        style: ElStyle(
          width: 200,
          fontSize: 16,
          padding: .all(8),
          margin: .only(bottom: 8),
          backgroundColor: Colors.grey,
          alignment: .center,
        ),
        child: ExcludeSemantics(
          child: Column(
            spacing: 8,
            children: [
              ElView(child: index),
              SingleChildScrollView(
                scrollDirection: .horizontal,
                child: Row(
                  spacing: 8,
                  children: [...ElevatedButton(onPressed: () {}, child: Text('hello')) * 10],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
