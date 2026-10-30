# ZoomView

为单个内容提供缩放、平移及可选旋转。

```dart
final controller = ElZoomController();
SizedBox(
  width: 320, height: 240,
  child: ElZoomView(
    controller: controller,
    maxScale: 6,
    child: FlutterLogo(size: 120),
  ),
);
ElButtonView(onPressed: () => controller.reset(), child: '还原');
```

控制器长期持有并 dispose；内容不是图片也能接入。

示例省略导入：`package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。
