part of 'index.dart';

class MyListGroup extends StatelessWidget {
  const MyListGroup({super.key, required this.children, this.title});

  final Widget? title;
  final List<MyListTile> children;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ElView(
        style: .new(bgColor: Colors.white, borderRadius: .circular(16), clipBehavior: .hardEdge),
        child: Column(
          children: children.mapIndexed((i, e) => ElChildIndex(index: i, end: children.length - 1, child: e)).toList(),
        ),
      ),
    );
  }
}

/// 列表组标题和行集合的公共声明。
class ElListTileGroup extends StatelessWidget {
  /// 创建列表组配置，不生成卡片或分隔线。
  const ElListTileGroup({
    super.key,
    this.title,
    required this.children,
    this.style,
  });

  /// 分组标题，接受文本或 Widget。
  final Object? title;

  /// 组内列表行。
  final List<ElListTile> children;

  /// 分组容器样式。
  final ElStyle? style;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).listTileGroupBuilder!(context, this);
}
