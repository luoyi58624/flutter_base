# 列表、网格、瀑布流与导航头 Sliver

通过 `package:flutter_base/flutter_base.dart` 导入 `ElSliverList`、`ElSliverGrid`、`ElSliverMasonry`、`ElSliverCollapse`、`ElSliverLargeTitle`，放入 `ElScrollView.sliver` 或官方 `CustomScrollView.slivers`，可与其他 Sliver 混排。方向、反向、滚动物理和缓存范围由外层滚动容器配置，内边距使用 `SliverPadding`。

## 三种布局 × 三种生命周期

| 构造 | 子项生命周期 | 适用 |
| --- | --- | --- |
| 默认 `children` | 一次挂载全部，状态常驻；内容没有变化时滚动不调用任何 `child.layout` | 文档、设置页、需要跨段选择或 `ensureVisible` 的内容 |
| `.builder` | 只构建缓存窗口，离开后销毁；支持官方 KeepAlive 与 `findChildIndexCallback` | 一般长列表 |
| `.recycler` | 同类型子树换绑，保留 Element、State、RenderObject | 结构固定、滚动频繁的长列表 |
| List 的 `.separated` | 与 builder 相同 | 分隔符自然测量，末项后无分隔符，语义序号不计分隔符 |

所有构造都按内容自然测量，不要求 `itemExtent`。`addRepaintBoundaries`、`addSemanticIndexes` 默认开启；只有 builder、separated 提供 `addAutomaticKeepAlives`（子项提出请求时才保活）。

```dart
ElScrollView.sliver(
  slivers: [
    ElSliverList.builder(
      itemCount: records.length,
      spacing: 12,
      itemBuilder: (context, index) => Text(records[index].title),
    ),
  ],
);
```

### 列表

| 参数 | 行为 |
| --- | --- |
| `spacing` | 相邻条目的主轴间距，默认 0；`.separated` 由分隔符尺寸决定 |
| `center` | 自然尺寸较窄的条目沿交叉轴居中 |
| `stretch` | 撑满交叉轴；`children` 构造默认 false，其余默认 true |
| `controller` | 仅 `.recycler`：`ElSliverRecyclerController` 按序号定位、通知条目增删 |

`jumpToIndex` 不预先构建途经条目：下一次布局先实测目标，再用官方偏移修正一次移动视口。`notifyItemsInserted` / `notifyItemsRemoved` 让视口内首个条目的序号随之移动，正文不被插在上方的内容推走。

### 网格

列数四选一：

| 参数 | 列数 |
| --- | --- |
| `crossAxisCount` | 固定数量；横向滚动时为行数 |
| `itemWidth` | 预估格宽：`max(1, floor(可用宽度 / itemWidth))`，再扣除间距均分。可用宽度 400、itemWidth 150、列间距 10 时排 2 列、每格宽 195 |
| `minCrossAxisExtent` | 单格不小于该值的前提下排尽量多的列 |
| `maxCrossAxisExtent` | 单格不超过该值的前提下排尽量少的列 |

格的主轴尺寸：

| 参数 | 行为 |
| --- | --- |
| 都不指定 | 自然测量，每行以最高条目定行高 |
| `mainAxisExtent` | 固定主轴尺寸：纵向为格高，横向为格宽 |
| `aspectRatio` | 物理宽/高；未指定 `mainAxisExtent` 时由格宽推导格高 |

指定 `mainAxisExtent` 或 `aspectRatio` 后位置是纯算术：不测量条目、不保存逐项数据，远跳和追加分页都不产生滚动范围修正，能确定格尺寸时优先使用。横向滚动的 `itemWidth` 先按 `aspectRatio` 换算成格高，再按可用高度取行数。

间距使用 `mainAxisSpacing`、`crossAxisSpacing`；`gap` 同时设置两者，单独指定的方向优先。

