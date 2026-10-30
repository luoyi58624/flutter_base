# TabView

水平分页；控制器负责页索引，页面内容由调用方提供。

```dart
final controller = ElTabController(length: 2);
SizedBox(
  height: 240,
  child: ElTabView(controller: controller, children: [Text('首页'), Text('设置')]),
);
```

需要延迟构建时启用 lazy；控制器由宿主持有并 dispose。

示例省略导入：`package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。
