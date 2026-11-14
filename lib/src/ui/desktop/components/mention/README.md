# Mention

从 Element Plus `components/form/mention/` 迁入，由桌面预设注册。通用参数见 [Mention](../../../../flutter/components/mention/README.md)，安装见 [Desktop](../../README.md)。

保留前缀与光标上下文、单项或整表过滤、键盘 active 导航、候选提交与完整提及删除。输入模型仍使用 String，T 只表示候选附加数据。

候选层由 ElPopup 锚定在光标处，panel.dart 保留品牌样式，进退场共用 dropdown_transition.dart；外部点击或 Esc 关闭时清空候选。
