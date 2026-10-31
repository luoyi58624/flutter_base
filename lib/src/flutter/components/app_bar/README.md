# AppBar

`ElAppBar` 保留普通、largeTitle、collapse、fade 四个构造，通过 `appBarBuilder(context, component)` 分派。title、leading、actions、返回按钮、居中、颜色、底边线、最大宽度和层级均为配置。

largeTitle 的 scale / fade / snap / search、collapse 的 followDelta / 速度阈值 / collapseOffset、fade 的渐显范围 / 曲线 / initialColor / fadeTitle 只声明参数，不创建滚动监听或动画。isLargeTitle、isCollapsible、isFading 供未来实现读取构造模式。

`ElAppBarSearch` 单独声明 value、onChanged、placeholder 和 semanticLabel，通过 `appBarSearchBuilder` 分派。本目录不实现编辑、搜索交接或 iconButton 快捷 UI 工厂。
