# Tap Feedback

根据交互需要选择透明、缩放或涟漪反馈。

```dart
ElFadeTap(onPressed: () {}, child: Text('淡化'));
ElScaleTap(onPressed: () {}, child: Text('缩放'));
ElRippleTap(onPressed: () {}, child: Text('涟漪'));
```

child 负责内容和外观；disabled 同时关闭交互。

示例省略导入：`package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。
