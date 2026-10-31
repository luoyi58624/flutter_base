# Sidebar

`ElSidebar` 是实现于 Widget 上的布局元数据协议，包含 width、expandTop、drawer 和 keepAlive。`ElSidebarState` 只保存 collapsed、drawer 与所属 ElScaffoldController 的快照。

该目录不提供侧栏 Widget、Builder、上下文查找或折叠动作实现；运行宿主与命令接口的连接在后续实现中处理。
