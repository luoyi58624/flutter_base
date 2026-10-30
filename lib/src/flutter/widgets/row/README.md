# Row / Col

24 栅格布局，列宽由 span 决定，空间不足时换行。

```dart
ElView(
  style: ElStyle(width: 600),
  child: ElRow(gutter: 16, children: [
    ElCol(span: 8, child: '左侧'),
    ElCol(span: 16, child: '右侧'),
  ]),
);
```

xs / sm / md 等是本库的上界断点语义，勿直接套用 CSS min-width 断点含义。

示例省略导入：`package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。
