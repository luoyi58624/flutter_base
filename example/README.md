# Flutter Base 动画示例

首页展示九个实际界面场景：轻量提示、侧边面板、状态反馈、消息通知、确认弹窗、内容揭示、卡片翻转、纵向折叠面板和横向搜索工具栏。

每种动画内置运动参数和动作幅度。透明度与几何变化分别驱动，让文字快速清晰；完整动作使用确定时长，反转承接当前位置与速度，最多用 4ms 制动，再按剩余距离在 80ms 内收尾。示例只保留各场景开关和全部播放，无需调整动效参数。

侧栏进入时减速停靠，离开时加速滑出；折叠提前达到速度峰值，末端速度与加速度归零，展开 200ms、收拢 160ms。侧栏的动作参考 [Material 的入场与退场原则](https://m1.material.io/motion/duration-easing.html)。弹窗从 92% 尺寸进入，退场保持尺寸并淡出；状态标记单调缩放；翻转沿 X 轴从下方抬起；Reveal 使用中心圆形遮罩。

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
