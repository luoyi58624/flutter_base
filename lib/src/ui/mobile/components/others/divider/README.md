# Divider

内部 Divider 皮肤保留水平 / 竖向、虚线、内容和 start / center / end 对齐，以及原有局部变量覆写，供内部回归继续验证。

用户使用通用 ElDivider 独立基元；它没有可注册的品牌 Builder 插槽，不增加旧皮肤专用参数。具体 Divider 与变量键不从 mobile.dart 导出。实现见 [index.dart](index.dart)。
