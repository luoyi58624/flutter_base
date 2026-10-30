import 'package:flutter/widgets.dart';
import '../../layout/layout_view.dart';
import 'segment_spec.dart';

/// 是否包含需要统一调度的布局 View。
bool hasVirtualSegmentDeclaration(List<Widget> children) => children.any((child) => child is LayoutView);

/// 普通 Widget 保持完整成员；List/Grid View 展开为对应的布局段。
List<SegmentSpec> resolveScrollSegments(List<Widget> children, {required Axis scrollAxis}) => [
  for (final child in children)
    if (child is LayoutView)
      _resolveLayout(child, scrollAxis)
    else if (child is SliverMultiBoxAdaptorWidget)
      throw FlutterError('ElScrollView 不接受 Sliver，请使用 ElListView 或 ElGridView。')
    else
      StaticSegment(child),
];

SegmentSpec _resolveLayout(LayoutView view, Axis axis) {
  final children = view.layoutChildren;
  final separator = view.layoutSeparatorBuilder;
  final count = view.layoutItemCount;
  final findIndex = view.layoutFindChildIndex;
  final source = children != null
      ? MaterializedItemSource(children)
      : BuilderItemSource(
          itemCount: separator == null || count == 0 ? count : count * 2 - 1,
          builder: separator == null
              ? view.layoutItemBuilder!
              : (context, index) =>
                    index.isEven ? view.layoutItemBuilder!(context, index ~/ 2) : separator(context, index ~/ 2),
          findChildIndex: separator == null || findIndex == null
              ? findIndex
              : (key) {
                  final index = findIndex(key);
                  return index == null ? null : index * 2;
                },
        );
  final grid = view.gridGeometry;
  if (grid != null) {
    return GridSegment(source: source, geometry: grid, axis: axis, view: view, resident: !view.isBuilder);
  }
  final list = view.listGeometry!;
  return LinearSegment(
    source: source,
    geometry: list,
    key: view.key,
    view: view,
    resident: !view.isBuilder,
    fixed: list.fixedSize ? FixedSizeSpec(itemStride: separator == null ? 1 : 2) : null,
  );
}
