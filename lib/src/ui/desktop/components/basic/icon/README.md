# Internal Icon

Element Plus 图标作为 Button、Switch、Input 等已迁入组件的内部依赖保留。index.dart 使用 ElView 的图标通道，icons.dart 保留源字体码点和名称；字体 family 为 element，fontPackage 为 flutter_base。

保留独立图标尺寸与颜色继承、RTL 镜像、可选文字缩放和字体变体轴。默认不随系统文字缩放。图标未新增到通用 ElComponentBuilders 接口；桌面公开入口以已支持的通用组件和主题安装为准。
