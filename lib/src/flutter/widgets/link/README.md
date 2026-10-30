# Link

链接统一处理激活、焦点、辅助语义与目标导航。

```dart
ElLink(
  href: 'https://example.com',
  target: LinkTarget.blank,
  child: '查看详情',
);
```

无 href 时可作为纯行为链接，通过 onPressed 接入操作；外观走 style。

示例省略导入：`package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。
