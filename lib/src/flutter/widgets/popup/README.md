# Popup / Portal

声明锚点内容和面板，用控制器开闭；需要祖先提供官方 Overlay。

```dart
final controller = ElPortalController();
ElPortal(
  controller: controller,
  anchor: ElOverlayAnchor(placement: ElPlacement.bottomStart, offset: 8),
  overlayBuilder: (_) => SizedBox(width: 160, height: 80, child: Text('面板')),
  child: ElButtonView(onPressed: controller.toggle, child: '打开'),
);
```

exitDuration 用于退场保活；controller.closed 在内容摘除后完成。控制器在卸载时 dispose。

示例省略导入：`package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。
