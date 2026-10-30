# Layout

按用途选择 List、Grid 或 Stack。普通构造全量布局；builder 构造交给滚动宿主虚拟化。

```dart
ElListView(gap: 8, children: [Text('第一项'), Text('第二项')]);
```

LayoutView / RenderLayoutView 是内部扩展基类，业务优先使用下列具体容器。

示例省略导入：`package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。
