# Splitter

相邻面板按占比分配空间，拖动分隔条调整尺寸。导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

```dart
SizedBox(
  width: 600, height: 240,
  child: ElSplitterView(direction: Axis.horizontal, barSize: 6,
    onResize: (sizes) => debugPrint('最新占比：$sizes'),
    panels: [
    ElSplitterPanel(size: 0.3, min: 0.2, max: 0.6, child: Text('侧栏')),
    ElSplitterPanel(child: Text('正文')),
  ]),
);
```

| API | 默认与含义 |
| --- | --- |
| ElSplitterPanel.size | 初始占比，未指定的面板分配剩余空间 |
| min / max | 最小、最大占比，默认 0 / 1 |
| resizable | 默认 true；false 禁止该面板参与拖动调整 |
| direction | 默认 horizontal；vertical 为上下分割 |
| barSize / barStyle | 分隔条尺寸和样式 |
| style / semanticLabel | 容器外观、辅助名称 |
| onResize | 拖动后的占比列表，顺序对应 panels，可保存到业务配置 |

size / min / max 均为 0～1 的占比，不是像素。父级需提供有限主轴尺寸；使用 Column / Row 分配剩余空间时先用 Expanded 约束。持久化由业务保存 onResize 结果，并在后续创建时传回。
