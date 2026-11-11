# Tap Feedback

按压淡化和缩放通过 `ElStyle.withTapFade()`、`ElStyle.withTapScale()` 添加，直接复用视图的按压态和过渡。导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

```dart
ElButtonView(onPressed: () {}, style: ElStyle().withTapFade(), child: '淡化');
ElButtonView(onPressed: () {}, style: ElStyle().withTapScale(), child: '缩放');
ElRippleTap(
  onPressed: () {},
  semanticLabel: '打开详情',
  style: ElStyle(padding: EdgeInsets.all(12), borderRadius: BorderRadius.circular(8)),
  child: Text('涟漪'),
);
```

| 用法 | 反馈 |
| --- | --- |
| withTapFade(0.2) | 按下立即变为 0.2，退出按压态后用 250ms 的 easeInOutQuad 恢复原透明度 |
| withTapScale(0.95) | 按下缩小至 0.95 倍，进入和恢复均默认使用 100ms 的 easeOut |
| ElRippleTap | 悬停高亮，按压从落点扩散涟漪，支持键盘反馈 |

淡化和缩放只负责样式，可直接用于 ElView 或组合在同一个按钮上，不额外创建 Widget 或维护按压状态：

```dart
ElButtonView(
  onPressed: () {},
  style: ElStyle().withTapScale(0.95).withTapFade(0.4),
  child: '缩放与淡化',
);
```

两个扩展保留其他按压属性，以及常态和按压态中已覆盖相应字段的过渡。淡化的常态过渡控制恢复，`onTap.transition` 控制进入；没有独立的按压过渡表时，会继承常态表的其他字段过渡，再将透明度设为立即变化。常态未设置 opacity 时，恢复到默认的不透明状态。

按下时进入反馈，释放、取消、拖拽获胜或禁用时恢复。淡化时长由样式过渡配置，点击在 Flutter 确认识别时触发。

按钮参数和键盘、辅助激活沿用 [ElButtonView](../../views/button/README.md)。`disabled` 同时关闭反馈与激活；`ElRippleTap` 仍提供 onPressed（可 null）、child、disabled、semanticLabel、style 和 focusNode，外部焦点节点由调用方 dispose。
