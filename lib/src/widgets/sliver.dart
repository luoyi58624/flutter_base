part of flutter_base;

class CustomSliverPersistentHeaderDelegate extends SliverPersistentHeaderDelegate {
  CustomSliverPersistentHeaderDelegate({
    required this.maxHeight,
    this.minHeight = 0,
    required Widget child,
  })  : builder = ((a, b, c) => child),
        assert(minHeight <= maxHeight && minHeight >= 0);

  //最大和最小高度相同
  CustomSliverPersistentHeaderDelegate.fixedHeight({
    required double height,
    required Widget child,
  })  : builder = ((a, b, c) => child),
        maxHeight = height,
        minHeight = height;

  //需要自定义builder时使用
  CustomSliverPersistentHeaderDelegate.builder({
    required this.maxHeight,
    this.minHeight = 0,
    required this.builder,
  });

  final double maxHeight;
  final double minHeight;
  final Widget Function(BuildContext context, double shrinkOffset, bool overlapsContent) builder;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    Widget child = builder(context, shrinkOffset, overlapsContent);
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(CustomSliverPersistentHeaderDelegate oldDelegate) {
    if (maxHeight == minHeight) {
      return true;
    } else {
      return oldDelegate.maxExtent != maxExtent || oldDelegate.minExtent != minExtent;
    }
  }
}
