# Collapse

`ElCollapse<D>` 的 D 是完整模型类型：单项展开使用可空业务值，多项展开使用 `List<业务值>`。复用 ElModelValue 和既有 ElModelValueType，不新增模式或成员注册协议。

single 强制 D 可空：再次激活允许全部收起，null 表示全部收起。multi 须提供初始 List 或外部模型。分组额外参数仅 children、disabled、style、semanticLabel。

`ElCollapseItem<T>` 直接声明 value、title、child、disabled、style，业务身份不限 String。展开计算、动画、内容保活和标题导航由品牌实现；接口只保存配置并分派。移动端尚未登记对应 Builder。
