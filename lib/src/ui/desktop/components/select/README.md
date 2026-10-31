# Select

从 Element Plus `components/form/select/` 迁入，注册到 `ElementPlusThemeData.select`。通用参数见 [Select](../../../../flutter/components/select/README.md)，安装见 [Desktop](../../README.md)。

保留业务模型与筛选文本分离、候选过滤、键盘 active 导航、选择回写、IME 状态及焦点恢复。panel.dart 保留品牌候选层外观和交互，宿主继续使用通用 ElPortal。

源 ElPresencePhase.exiting 对应当前 ElPortalPhase.exiting，只调整枚举名称，保留离场期间的交互保护。
