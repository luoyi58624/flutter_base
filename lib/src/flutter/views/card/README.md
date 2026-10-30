# CardView

建立区域语义，保留子内容各自的文本、按钮节点；外观与布局沿用 ElView。导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

```dart
ElCardView(
  semanticLabel: '订单摘要',
  style: ElStyle(
    padding: EdgeInsets.all(16),
    bgColor: Colors.white,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('订单 #1001'),
    Text('待付款'),
    ElButtonView(onPressed: () {}, child: '立即付款'),
  ]),
);
```

| 参数 | 用途 |
| --- | --- |
| semanticLabel | 命名区域，不替换后代语义 |
| child / style | 内容、尺寸、盒模型和文本样式 |
| event / focusNode | 可选区域交互与焦点，不默认创建按钮动作 |
| themeMode / breakpoint / inheritSize / locale | 继承 ElView 的主题、响应式和文本环境 |

区域边界包含边框及内边距，margin 只参与排布。可点击卡片需明确提供 event；需要标准按钮键盘激活时使用 ElButtonView，卡片内部操作按钮仍可保持独立。完整样式见 [ElView](../view/README.md)。
