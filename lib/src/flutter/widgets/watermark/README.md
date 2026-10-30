# Watermark

在内容上平铺旋转文字，水印层不拦截指针。导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

```dart
ElWatermark(
  content: ['内部资料', '用户 Alice'],
  fontSize: 14,
  color: Color(0x26000000),
  rotate: -22,
  gap: Offset(100, 80),
  offset: Offset(20, 20),
  child: SizedBox(width: 320, height: 200, child: Text('正文')),
);
```

| 参数 | 默认与说明 |
| --- | --- |
| content | String 单行、List<String> 多行；null 不绘制文案 |
| fontSize / fontWeight / fontFamily | 默认 16 / normal / 未指定字体族 |
| color | 默认 0x26000000 |
| rotate | 默认 -22，单位为**度** |
| gap | 默认 Offset(100, 100)，水平和垂直重复间距 |
| offset | 整体起始偏移，省略时取 gap 的一半 |
| style / child | 外层样式与被覆盖内容 |

内容本身决定水印区域尺寸；内容仍可正常点击和滚动。
