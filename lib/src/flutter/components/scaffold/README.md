# Scaffold

`ElScaffold` 声明导航、固定底部区域、body / viewport、滚动控制器、刷新、滚动策略、两侧导航和边缘唤出范围，通过 `scaffoldBuilder(context, component)` 分派。

`ElScaffoldController` 仅声明 Listenable、开合与折叠状态、滚动控制器读取和对应命令签名；`ElScaffoldState` 仅声明已挂载页面的查询与命令契约。此处没有控制器实例、Flutter State、页面布局、抽屉生命周期、滚动监听或 of / maybeOf 运行查找；这些由后续实现提供。
