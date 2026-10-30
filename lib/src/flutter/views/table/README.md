# Table

控制器持有数据和列；ElTable 负责显示、滚动和交互。

```dart
final controller = ElTableController(
  rowKey: 'id',
  data: [{'id': 1, 'name': 'Alice'}],
  columns: [ElTableColumn(prop: 'name', title: '姓名')],
);
ElTable(controller: controller, height: 240);
```

控制器在卸载时 dispose。当前仍读取 UI 层的 ElComponentProvider；迁移目录不等于完全移除品牌配置依赖。

示例省略导入：`package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。
