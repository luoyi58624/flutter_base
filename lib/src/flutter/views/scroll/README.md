# ScrollView

普通滚动与虚拟列表使用同一个宿主。

```dart
SizedBox(
  height: 320,
  child: ElScrollView(children: [
    ElListView.builder(
      itemCount: 1000,
      itemBuilder: (_, i) => SizedBox(height: 40, child: Text('第 $i 行')),
    ),
  ]),
);
```

默认需要父级提供有限视口。builder List/Grid 是 children 的直接成员；shrinkWrap 会全量布局并关闭虚拟挂窗。

示例省略导入：`package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。
