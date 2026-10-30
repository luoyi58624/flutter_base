# Selection

为当前子树建立独立文档选区。弹窗需要选择能力时，显式再包一个根。

```dart
final controller = ElSelectionController();
ElSelectionView(
  controller: controller,
  child: Column(children: [ElView(child: '第一段'), Text('第二段')]),
);
ElButtonView(onPressed: controller.selectAll, child: '全选');
final selectedText = controller.text;
ElButtonView(onPressed: controller.clear, child: '清除');
```

控制器在卸载时 dispose。对象框选仍属实验能力，见 box/；原有详细约定保留在 [CONTRACT.md](CONTRACT.md)。

示例省略导入：`package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。
