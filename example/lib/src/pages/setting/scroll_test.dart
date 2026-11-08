import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_base/desktop.dart';

enum _ScrollMode {
  fixed('SliverFixedExtentList'),
  recycler('ElSliverRecycler'),
  eager('非虚拟滚动'),
  el('ElScrollView');

  const _ScrollMode(this.label);

  final String label;
}

/// 使用固定 ElView 实例，对照四种滚动容器的性能。
class ScrollTestPage extends HookWidget {
  /// 创建固定子项的滚动对照页。
  const ScrollTestPage({super.key});

  static const _itemCount = 1000;
  static const _itemGap = 8.0;
  static const _cacheExtent = 250.0;

  @override
  Widget build(BuildContext context) {
    final mode = useState(_ScrollMode.fixed);
    final controller = useScrollController(keepScrollOffset: false);
    final elController = useScrollController(keepScrollOffset: false);
    final physics = ClampingScrollPhysics();

    final scrollView = switch (mode.value) {
      .eager => SingleChildScrollView(
        controller: controller,
        physics: physics,
        padding: .all(16),
        child: RepaintBoundary(
          child: Column(crossAxisAlignment: .stretch, children: List<Widget>.generate(_itemCount, (index) => _Child())),
        ),
      ),
      .el => ElScrollView(
        controller: elController,
        physics: physics,
        smoothScroll: null,
        cacheExtent: _cacheExtent,
        padding: .all(16),
        children: [
          ElListView.builder(itemCount: _itemCount, fixedSize: true, keepAlive: false, itemBuilder: (_, _) => _Child()),
        ],
      ),
      .fixed || .recycler => CustomScrollView(
        controller: controller,
        physics: physics,
        scrollCacheExtent: ScrollCacheExtent.pixels(_cacheExtent),
        semanticChildCount: _itemCount,
        slivers: [
          SliverPadding(
            padding: .all(16),
            sliver: mode.value == _ScrollMode.recycler
                ? ElSliverRecycler(itemCount: _itemCount, itemBuilder: (_, _) => _Child())
                : SliverFixedExtentList(
                    delegate: SliverChildBuilderDelegate(
                      (_, _) => _Child(),
                      childCount: _itemCount,
                      addAutomaticKeepAlives: false,
                    ),
                  ),
          ),
        ],
      ),
    };

    return Scaffold(
      backgroundColor: context.elTheme.fill,
      appBar: AppBar(title: Text('滚动测试 · 固定 ElView')),
      body: Column(
        children: [
          Padding(
            padding: .symmetric(horizontal: 16, vertical: 8),
            child: DropdownButton<_ScrollMode>(
              value: mode.value,
              isExpanded: true,
              items: [
                for (final option in _ScrollMode.values)
                  DropdownMenuItem(
                    value: option,
                    child: Text('${option.label} · $_itemCount 项', maxLines: 1, overflow: .ellipsis),
                  ),
              ],
              onChanged: (value) {
                if (value == null || value == mode.value) return;
                final activeController = mode.value == _ScrollMode.el ? elController : controller;
                if (activeController.hasClients) activeController.jumpTo(0);
                mode.value = value;
              },
            ),
          ),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(mode.value),
              child: RepaintBoundary(child: scrollView),
            ),
          ),
        ],
      ),
    );
  }
}

class _Child extends StatefulWidget {
  const _Child();

  @override
  State<_Child> createState() => _ChildState();
}

class _ChildState extends State<_Child> {
  @override
  void dispose() {
    super.dispose();
    ElLog.e('dispose');
  }

  @override
  Widget build(BuildContext context) {
    return ElView(
      style: .new(width: 200, height: 50, margin: .only(bottom: 8), backgroundColor: Colors.grey),
    );
  }
}
