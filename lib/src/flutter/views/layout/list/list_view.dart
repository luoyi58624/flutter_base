import 'package:flutter/widgets.dart';

import '../geometry/list_geometry.dart';
import '../layout_view.dart';

/// List 排列布局；全量挂载，虚拟列表使用 ElScroll 中的 Sliver。
class ElListView extends LayoutView {
  /// 创建全量布局，方向跟随所属滚动容器，独立使用时默认垂直。
  const ElListView({
    super.key,
    this.gap = 0,
    this.fixedSize = false,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    super.children,
  }) : assert(gap >= 0 && gap < double.infinity),
       assert(crossAxisAlignment != CrossAxisAlignment.baseline);

  /// 相邻条目的主轴间距。
  final double gap;

  /// 实测首条后固定所有条目主轴尺寸，直接计算最终范围。
  final bool fixedSize;

  /// 条目的交叉轴对齐方式。
  final CrossAxisAlignment crossAxisAlignment;

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
