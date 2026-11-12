# Sliver 业务示例

这些页面沿用原有路由 key，以 Sliver 组织滚动内容，滚动条绑定页面的 ScrollController。下拉保留现有官方与回收对照，并增加 ElScrollView · children / builder / recycler。各模式共用业务工厂、数据、控制器和 250 逻辑像素缓存窗口；外卖继续沿用原有 ElScrollView 宿主与平滑滚轮。合成列表、网格与长文使用 1000 条，本机媒体及 Bibi 卡片来源按实际数量显示。

| 场景 | 当前入口与保留行为 |
| --- | --- |
| 色块、纯文本 | 复用 ../sliver_recycler/index.dart 的千条负载，纯文本入口指定初始内容 |
| 复杂卡片 | cards.dart；按需创建记录、固定卡片与图片、按压反馈、统计叶子更新、按业务 ID 选择 |
| 复选列表 | selection.dart；按需创建文案，行点击与复选不重复消费，选择持久化，业务等高条目定位 |
| 聊天、实时群聊 | chat.dart；反向列表、历史前插、流式增长、未读、末端跟随，按消息 ID 恢复位置；正文步骤只更新相关进度文字 |
| 动态流 | social_feed.dart；长文展开、九宫格、转发和投票 |
| 订单 | orders.dart；选择、进度、批次更新、头部增删后按订单 ID 补偿位置 |
| 视频流、相册、瀑布流 | media.dart 及 part；授权、本机文件、缩略图队列、预览、播放和过期结果处理；整宽头图单独作为 Sliver |
| 商品瀑布流 | product_waterfall.dart；延迟揭晓图片尺寸、远拖、详情返回与自然补测 |
| 富文本文档 | rich_document.dart；ElSliverList 常驻文档对照官方 SliverList，目录定位不变，展开与勾选只通知当前节 |
| 单帧尖峰工具 | spike.dart；控制栏保留列表配置，回收行只更新编号；注入、取消、拖动与惯性窗口不变，测试替换工作函数 |
| 外卖 | 复用上级 sliver_takeaway/，普通卡片布局与 ElImageView，店名/商品名单行、商品等高，保留分类、店内菜单、图集、加购和辅助操作 |

媒体布局与卡片来源分别切换，Bibi 卡片来源不构成第三种滚动实现。官方网格按自身协议提供格子几何，回收网格和瀑布流继续自然测量。selection、cards、orders 的定向定位只沿用各页已有的业务等高几何，没有增加组件 itemExtent 参数。

官方网格示例在几何不变时保留 SliverGrid 与 delegate，滚动不重新配置已挂载卡片；宽度、列数、字号和方向变化仍正常更新。记录懒创建减少初始分配，缓存随访问增长；官方自然高度 SliverList 的远距离定位仍可能布局中间条目，这与 recycler 的定位成本不同。

文档设置中的旧 recyclerView 存储值定向迁移为 sliverList，使用 CustomScrollView + ElSliverList。官方普通、官方虚拟文档模式保留；ElScrollView 模式常驻挂载文档，沿用 elScroll 存储值，旧值 elScrollView 迁移到该值。常驻文档通过已挂载小节进行 ensureVisible，回收项需要先挂载才能定位。

旧公共入口 lib/recycler_view.dart、lib/flutter.dart 中的旧导出、旧内核、旧例页副本及专属诊断报告已移除。仍有效的业务回归迁到 example/test/scroll_*.dart，新 Sliver 的换绑过渡回归位于 test/flutter/slivers/sliver_recycler_rebind_transition_test.dart；旧 Adapter/Holder 成本诊断下线。

共享 example_image、example_scrollbar、plain_scroll、Bibi、外卖与 recycler_cards 资产保留。
