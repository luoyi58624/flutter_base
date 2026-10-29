import 'package:flutter/widgets.dart';
import '../geometry/list_geometry.dart';
import '../layout_view.dart';

/// List 排列布局；普通构造全量挂载，builder 仅能直接接入 ElScrollView。
class ElListView extends LayoutView {
  /// 创建全量布局，方向跟随所属滚动容器，独立使用时默认垂直。
  const ElListView({
    super.key,
    this.gap = 0,
    this.fixedSize = false,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    List<Widget> this.children = const <Widget>[],
  }) : itemCount = null,
       keepAlive = false,
       itemBuilder = null,
       findChildIndexCallback = null,
       separatorBuilder = null,
       assert(gap >= 0 && gap < double.infinity),
       assert(crossAxisAlignment != CrossAxisAlignment.baseline);

  /// 创建虚拟布局，上级必须为 ElScrollView 的直接内容槽。
  const ElListView.builder({
    super.key,
    required int this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    this.keepAlive = false,
    this.findChildIndexCallback,
    this.separatorBuilder,
    this.gap = 0,
    this.fixedSize = false,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  }) : children = null,
       assert(itemCount >= 0),
       assert(separatorBuilder == null || gap == 0, 'gap 与 separatorBuilder 只能设置一个。'),
       assert(gap >= 0 && gap < double.infinity),
       assert(crossAxisAlignment != CrossAxisAlignment.baseline);

  /// 相邻条目的主轴间距，与 separatorBuilder 互斥。
  final double gap;

  /// 首条正文与首个分隔项分别实测后固定各自尺寸，直接计算最终范围。
  final bool fixedSize;

  /// 条目的交叉轴对齐方式。
  final CrossAxisAlignment crossAxisAlignment;

  /// 构建相邻业务条目之间的分隔项，尾部不构建。
  final IndexedWidgetBuilder? separatorBuilder;
  @override
  IndexedWidgetBuilder? get layoutSeparatorBuilder => separatorBuilder;

  /// 普通构造的全部条目，builder 模式为 null。
  final List<Widget>? children;

  /// builder 的业务条目数量，不包含分隔项。
  final int? itemCount;

  /// 按业务索引构建条目。
  final IndexedWidgetBuilder? itemBuilder;

  /// 根据业务 key 返回重排后的业务索引。
  final ChildIndexGetter? findChildIndexCallback;

  /// 保留已构建条目及分隔项的状态，默认关闭；不会提前构建未访问条目。
  final bool keepAlive;
  @override
  bool get layoutKeepAlive => keepAlive;
  @override
  List<Widget>? get layoutChildren => children;
  @override
  int get layoutItemCount => children?.length ?? itemCount!;
  @override
  IndexedWidgetBuilder? get layoutItemBuilder => itemBuilder;
  @override
  ChildIndexGetter? get layoutFindChildIndex => findChildIndexCallback;
  @override
  ListLayoutGeometry get listGeometry =>
      ListLayoutGeometry(gap: gap, fixedSize: fixedSize, crossAxisAlignment: crossAxisAlignment);
  @override
  ElRenderListView createRenderObject(BuildContext context) {
    final render = ElRenderListView();
    configureRenderObject(context, render);
    return render;
  }
}

/// List 条目的布局偏移。
class ElListParentData extends LayoutParentData {}

/// 使用共享 List 算法的渲染宿主。
class ElRenderListView extends RenderLayoutView {
  @override
  LayoutParentData createParentData() => ElListParentData();
}
