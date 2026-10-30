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
