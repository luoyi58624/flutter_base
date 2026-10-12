# Flutter Base 动画示例

首页展示九个实际界面场景：轻量提示、侧边面板、状态反馈、消息通知、确认弹窗、内容揭示、卡片翻转、纵向折叠面板和横向搜索工具栏。

每种动画内置运动响应和动作幅度。透明度与几何变化分别驱动，连续切换只改变目标，保留当前位置和速度，沿用相同的刚度与阻尼。结束时间由当前运动状态自然决定。示例只保留各场景开关和全部播放，无需调整动效参数。

布局、侧栏、翻转和揭示使用 [Flutter Cupertino 对话框与 action sheet 的弹簧参数](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/cupertino/route.dart)：质量 1、刚度 522.35、阻尼 45.7099552。小幅反馈取 [Material 标准运动](https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/StandardMotionTokens.kt) 的 fast spatial 刚度 1400，并使用临界阻尼保持尺寸范围；透明度使用 fast effects 刚度 3800 和临界阻尼。

弹窗从 92% 尺寸进入，退场仅淡出，内容完全不可见后才复位几何状态。背景显隐与弹窗透明度同步，折叠箭头与面板运动同步；中途反转也保持同步。翻转沿 X 轴从下方抬起，Reveal 使用中心圆形遮罩。

```dart
import 'package:flutter_base/flutter_base.dart';

ElFadeScaleAnimation(
  value,
  child: content,
)
```

位置参数 `value` 为 true 时显示，为 false 时隐藏。初次挂载直接呈现目标状态。动画途中可以反向切换，隐藏时禁用指针交互和语义。

Collapse 额外保留方向及状态管理：

```dart
ElCollapseAnimation(
  value,
  axis: Axis.horizontal,
  keepState: false,
  child: content,
)
```

`keepState: false` 在退场完成后销毁内容；中途重新展开保留原有状态。Collapse 改变布局占位，其他动画保留占位。

在此目录运行：

```powershell
flutter pub get
flutter run -d windows
```

无头验证：

```powershell
flutter test test/animations_page_test.dart
```
