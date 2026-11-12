# 列表、网格与瀑布流

通过 `package:flutter_base/flutter_base.dart` 导入 `ElSliverList`、`ElSliverGrid`、`ElSliverMasonry`，放入 `ElScrollView.sliver` 或官方 `CustomScrollView.slivers`。

| 构造 | 子项生命周期 | 尺寸与滚动 |
| --- | --- | --- |
| 默认 `children` | 一次挂载全部，状态常驻 | 全量自然排版并缓存位置；普通滚动不重新布局全部子项，仅绘制可见内容 |
| `.builder` | 缓存窗口内创建，离开后销毁；支持官方 KeepAlive | 与 recycler 共用自然尺寸索引，列表远跳直接测量目标窗口 |
| `.recycler` | 同类型槽位换绑，保留 Element、State、RenderObject | 保留现有活索引与复用池，不使用 KeepAlive |
| List 的 `.separated` | 与 builder 相同 | 分隔符自然测量，末项后无分隔符，业务语义序号不计分隔符 |

`ElSliverList` 前三个构造提供 `spacing`，默认 0；`.separated` 只使用 `separatorBuilder` 的实际尺寸。网格、瀑布流使用 `mainAxisSpacing`、`crossAxisSpacing`，默认均为 0。普通网格以每行最高子项确定行高，瀑布流沿最短列自然排列。

所有构造提供默认开启的 `addRepaintBoundaries`、`addSemanticIndexes`。只有 builder、separated 提供 `addAutomaticKeepAlives`，默认 true：仅在子项提出保活请求时保留它，不是保留所有已访问条目。children 始终常驻，recycler 自己管理复用池，不提供自动保活开关。

```dart
ElScrollView.sliver(
  scrollCacheExtent: const ScrollCacheExtent.pixels(250),
  slivers: [
    ElSliverList.builder(
      itemCount: records.length,
      spacing: 12,
      addAutomaticKeepAlives: false,
      itemBuilder: (context, index) => Text(records[index].title),
    ),
  ],
);
```

builder 直接使用官方 `SliverChildBuilderDelegate` 的包装和 Key 规则，不创建 recycler 的 Focus、TickerMode、HeroMode、复用动画包装。`findChildIndexCallback` 用于记录重排；separated 的 `findItemIndexCallback` 返回业务条目序号。

自然尺寸布局的未测范围使用估值；后续实测会修正总长度和可见锚点。瀑布流远跳需要推算前置列几何，但不创建前置 Widget。具体复用接法见 [recycler/README.md](recycler/README.md)，常驻文档与跨段选择见 [list/README.md](list/README.md)。

示例的合成列表和长文数据为 1000 条，本机媒体及 Bibi 卡片来源使用实际数量。1000 是示例规模，不是组件限制。无头测试只能检查工作量与同环境耗时，设备帧率须用目标设备的 profile/release 测量。
