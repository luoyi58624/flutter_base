# Layout

导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

| 容器 | 用途 |
| --- | --- |
| ElListView | 主轴顺序排列，可变高度或统一尺寸 |
| ElGridView | 固定列数或按格尺寸自适应排列 |
| ElStackView | 层叠、定位、zIndex 与溢出命中 |

List/Grid 全量挂载，方向跟随最近的 Scrollable，独立使用默认纵向。大量条目的虚拟列表与网格使用 `ElScroll.sliver` 配合 `ElSliverList`、`ElSliverRecyclerList`、`ElSliverRecyclerGrid` 或官方 Sliver。

## List：间距与统一尺寸

```dart
ElListView(gap: 8, children: [Text('第一项'), Text('第二项')]);

ElListView(fixedSize: true, children: [for (final item in items) SizedBox(height: 48, child: Text(item))]);
```

| 参数 | 说明 |
| --- | --- |
| gap | 条目间距 |
| fixedSize | 默认 false；true 时实测首条后复用尺寸，适合等高条目 |
| crossAxisAlignment | 默认 stretch；baseline 不支持 |

## Grid：列数与自适应尺寸

```dart
ElGridView(
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

## Stack：自然占位与绝对定位

```dart
SizedBox(
  width: 240, height: 160,
  child: ElStackView(children: [
    ElStackItem(zIndex: 1, offset: Offset(0, 4), child: Text('保留自然槽位')),
    ElPositioned(top: 8, right: '10%', zIndex: 2, child: Text('定位角标')),
  ]),
);
```

- ElStackItem 的 offset 改变呈现位置，不改变兄弟布局；只调层级也可用它。
- ElPositioned 接受数字、百分比和 ElDimension；水平 left/right/width、垂直 top/bottom/height 各最多设两个。`.fill` 四边贴 0。
- 同层 zIndex 越大越靠前；负值保留布局但隐藏呈现及语义。
- alignment 定义非定位子和缺边定位子的对齐，fit 使用官方 StackFit。
- 默认 `clipBehavior: Clip.none`，支持溢出命中；改为裁剪会截断溢出绘制和命中。
- ElStackView 可接官方 Positioned；ElPositioned 不能放进官方 Stack。
