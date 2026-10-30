# Text

`ElText` 平铺声明 Flutter Text 的常用参数，通过 `textBuilder(context, component)` 分派到当前品牌实现。导入与实现登记见 [Components](../README.md)。

```dart
ElText(
  '订单已完成',
  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
);
```

| 参数 | 用途 |
| --- | --- |
| data | 必填的字符串内容 |
| style / strutStyle | TextStyle 与行高支柱配置 |
| textAlign / textDirection / locale | 对齐、文字方向和语言区域 |
| softWrap / overflow / maxLines | 换行、溢出与最大行数 |
| textScaler | 字体缩放策略 |
| textWidthBasis / textHeightBehavior | 文本宽高计算方式 |
| selectionColor | 选区颜色 |

这里的 style 是 Flutter TextStyle。公共声明只转交参数，文本布局、主题默认值及选择环境由具体实现提供；Builder 应保留调用方明确指定的值。
