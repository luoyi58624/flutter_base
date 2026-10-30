# Splitter

按占比分配相邻面板，拖动分隔条调整大小。

```dart
SizedBox(
  width: 600, height: 240,
  child: ElSplitterView(panels: [
    ElSplitterPanel(size: 0.3, min: 0.2, child: Text('侧栏')),
    ElSplitterPanel(child: Text('正文')),
  ]),
);
```

size、min、max 使用 0～1 的占比；外层提供有限的主轴尺寸。

示例省略导入：`package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。
