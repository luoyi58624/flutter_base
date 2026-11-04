# Tap Feedback

按压缩放通过 `ElStyle.withTapScale()` 添加。淡化和涟漪反馈可使用下面的按钮。导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

```dart
ElFadeTap(onPressed: () {}, child: Text('淡化'));
ElButtonView(onPressed: () {}, style: ElStyle().withTapScale(), child: '缩放');
ElRippleTap(
  onPressed: () {},
  semanticLabel: '打开详情',
  style: ElStyle(padding: EdgeInsets.all(12), borderRadius: BorderRadius.circular(8)),
  child: Text('涟漪'),
);
```

| 组件 | 反馈 |
| --- | --- |
| ElFadeTap | 对齐 RN TouchableOpacity：首次按下立即变为 0.2，移出后重新移入用 150ms 变淡，释放或取消后用 250ms 恢复 |
| ElRippleTap | 悬停高亮，按压从落点扩散涟漪，支持键盘反馈 |

共同参数为 onPressed（可 null）、child、disabled、semanticLabel、style。disabled 同时关闭反馈与激活。Ripple 额外提供 focusNode，外部节点由调用方 dispose。

缩放默认为 0.95 倍，缺少变换过渡时使用 100ms 的 `easeOut`。可以在调用 `withTapScale()` 前配置 `transition` 和 `onTap`，合并时会保留其他按压属性及已有过渡。

Fade 不保留最短触摸反馈，松手立即恢复到原有透明度，点击仍在抬手时触发。缓动使用与 RN `Easing.inOut(Easing.quad)` 相同的二次函数；通过 `style.onTap.opacity`、`style.onTap.transition` 和 `style.transition` 分别覆写按压透明度、进入过渡和恢复过渡。这里对齐的是透明度动画，命中范围、手势竞争及键盘行为仍沿用 ElButtonView。

键盘和辅助激活沿用 [ElButtonView](../../views/button/README.md)：Enter 激活，Space 按住/释放完成会话。需要 event、toggled 或 selected 等完整按钮参数时，直接组合 ElButtonView 的样式与状态。
