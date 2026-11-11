# Row / Col

24 栅格，空间不足时换行。导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

```dart
ElView(
  breakpoint: ElBreakpoint(inheritSize: true),
  style: ElStyle(width: 600),
  child: ElRow(
    gutter: 16,
    justify: ElRowJustify.spaceBetween,
    align: ElRowAlign.middle,
    children: [
      ElCol(span: 8, xs: 24, md: 12, child: '左侧'),
      ElCol(span: 16, xs: 24, md: 12, child: '右侧'),
    ],
  ),
);
```

| 组件参数 | 说明 |
| --- | --- |
| Row.gutter | 列间距，通过列左右各一半 padding 实现 |
| Row.justify | start / end / center / spaceAround / spaceBetween / spaceEvenly |
| Row.align | top / middle / bottom |
| Row.style / semanticLabel | 容器样式与辅助名称 |
| Col.span | 默认 24，取 0～24；0 不渲染 |
| Col.offset | 左侧空出多少格，默认 0，取 0～24 |
| Col.xs / sm / md / lg / xl | 对应断点覆写 span |
| Col.style / child | 列外观与内容 |

断点为**上界语义**：默认 xs≤320、sm≤640、md≤1024、lg≤1920、xl≤2560，取已声明且命中的最小档；都未命中则用 span。上例 300 宽用 24，800 宽用 12，更宽用原 span。通过祖先 ElView 的 breakpoint 设置断点，尺寸基准由 ElBreakpoint.inheritSize 配置。

没有 push / pull 参数；任意比例分隔面板用 Splitter，等距格子用 Grid。
