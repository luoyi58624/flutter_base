# 全量常驻的文档 Sliver

本文说明 `ElSliverList(children: ...)`。同一个公开组件还提供 `.builder`、`.recycler`、`.separated`，三种生命周期的区别和包装开关见 [上级说明](../README.md)。

`ElSliverList` 将所有子项一次挂载并自然排版，缓存每项的起止位置；普通滚动使用缓存更新坐标，通过二分查找处理可见内容。思路参考旧示例的 `MyScrollView`，现在接入官方 Sliver 协议，可以与标题、页脚、Recycler 列表和网格放在同一个 `CustomScrollView` 中。

## 使用

通过 `package:flutter_base/flutter_base.dart` 导入；`SelectionArea` 来自 Flutter Material 库。

```dart
SelectionArea(
  child: CustomScrollView(
    slivers: [
      SliverToBoxAdapter(child: Text('文档标题')),
      SliverPadding(
        padding: .all(16),
        sliver: ElSliverList(
          spacing: 16,
          children: [
            for (final paragraph in paragraphs)
              ElView(
                style: ElStyle(fontSize: 16),
                child: paragraph,
              ),
          ],
        ),
      ),
      SliverToBoxAdapter(child: Text('文档结束')),
    ],
  ),
);
```

`paragraphs` 是应用的段落内容。每个段落或卡片应作为独立 child，才能跳过屏外段落的绘制；一整个大 Column 作为单项时，只能按该 Column 的整体边界裁剪。

## API

| 参数 | 行为 |
| --- | --- |
| children | 按文档顺序排列的全部 Widget；元素与状态常驻，正常增删和 key 规则仍生效 |
| spacing | 相邻条目的主轴间距，默认 0，末项后无间隔 |
| center | 将自然尺寸较小的条目沿交叉轴居中，默认按交叉轴起点排列 |
| stretch | 让条目撑满交叉轴，默认保留自然尺寸；开启后 center 不再产生效果 |

方向、reverse、控制器、滚动物理、键盘收起行为和窗口裁剪沿用外层 `CustomScrollView`；内边距使用 `SliverPadding`。纵向只限制子项最大宽度，横向只限制最大高度，主轴尺寸由内容决定。

## 排版与滚动

- 首次挂载、子项增删或重排、自然尺寸变化、主轴方向或可用交叉轴尺寸变化，会更新文档几何。
- 普通滚动仍由官方 Viewport 调用 Sliver 的布局入口，入口只计算滚动几何，复用内容排版；不会遍历全部子项或调用每个 child.layout。
- 绘制、命中和语义分别根据当前窗口查询范围，不依赖上一次绘制留下的可见索引。
- 离屏子项保留真实坐标变换与滚动偏移，支持官方 `Scrollable.ensureVisible`。默认示例使用官方 `SelectionArea` 选择跨段落内容。
- 子项变化导致总长度改变时，外层滚动位置按官方机制重新协商范围。这里没有额外的滚动锚定协议。

全量常驻的首次构建、排版和内存占用随子项数量增长。需要随滚动回收业务子树的长列表使用 `ElSliverRecyclerList` / `ElSliverRecyclerGrid`；这三个入口可以混排。

## 验证与示例

组件测试位于 `test/flutter/slivers/sliver_list_test.dart`，包含全量挂载、滚动期间的构建/布局计数、可见绘制、尺寸变化、增删重排、坐标与命中、离屏定位及官方文本选择。

首页提供“文档滚动（全量常驻）”入口，示例包含 80 个自然高度段落，可以切换阅读宽度、展开或收起段落，并选择文字。对应交互测试位于 `example/test/sliver_list_example_test.dart`。验证使用无头 Widget 测试。
