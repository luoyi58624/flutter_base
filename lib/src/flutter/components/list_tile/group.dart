part of 'index.dart';

class MyListGroup extends StatelessWidget {
  const MyListGroup({super.key, required this.children, this.title});

  final Widget? title;
  final List<MyListTile> children;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ElView(
        style: .new(backgroundColor: Colors.white, borderRadius: .circular(16), clipBehavior: .hardEdge),
        child: Column(
          children: children.mapIndexed((i, e) => ElChildIndex(index: i, end: children.length - 1, child: e)).toList(),
        ),
      ),
    );
  }
}

/// 列表组标题、说明和内容集合的公共声明，不管理组内选择状态。
class ElListTileGroup extends StatelessWidget {
  /// 创建列表组配置，不生成卡片或分隔线。
  const ElListTileGroup({
    super.key,
    this.title,
    this.description,
    required this.children,
    this.style,
    this.semanticLabel,
  });

  /// 分组标题，接受文本或 Widget。
  final Object? title;

  /// 分组说明，接受文本或 Widget。
  final Object? description;

  /// 组内内容，允许列表行与自定义 Widget 混排。
  final List<Widget> children;

  /// 分组容器样式。
  final ElStyle? style;

  /// 没有可见标题时提供分组的辅助名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => ElComponentProvider.of(context).listTileGroupBuilder!(context, this);
}
