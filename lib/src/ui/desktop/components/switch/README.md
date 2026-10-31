# Switch

从 Element Plus `components/form/switch/index.dart` 迁入，注册到 `ElementPlusThemeData.switchButton`。通用参数见 [Switch](../../../../flutter/components/switch/README.md)，安装见 [Desktop](../../README.md)。

保留普通 bool、ValueNotifier 与表单绑定通道，disabled 与 loading、焦点、语义和事件取消规则。轨道、滑块、开启与关闭内容、显式 height / gap / widthAspect 和 slide 均沿源实现。

默认几何分 normal / compact 两态，轨道高度分别为 26 / 24，间距为 2；显式 height、gap、widthAspect 参数优先。滑块的固定尺寸、300ms 位移和内容过渡保持源行为。