```dart
ElSliverGrid.builder(
  itemCount: photos.length,
  itemWidth: 150,
  aspectRatio: 1,
  gap: 6,
  itemBuilder: (context, index) => Photo(photos[index]),
);
```

### 瀑布流

列数与间距参数同网格（没有固定格尺寸）。条目放入当前最短列；已显示的条目固定在原来的列，上方内容补测或变化时不左右跳动。远跳只推算前置列的几何，不创建前面的 Widget。

## 自然尺寸与锚点

- 未测条目使用同类型（`itemType`）首个实测值作估值，后续实测修正总长度。
- 缓存窗口内、视口上方的条目尺寸变化时，按视口内首个条目保持正文位置，通过 `scrollOffsetCorrection` 修正滚动偏移。`children` 构造没有这一锚定，总长度变化按官方机制重新协商范围。
- 条目数、轴向、交叉轴尺寸、类型序列或布局参数变化时重新测量；父级重建但这些都没变时保留实测尺寸和瀑布流的列分配。

## recycler 的接法

`itemBuilder` 只创建一次槽位的固定结构，换绑通过同一个 `ValueListenable<int>` 通知新序号：

```dart
ElSliverList.recycler(
  itemCount: records.length,
  itemBuilder: (context, index) => ValueListenableBuilder<int>(
    valueListenable: index,
    builder: (context, value, child) => Text(records[value].title),
  ),
);
```

- 动态区域放在监听范围内，固定内容放在外面或经 `child` 传入。不要把整张卡片放进 index 的监听，也不要用随记录变化的 Key 标识可复用卡片：前者仍会重建整棵业务树，后者直接卸载旧子树。
- 父级刷新配置时 index 也会通知，此时 `value` 可能不变但对应记录已变，监听方收到通知就重新读取记录。
- 事件回调在触发时读取 `index.value`；输入内容、展开状态和异步任务按业务记录保存。
- `itemType` 区分不能互换结构的类型；`maxRecycledItems` 限制所有类型合计的空闲槽位，不含当前缓存窗口。
- 把稳定的 `ValueListenable` 直接作为 `ElView.child`，纯文本换绑不经过 Widget 更新。

## 文件分工

依赖只有一个方向：`list/`、`grid/`、`masonry/` → `internal/`；`appbar/` 与其余部分互不引用。`internal/` 不从公共入口导出。

| 路径 | 职责 |
| --- | --- |
| `list/` | `ElSliverList`、`ElSliverRecyclerController`；`layout.dart` 是一维排列算法 |
| `grid/` | `ElSliverGrid`；`layout.dart` 含自然行高与固定格尺寸两种算法 |
| `masonry/` | `ElSliverMasonry`；`layout.dart` 是最短列放置算法 |
| `appbar/` | `ElSliverCollapse`、`ElSliverLargeTitle`，基于官方 Header |
| `internal/layout.dart` | `SliverLayout` 布局算法接口、`SliverLayoutSpec` 规格值对象、`SliverTracks` 列数解析 |
| `internal/extent_index.dart` | 实测尺寸、类型估值、前缀和与偏移反查 |
| `internal/render.dart` | `RenderNaturalSliver`：唯一的渲染器，统一布局循环、锚点、定位、绘制、命中、语义 |
| `internal/child_source.dart` | `SliverChildSource`：渲染器取子项的接口 |
| `internal/eager.dart` / `builder.dart` / `recycler.dart` | 三种生命周期各自的 Widget 基类与 Element |
| `internal/slots.dart` | builder 与 recycler 共用的槽位登记 |
| `internal/index_controller.dart` | 控制器通往渲染器的内部通道 |

布局算法只管几何，不认识 Element；子项来源只管子项怎么来、怎么走，不认识几何。新增一种布局只需实现 `SliverLayout`，三种生命周期自动可用。

测试位于 `test/flutter/slivers/`，示例业务回归位于 `example/test/sliver_*`、`example/test/scroll_*`，均为无头 Widget 测试。
