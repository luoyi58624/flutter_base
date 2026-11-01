# Icon

ElIcon 保留 Flutter IconData 作为 child，共同参数只有 size、color、style 和 semanticLabel。装饰图标可以省略辅助名称。

不再单独公开 fill / weight / grade / opticalSize、fontWeight、textDirection 或 applyTextScaling。字形数据、可变轴、字体与方向由 ElStyle 或既有图标机制承接，不在接口复制一份 Flutter Icon 配置。

移动和桌面主题均已登记 Icon Builder，统一使用 ElView 的字体字形通道；尺寸与颜色由 ElStyle.iconSize / iconColor 继承，支持状态、主题过渡，默认不随系统文字缩放。具体实现不公开导出。

```dart
ElView(
  style: ElStyle(iconSize: 28, iconColor: Colors.blue),
  child: ElIcon(Icons.home),
);
```

按钮、列表、输入、选择器、菜单和底栏的图标槽会将普通 Flutter Icon 转入相同字形通道，显式 size / color 等参数转为局部样式；其他自定义 Widget 保留原实例。SVG 加载、进度及关闭图标同样读取最近 ElView 的 iconSize / iconColor，由渲染侧响应样式变化。
