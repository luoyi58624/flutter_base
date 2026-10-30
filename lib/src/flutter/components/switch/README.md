# Switch

`ElSwitch` 声明布尔值、轨道和滑块配置，通过 `switchBuilder(context, component)` 提供具体绑定、交互和外观。导入与实现登记见 [Components](../README.md)。

```dart
final enabled = ValueNotifier(false);
ElSwitch(
  modelValue: enabled,
  onChanged: (value) { debugPrint('通知：$value'); },
  activeContent: '开',
  inactiveContent: '关',
  semanticLabel: '消息通知',
);
```

| 参数 | 用途 |
| --- | --- |
| value / modelValue / onChanged | bool 输入、双向绑定和变化通知；value 与 modelValue 互斥 |
| disabled / loading | 禁止切换；loading 同时显示加载状态 |
| activeColor / inactiveColor | 开启、关闭时的轨道颜色 |
| activeContent / inactiveContent | 轨道两种状态的内容 |
| activeActionContent / inactiveActionContent | 滑块两种状态的内容 |
| height / gap / widthAspect | 高度、边缘间距与最小宽高比 |
| slide | 是否使用滑块切换动画 |
| style / trackStyle | 根样式与轨道样式 |
| focusNode / event / semanticLabel | 焦点、事件和辅助名称 |

`onChanged` 为空不表示禁用。value 变化时的同步、缺省状态和祖先表单字段的接入由具体实现处理；公共声明本身不继承 `ElModelValue`。外部 notifier 和焦点节点由调用方持有并释放。
