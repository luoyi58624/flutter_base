# Select

从 Element Plus `components/form/select/` 迁入，由桌面预设注册。通用参数见 [Select](../../../../flutter/components/select/README.md)，安装见 [Desktop](../../README.md)。

保留业务模型与筛选文本分离、候选过滤、键盘 active 导航、选择回写、IME 状态及焦点恢复。panel.dart 保留品牌候选层外观和交互，宿主使用 ElPopup 锚定，进退场共用 dropdown_transition.dart。

