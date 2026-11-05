# Icon

`ElIcon` 使用 Flutter `IconData` 绘制字体图标，装饰图标可以省略辅助名称。

`ElIcon` 直接使用 ElView 的字形通道，尺寸与颜色沿 `ElStyle.iconSize` 和 `iconColor` 继承。`applyTextScaling` 控制是否随系统文字缩放，可变轴及阅读方向可以按图标配置。

```dart
ElView(
  style: ElStyle(iconSize: 28, iconColor: Colors.blue),
  child: ElIcon(Icons.home),
);
```

按钮、列表、输入、选择器、菜单和底栏的图标槽会将普通 Flutter Icon 转入相同字形通道，显式 size / color 等参数转为局部样式；其他自定义 Widget 保留原实例。SVG 加载、进度及关闭图标同样读取最近 ElView 的 iconSize / iconColor，由渲染侧响应样式变化。

桌面端的 `ElDesktopIcons` 提供 Element 字体的 `IconData`。移动端的 `ElMobileIcons` 提供可直接传给图标插槽的 SVG Widget。
