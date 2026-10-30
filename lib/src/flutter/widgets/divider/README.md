# Divider

水平/垂直分割线，可在中间放内容。导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

```dart
ElDivider(child: '更多内容', thickness: 1, gap: 8, color: Colors.grey);
ElDivider(
  vertical: true,
  thickness: 1,
  style: ElStyle(height: 80),
);
```

| 参数 | 默认与说明 |
| --- | --- |
| vertical | false；true 改为竖线 |
| child | 可选中间标签，支持文本或 Widget |
| size | 默认 24，生成容器基础尺寸；横线默认占满可用宽度，竖线基础宽高均取 size |
| thickness | 默认 1，线条粗细 |
| indent | 默认 0，水平线左右或竖线上下的内缩 |
| gap | 默认 8，标签两侧与线条之间的间隔 |
| color | 默认灰色 0xff808080 |
| style | 覆写容器尺寸、边距等，例如竖线实际高度 |

无 child 时只画一条线；有 child 时两侧线段平均分剩余空间。水平需有有限宽度，竖直需有有限高度；竖线高度通过 style.height 覆盖自身基础尺寸。
