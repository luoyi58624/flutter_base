# Sliver 业务示例

这些页面从旧 RecyclerView 示例迁出，继续保留原来的十五个路由 key。滚动宿主统一为 CustomScrollView，滚动条绑定同一个 ScrollController；布局菜单仅保留官方 SliverList / SliverGrid 与 ElSliverRecyclerList / ElSliverRecyclerGrid 两种实现。

| 场景 | 当前入口与保留行为 |
| --- | --- |
| 色块、纯文本 | 复用 ../sliver_recycler/index.dart 的万条负载，纯文本入口指定初始内容 |
| 复杂卡片 | cards.dart；固定卡片与图片、按压反馈、统计叶子更新、按业务 ID 选择 |
| 复选列表 | selection.dart；行点击与复选不重复消费，选择持久化，业务等高条目定位 |
| 聊天、实时群聊 | chat.dart；反向列表、历史前插、流式增长、未读、末端跟随，按消息 ID 恢复位置 |
| 动态流 | social_feed.dart；长文展开、九宫格、转发和投票 |
| 订单 | orders.dart；选择、进度、批次更新、头部增删后按订单 ID 补偿位置 |
| 视频流、相册、瀑布流 | media.dart 及 part；授权、本机文件、缩略图队列、预览、播放和过期结果处理；整宽头图单独作为 Sliver |
| 商品瀑布流 | product_waterfall.dart；延迟揭晓图片尺寸、远拖、详情返回与自然补测 |
| 富文本文档 | rich_document.dart；沿用计划选择的 ElSliverList 常驻文档，对照官方 SliverList，保留目录、展开与勾选 |
| 单帧尖峰工具 | spike.dart；注入、取消、拖动与惯性窗口，测试替换工作函数，不运行压力基准 |
| 外卖 | 复用上级 sliver_takeaway/，保留分类、店内菜单、图集、加购、纯 RenderObject 和辅助操作 |

媒体布局与卡片来源分别切换，Bibi 卡片来源不构成第三种滚动实现。官方网格按自身协议提供格子几何，回收网格和瀑布流继续自然测量。selection、cards、orders 的定向定位只沿用各页已有的业务等高几何，没有增加组件 itemExtent 参数。

文档设置中的旧 recyclerView 存储值定向迁移为 sliverList，使用 CustomScrollView + ElSliverList；原有官方普通、官方虚拟文档模式保留，旧 ElScrollView 模式改为 ElScroll 常驻文档，旧存储值 elScrollView 定向迁移为 elScroll。常驻文档通过已挂载小节进行 ensureVisible，不能将该能力用于尚未挂载的回收项。

旧公共入口 lib/recycler_view.dart、lib/flutter.dart 中的旧导出、旧内核、旧例页副本及专属诊断报告已移除。仍有效的业务回归迁到 example/test/scroll_*.dart，新 Sliver 的换绑过渡回归位于 test/flutter/slivers/sliver_recycler_rebind_transition_test.dart；旧 Adapter/Holder 成本诊断下线。

共享 example_image、example_scrollbar、plain_scroll、Bibi、外卖与 recycler_cards 资产保留。ElScrollable 实现和 ElScrollView 内核迁移留待后续；本轮只使用局部无头测试，不将其耗时视为设备帧耗时。
