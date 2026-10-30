# Watermark

在现有内容上绘制水印，不拦截底层点击。

```dart
ElWatermark(
  content: ['内部资料', '仅供预览'],
  child: SizedBox(width: 320, height: 200, child: Text('正文')),
);
```

rotate 使用角度；gap 控制水平与垂直重复间距。

示例省略导入：`package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。
