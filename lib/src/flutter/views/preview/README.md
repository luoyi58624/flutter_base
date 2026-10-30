# PreviewView

多页预览，组合分页与每页的缩放、平移能力。

```dart
final controller = ElPreviewController();
SizedBox(
  width: 320, height: 240,
  child: ElPreviewView(
    controller: controller,
    children: [FlutterLogo(size: 100), Text('第二页')],
  ),
);
ElButtonView(onPressed: () => controller.next(), child: '下一页');
```

大数据集用 builder；重排数据时提供稳定的 itemIdBuilder。控制器在卸载时 dispose。

示例省略导入：`package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。
