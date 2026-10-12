# Flutter Base 动画示例

首页展示九个实际界面场景：轻量提示、侧边面板、状态反馈、消息通知、确认弹窗、内容揭示、卡片翻转、纵向折叠面板和横向搜索工具栏。

每种动画内置运动参数和动作幅度。反转时保留当前位置和速度，使用临界阻尼弹簧平稳回正。示例只保留各场景开关和全部播放，无需调整动效参数。

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
