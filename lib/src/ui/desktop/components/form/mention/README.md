# Mention

从 Element Plus `components/form/mention/` 迁入，注册到 `ElementPlusThemeData.mention`。通用参数见 [Mention](../../../../../flutter/components/mention/README.md)，安装见 [Desktop](../../../README.md)。

保留前缀与光标上下文、单项或整表过滤、键盘 active 导航、候选提交与完整提及删除。输入模型仍使用 String，T 只表示候选附加数据。

候选层沿光标几何定位，panel.dart 保留品牌样式；离场枚举名称适配为 ElPortalPhase，没有重写编辑控制器或面板行为。
