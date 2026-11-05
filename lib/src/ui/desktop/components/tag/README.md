# Tag

从 Element Plus `components/basic/tag/index.dart` 迁入，由桌面预设注册。通用参数见 [Tag](../../../../flutter/components/tag/README.md)，安装见 [Desktop](../../README.md)。

公共宿主管理 bool 绑定和主入口交互，品牌 Builder 读取 selected、isToggle 并保留柔和底色、light / dark / plain、尺寸、圆角与命中反馈。关闭入口使用独立的 ElButtonView；关闭动作阻止传播，避免触发标签切换。

标签外观沿用通用组件的选择模型。
