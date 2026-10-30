# Other Widgets

测量、加载和监听等通用组合能力。尺寸构建器复用同一份内容 State：

```dart
ElChildSizeBuilder(
  child: Text('测量真实内容'),
  builder: (size, child) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [Text('尺寸：$size'), child],
  ),
);
```

builder 收到的 child 可以省略或放置一次；仍可能发生测量和最终布局两次布局。

```dart
ElLoading(child: Icon(Icons.sync));
ElFps();

final controller = ScrollController();
ElInfiniteScroll(
  controller: controller,
  onLoad: () async {},
  child: SizedBox(height: 200, child: ElScrollView(controller: controller, children: [Text('内容')])),
);
```

ElFps 只显示实时帧率，位置由外层布局决定；平均 FPS 不能单独证明滚动或输入流畅。ElInfiniteScroll 的 controller 应与内容滚动宿主相同。

示例省略导入：`package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。
