# Card

`ElCard` 声明正文、标题、说明、附加编号、加载状态和整卡激活配置，通过 `cardBuilder(context, component)` 分派。child 接受文本、图标或 Widget；style、semanticLabel 和外部 focusNode 保留调用方配置。

本目录仅提供公共声明，不实现布局、加载动画、事件或焦点。品牌实现负责 interactive、onActivate 与触摸反馈时序，并为内部控件保留独立操作。无品牌外观的区域基元继续使用 ElCardView。
