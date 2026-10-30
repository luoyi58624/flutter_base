# CardView

为内容建立独立的区域语义，布局和外观仍由 ElView 样式控制。

```dart
ElCardView(
  semanticLabel: '订单摘要',
  style: ElStyle(padding: EdgeInsets.all(16)),
  child: Column(children: [Text('订单 #1001'), Text('待付款')]),
);
```

示例省略导入：`package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。
