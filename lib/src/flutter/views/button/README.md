# ButtonView

提供点击、键盘激活、焦点和语义；外观由内容与样式决定。

```dart
ElButtonView(
  onPressed: () {},
  semanticLabel: '保存',
  style: ElStyle(padding: EdgeInsets.all(12), bgColor: Colors.blue),
  child: '保存',
);
```

纯行为按钮不需要 ElComponentProvider；disabled 会同时禁用交互。

示例省略导入：`package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。
