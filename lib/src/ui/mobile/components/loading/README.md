# Loading

内部 Loading 保留 16 / 24 / 32 像素尺寸、默认说明、内容槽和减少动态效果配置，用作移动端按钮、开关及卡片的加载指示。

公共 ElLoadingIndicator 声明已存在，移动端尚未适配对应 Builder。具体实现不从 mobile.dart 导出，现有皮肤回归显式访问内部源码。实现见 [index.dart](index.dart)。
