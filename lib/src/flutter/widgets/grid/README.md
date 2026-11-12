# ElGrid

Grid 与 Stack 的组件入口分别位于 `widgets/grid/index.dart` 和 `widgets/stack/index.dart`。

导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

| 容器 | 用途 |
| --- | --- |
| ElGrid | 固定列数或按格尺寸自适应排列 |

ElGrid 全量挂载，方向跟随最近的 Scrollable，独立使用默认纵向。大量条目的虚拟列表与网格使用 `ElScrollView.sliver` 配合 `ElSliverList`、`ElSliverRecyclerList`、`ElSliverRecyclerGrid` 或官方 Sliver。

## Grid：列数与自适应尺寸

```dart
ElGrid(
  crossAxisCount: 3,
  mainAxisExtent: 80,
  rowGap: 8,
  columnGap: 12,
  children: [Text('A'), Text('B'), Text('C')],
);
```

itemWidth 是预估物理格宽：纵向按 `max(1, floor(可用宽度 / itemWidth))` 取列数，再扣除列间距并均分剩余宽度。例如可用宽度 400、itemWidth 为 150 时排 2 列；columnGap 为 10 时每格宽 195。横向先按 `itemWidth / aspectRatio` 换算预估格高，再按可用高度取行数。独立布局的交叉轴无界且未指定固定数量时，按预估尺寸排成一带。

crossAxisCount 优先于 itemWidth，在纵向为列数、横向为行数；itemWidth 与 minCrossAxisExtent / maxCrossAxisExtent 互斥。原有 `crossAxisCount / minCrossAxisExtent / maxCrossAxisExtent` 三选一规则不变。mainAxisExtent 在纵向为格高、横向为格宽，优先于 aspectRatio 推导的主轴尺寸。gap 与 rowGap / columnGap 互斥，后两者始终是物理纵/横间距。

轨道数、单格尺寸与完整范围通过常数次计算得到，无需预先测量条目。

