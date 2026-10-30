# Tap Feedback

三个通用按钮反馈，child 和 style 决定业务外观。导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

```dart
ElFadeTap(onPressed: () {}, child: Text('淡化'));
ElScaleTap(onPressed: () {}, child: Text('缩放'));
ElRippleTap(
  onPressed: () {},
  semanticLabel: '打开详情',
  style: ElStyle(padding: EdgeInsets.all(12), borderRadius: BorderRadius.circular(8)),
  child: Text('涟漪'),
);
```

| 组件 | 反馈 |
| --- | --- |
| ElFadeTap | 按压时 opacity 降到 0.2，松开后过渡恢复 |
| ElScaleTap | 按压时缩放到 0.95，默认 100ms 过渡 |
| ElRippleTap | 悬停高亮，按压从落点扩散涟漪，支持键盘反馈 |

共同参数为 onPressed（可 null）、child、disabled、semanticLabel、style；disabled 同时关闭反馈与激活。Fade/Scale 可用 style.onTap 和 transitions 覆写默认效果；Ripple 额外提供 focusNode，外部节点由调用方 dispose。

键盘和辅助激活沿用 [ElButtonView](../../views/button/README.md)：Enter 激活，Space 按住/释放完成会话。需要 event、toggled 或 selected 等完整按钮参数时，直接组合 ElButtonView 的样式与状态。
