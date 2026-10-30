# Layout

导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

| 容器 | 用途 |
| --- | --- |
| ElListView | 主轴顺序排列，可变高度或统一尺寸 |
| ElGridView | 固定列数或按格尺寸自适应排列 |
| ElStackView | 层叠、定位、zIndex 与溢出命中 |

List/Grid 普通构造可独立使用，全量挂载；`.builder` 必须直接放在 ElScrollView.children 中，由滚动宿主负责虚拟化。方向跟随宿主，独立使用默认纵向。

## List：间距、分隔与统一尺寸

```dart
ElListView(gap: 8, children: [Text('第一项'), Text('第二项')]);

SizedBox(
  height: 320,
  child: ElScrollView(children: [
    ElListView.builder(
      itemCount: 1000,
      fixedSize: true,
      itemBuilder: (_, i) => SizedBox(height: 48, child: Text('第 $i 项')),
      separatorBuilder: (_, i) => SizedBox(height: 1, child: ColoredBox(color: Colors.grey)),
    ),
  ]),
);
```

| 参数 | 说明 |
| --- | --- |
| gap | 条目间距，与 separatorBuilder 互斥 |
| fixedSize | 默认 false；true 时分别实测首个正文、首个分隔项，再复用尺寸，适合等高条目 |
| crossAxisAlignment | 默认 stretch；baseline 不支持 |
| separatorBuilder | 业务条目之间构建分隔项，不构建尾部分隔项 |
| keepAlive | builder 默认 false；true 保留已访问条目 State，内存随访问增长 |
| findChildIndexCallback | 重排时由稳定 Key 查回新的业务索引 |

## Grid：列数与自适应尺寸

```dart
ElGridView(
  crossAxisCount: 3,
  mainAxisExtent: 80,
  rowGap: 8,
  columnGap: 12,
  children: [Text('A'), Text('B'), Text('C')],
);

SizedBox(
  height: 320,
  child: ElScrollView(children: [
    ElGridView.builder(
      itemCount: 1000,
      minCrossAxisExtent: 120,
      aspectRatio: 1.5,
      gap: 12,
      itemBuilder: (_, i) => Text('卡片 $i'),
    ),
  ]),
);
```

`crossAxisCount / minCrossAxisExtent / maxCrossAxisExtent` 三选一。crossAxisCount 在纵向为列数、横向为行数；mainAxisExtent 在纵向为格高、横向为格宽。未设主轴尺寸时由物理宽高比 aspectRatio 推导。gap 与 rowGap / columnGap 互斥，后两者始终是物理纵/横间距。

builder 支持 keepAlive 和 findChildIndexCallback，语义与 List 相同。重排时两边一起提供：

```dart
final ids = ['a', 'b', 'c'];
SizedBox(
  height: 240,
  child: ElScrollView(children: [ElListView.builder(
    itemCount: ids.length,
    itemBuilder: (_, i) => Text(ids[i], key: ValueKey(ids[i])),
    findChildIndexCallback: (key) {
      if (key is! ValueKey<String>) return null;
      final index = ids.indexOf(key.value);
      return index < 0 ? null : index;
    },
  )]),
);
```

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
