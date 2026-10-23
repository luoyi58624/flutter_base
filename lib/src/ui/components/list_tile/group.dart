part of 'index.dart';

class MyListGroup extends StatelessWidget {
  const MyListGroup({super.key, required this.children});

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
