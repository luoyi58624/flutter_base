# ElView

盒模型、内容、样式、事件和语义的基础宿主。

```dart
ElView(
  style: ElStyle(
    padding: EdgeInsets.all(12),
    bgColor: Colors.blue,
    borderRadius: BorderRadius.circular(8),
    onHover: ElStyle(bgColor: Colors.indigo),
  ),
  event: ElEvent(onTap: (_) {}),
  child: '点击我',
);
```

child 可接 Widget、文本或混排内容。Row 的 Expanded、Stack 的 Positioned 应放在各自的直接布局槽内。

示例省略导入：`package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。
