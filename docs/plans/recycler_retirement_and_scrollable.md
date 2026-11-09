# 旧 RecyclerView 退休与 ElScrollable 重构准备计划

日期：2026-11-10  
项目：D:\project\flutter\flutter_base  
审计基线：747b8a5（修复滚动跳动问题）

本文是交给本地 agent 的执行计划。本轮仅新增本文，没有修改、迁移或删除实现，也没有运行测试。下文文件路径均相对于上述项目根目录；执行时先核对当前源码和工作区，保留在途修改。

## 1. 目标与执行范围

分两步完成：

1. 迁移仍有效的页面与行为，删除旧 AndroidX 风格 RecyclerView 内核、入口及专属旧测试。
2. 收齐 ElScrollView 的用户可见能力，确定 ElScrollable 的职责和验收场景，为下一轮实现准备依据。

本地 agent 首轮执行到“旧 RecyclerView 已删除、功能清单已核实、剩余设计问题已明确”为止。本文后半部分描述新壳的方向与后续验证顺序，不要求在清理提交中同时重写 ElScrollView。

**当前结论：可以安排退休，但不能直接删除旧目录。** ElSliverRecyclerList、ElSliverRecyclerGrid 及 masonry 已覆盖自然尺寸回收布局；ElSliverList 提供常驻自然尺寸文档。它们不逐项兼容旧 Adapter、ViewHolder、LayoutManager API。迁移目标是保留实际需要的体验，不是复刻旧接口。

### 已确定的约束

- 新 ElScrollable 的内容拖拽识别和事件分发必须接现有 El 自定义事件系统。不要让官方拖拽识别器与 El 识别器重复处理同一输入。
- 继续遵守官方 Viewport / RenderSliver / SliverConstraints / SliverGeometry 规范。内容布局交给官方 Viewport 和具体 Sliver。
- 保持自然尺寸；不增加 itemExtent、精确高度回调或要求业务预先计算卡片高度。
- 回收槽位使用标准 ValueListenable；稳定业务结构只更新变化的叶子。不重新引入 Adapter、Selector、payload、共享池管理等公共体系。
- 不参考 ElRecyclerView2。
- 删除 RecyclerView 阶段保留 ElScrollView、ElTabView、事件系统、独立物理与平滑滚动模块。新壳验收之前不顺手删除它们。
- 验证只运行本次改动涉及的无头 Flutter 测试。不得运行 flutter run / drive、真机或桌面前台测试、全量 benchmark；不得操作用户正在运行的应用。

## 2. 阶段 A：删除旧 RecyclerView

### A1. 核对实际依赖

当前旧组件的实际入口是 package:flutter_base/recycler_view.dart，示例主要使用 rv.RecyclerView / rv.Adapter / rv.ViewHolder，不应只搜索 ElRecyclerView 类型名。

需要核对：

- lib/recycler_view.dart
- lib/flutter.dart 的旧 export
- lib/src/flutter/views/recycler_view/
- lib/src/flutter/slivers/recycler/sliver_recycler.dart
- example/lib/src/widgets/doc_scroll_view.dart
- example/lib/src/pages/examples/catalog.dart
- example/lib/src/pages/examples.dart
- example/lib/src/utils/router.dart
- example/lib/src/pages/settings.dart
- example/lib/src/pages/setting/scroll_test2.dart
- example/lib/src/state/index.dart
- test/ 与 example/test/ 中的旧实现引用

先建立“迁移、重复场景下线、保留”三种明确结果，再删文件。不要用“删入口后编译通过”代替行为迁移。

### A2. 迁出 Sliver 的硬依赖

目前的依赖为：

- sliver_recycler/sliver_recycler.dart 导入 ../recycler_view/extent_index.dart。
- extent_index.dart 导入旧 work_probe.dart，并在 assert 中记录前缀查询次数。

执行：

1. 将尺寸索引迁到 lib/src/flutter/slivers/recycler/extent_index.dart，继续使用现有算法。
2. 把它收为 Sliver 内部实现；若采用 part，使用私有类型，避免从公共 Sliver 库泄漏辅助类。
3. 更新 sliver_recycler.dart 与 grid_geometry.dart 中的引用和说明。
4. 移除对旧 RecyclerWorkProbe 的依赖。不要为了保留一项旧计数器搬入整套性能探针。
5. 删除仅供旧 Adapter 使用、且新布局没有调用的结构通知方法时，保持测量、类型估值、前缀和、偏移反查的现有语义。
6. 先验证新 Sliver 相关局部测试，再继续清理旧目录。

不能改变刚修复的几何规则：普通重建保持测量缓存；远跳没有真实旧可见锚点时保留输入像素；新类型估值不回溯改写已生成前缀；总范围可以随实际补测合理更新。

### A3. 迁移文档宿主，并明确它的挂载模型

本计划选择：**文档设置中的旧 RecyclerView 模式替换为 ElSliverList 常驻文档模式**。已有 officialVirtual 和 elScrollView 模式继续保留，承担虚拟文档对照。

修改：

- example/lib/src/widgets/doc_scroll_view.dart
- example/lib/src/state/index.dart
- example/lib/src/pages/settings.dart

实施要点：

1. 新模式使用 CustomScrollView + SliverPadding + ElSliverList，沿用现有 _official 控制器、padding、gap、headerCount 和 _item 构建逻辑。
2. 保留每个逻辑小节的独立 GlobalKey、状态及交互；目录通过已挂载小节的 context 调用 Scrollable.ensureVisible。
3. 删除 _recycler、_DocItemsAdapter、_DocItemHolder、仅服务旧模式的 _DocItemBuilderScope，以及旧 scrollToPosition 分支。
4. 模式名称、界面文案和测试明确标为 ElSliverList，不能继续显示为“回收列表”。
5. 它是常驻模式：重复倍率会增加实际挂载量。旧“20 倍压力仍只挂载附近小节”的断言继续用于虚拟模式，不套用到常驻模式。
6. 父级更新 itemBuilder 后正文必须更新；预测返回不能重置阅读位置；目录远跳和跨段选择仍有效。

**缓存迁移：** DocScrollMode 使用 ElEnumSerialize 按 enum.name 存储，未知 name 返回 null，Obs 再回落默认值。直接删除 recyclerView 不会产生枚举 index 错位，但会让旧选择静默回落 ElScrollView。应在既有设置初始化/读取入口将键 example.settings.docScrollMode 的精确旧值 'recyclerView' 定向迁到新模式名（建议 sliverList）；其它 name 原样保留。不要为此修改通用序列化器。

注意：这里的 ensureVisible 有效，是因为 ElSliverList 的目标已经挂载。不要将它描述为能直接定位任意尚未挂载的回收条目。

### A4. 收敛示例，保留独立业务场景

旧分组在 catalog.dart 的 recyclerExamples 中，共 15 个入口；examples.dart 展示它，router.dart 将其加入路由。home.dart 当前已有新的 Sliver 入口，不需要因清理而重写。

迁出的业务页面放到现有 examples/ 下独立主题目录，目录名不再绑定旧 RecyclerView。更新 catalog、菜单分组和路由。保留独立场景原有路由 key 可以减少深链变化，不应把路由字符串里含 recycler 当成继续依赖旧内核。

| 旧场景 | 执行方案 | 迁移验收 |
| --- | --- | --- |
| rectangles.dart、text.dart | 新 sliver_recycler.dart 已有对应负载，合并仍缺少的有效断言后下线重复页 | 新入口可达，滚动和状态更新有效 |
| cards.dart | 新页面已有复杂卡片负载，下线旧内核专属性能对照和统计 UI；保留仍有价值的绑定/交互断言 | 不把旧可见范围统计 UI 宣称为已等价迁移 |
| takeaway.dart 及其 part | 使用已有独立 sliver_takeaway/，删除旧副本；核对旧纯 RenderObject 模式仍有价值的触摸、加购、语义回归 | 分类、商家换绑、横向菜单身份、图集、加购与辅助操作正确 |
| selection.dart | 迁到 ElSliverRecyclerList；选择状态按业务 ID 保存，事件读取活索引；保留首项/末项/指定条目定位，沿用该页已有 _scrollTo 的等高业务几何 | 行点击和复选不重复触发；定位 5000 后实际目标记录可见，滚走返回后选择状态正确 |
| social_feed.dart | 迁出记录与卡片，用 Listenable 更新长文展开、投票等局部状态 | 展开、投票、图片与事件始终对应当前记录 |
| chat.dart 的聊天/实时聊天 | 先把消息存储从 Adapter 解耦；复用已有官方分支，整理为 CustomScrollView + 官方 SliverList，保留 reverse、findChildIndexCallback 与按 ID 的锚点恢复 | 历史前插、流式增高、底部跟随、离底未读行为均保留 |
| orders.dart | 用 ElSliverRecyclerList；复用 _changeHead 已有的按订单 ID 和偏移补偿逻辑，去掉 Adapter 通知耦合 | 批次头插/头删后同一订单留在原阅读位置，选择和进度不串绑 |
| media.dart 的视频/相册/瀑布流 | 保留本机读取、授权、缩略图队列、预览与播放；迁出媒体业务，布局使用新 Grid/Masonry | 自然尺寸、媒体身份、预览返回、缓存与过期结果处理正确 |
| product_waterfall.dart | 保留商品、450 ms 后图片尺寸揭晓、详情返回；删除“旧 RecyclerView 与官方实现互切”的比较器，统一到现有 Masonry | 普通重建/返回不跳，真实列数或内容变化不偷换为回到顶部 |
| rich_document.dart | 迁出源码展开、小节交互和目录业务，正文采用 ElSliverList | 离屏定位、展开状态和文本选择有效 |
| spike.dart | 将单帧工作注入控制与负载迁入现有 Sliver 对照页，再删除旧容器适配 | 工具仍能注入指定工作量；本轮不运行压力基准 |

额外入口：settings.dart 仍打开 setting/scroll_test2.dart 的旧 200 色块页。让该入口指向已有 Sliver 色块负载，或同步删除这个重复入口；对应 scroll_test2_test.dart 一起更新。

#### 聊天与订单的内容身份

当前 ElSliverRecycler 的可见锚点以 index 表示，不能自动理解前插后“哪个新 index 仍是原消息”。这不是未来 ElScrollable 能自动解决的问题。

- 聊天采用上述现有官方 Sliver 内容路径，是为了直接保留既有行为，不声称该路径具备 ElSliverRecycler 的回收性能。
- 不为迁移恢复整套 stable ID / notifyItemRangeInserted 公共协议。
- 订单若复用页面自身已知行高的补偿，这是业务层现有逻辑；不得变成组件要求传入 itemExtent，也不得把动态卡片强制固定高度。
- selection.dart 的既有 index * _selectionExtent 定位同样只适用于该页现有等高内容，不推广成动态高度列表的通用定位能力。
- 如果执行者另选 ElSliverRecycler 作为聊天布局，必须先补齐并通过“同一业务记录的屏幕位置保持”验收，不能只换组件名。

#### 媒体跨列与资源

media.dart 的 SpanSizeLookup 实际只用于第一个整宽横幅：拆成 SliverToBoxAdapter 横幅和后续 ElSliverRecyclerGrid 即可。同步修正内容索引、Hero ID 和点击对象，不为一个横幅新增通用跨列 API。

media.dart、media_source.dart、media_cards.dart、media_preview.dart、album_thumbnails.dart 需要作为一组迁出；同步调整 part / part of。移除旧精确尺寸回调路径，未知内容补测允许更新总长度。

### A5. 回收绑定需要额外检查的一项行为

旧 viewport.dart 在跨记录绑定时使用通用 ReuseAnimationScope / runRebind，防止上一条记录的视觉状态动画到下一条记录。当前 Sliver 槽位没有同样的显式接线。

迁移复选、开关、进度卡片时检查：

- 换绑到不同记录后，没有旧记录的过渡残留。
- 同一记录的正常状态更新仍能动画。
- 如需修正，复用已有通用作用域，限定在换绑路径；不要恢复 Adapter 生命周期体系。

通用工具 lib/src/flutter/utils/internal/reuse_animation.dart 不属于旧内核删除范围。

### A6. 精确删除范围与保留例外

以下范围在依赖和行为迁移完成后删除：

- lib/recycler_view.dart
- lib/src/flutter/views/recycler_view/：包含旧 Dart 实现、诊断 JSON、性能报告及 README。
- test/flutter/views/recycler_view/：先迁走仍适用的行为断言，再删除这 16 个旧内核测试。
- example/lib/src/pages/examples/recycler_view/：独立场景与媒体文件迁出后删除；旧性能报告随目录删除。
- lib/flutter.dart 中 export 'recycler_view.dart'; 这一条旧导出。

不保留旧公共入口的兼容空壳，不顺手删除新 Sliver 导出或 ElScrollView 导出。

**必须保留：**

- example/lib/src/widgets/example_image.dart
- example/lib/src/widgets/example_scrollbar.dart
- example/lib/src/widgets/plain_scroll.dart
- example/lib/src/pages/examples/sliver_takeaway/
- example/lib/src/pages/examples/bibi/
- example/assets/recycler_cards/ 整目录及 LICENSE、README；新外卖使用 takeaway-food.webp，新卡片使用 owl*.jpg，Bibi 与新视频负载使用 bili_home.webp。
- example/pubspec.yaml 中仍被上述资源使用的 assets 声明。

RecyclerExampleScrollbar 的名字不代表它依赖旧内核。无需为了清理进行无关重命名。

### A7. 旧测试不能按文件名前缀批删

按行为处理以下测试；可以迁到新的语义化文件名，随后删除旧文件。

| 当前测试来源 | 保留/迁移内容 |
| --- | --- |
| recycler_doc_page_test.dart、recycler_scrollbar_test.dart | 文档目录、重复倍率、闭包更新、预测返回、真实滚动条交互 |
| recycler_chat_el_scroll_test.dart、recycler_chat_document_test.dart、recycler_long_examples_test.dart | 头插、阅读锚点、末端跟随、流式增长、文档入口；保留仍有效的 ElScrollView 分支 |
| recycler_feed_orders_test.dart | 动态流交互、订单定向刷新、批次增删锚点与任务停止 |
| recycler_product_waterfall_test.dart | 图片补测、远拖、详情返回；删除比较器后移除仅依赖旧/官方互切的断言 |
| recycler_media_test.dart、recycler_album_thumbnail_test.dart | 本机媒体、路由、缩略图队列、过期结果及缓存 |
| recycler_selection_row_tap_test.dart、recycler_el_examples_test.dart | 事件消费、复选联动及仍有效的 ElScrollView 状态 |
| recycler_takeaway_test.dart、recycler_takeaway_render_test.dart | 对照 sliver_takeaway_page_test.dart 补齐尚未覆盖的行为，特别是纯 RenderObject 卡片交互 |
| recycler_waterfall_scrollbar_test.dart | 通用稳定性合并现有 Sliver 回归，媒体专属部分随媒体页迁移 |
| recycler_cards_test.dart、recycler_text_test.dart、recycler_rectangles_test.dart、recycler_spike_test.dart | 合并仍保留的负载与业务行为，删旧页面专属断言 |
| plain_scroll_test.dart、bibi_grid_performance_test.dart | 更新旧页/旧 media 对照导入，保留普通滚动与 Bibi 有效用例；不执行重负载性能轮次 |
| global_state_cache_test.dart、global_state_cache_invalid_test.dart、scroll_settings_test.dart | 播种旧 enum.name 的定向迁移、其它模式不变、无效值回退和新菜单文案 |
| scroll_test2_test.dart | 跟随设置页重复入口的处理结果更新 |

以下纯旧实现成本/结构诊断可在有效行为已迁移后下线：recycler_card_create_update_cost_test.dart、recycler_leaf_build_test.dart、recycler_official_comparison_test.dart 及其 recycler_comparison_profile.dart part、recycler_row_performance_test.dart、recycler_row_reuse_test.dart、recycler_text_cost_test.dart、recycler_takeaway_initial_rebind_test.dart、recycler_takeaway_performance_test.dart。

不要通过移除仍有效的失败断言来宣称迁移完成。旧实现私有字段、内部探针和固定总长假设不属于新实现必须兼容的合同。

### A8. 退休完成条件

- 运行代码和保留测试不再 import/export 旧 recycler_view.dart 或旧内核目录。
- 新 Sliver 的尺寸索引已独立；自然尺寸、复用及上一轮稳定性回归仍通过。
- 保留的页面、目录、设置和路由可达；独立业务场景没有因清理丢失。
- 聊天/订单按业务记录保位，文档定位正常，商品和媒体返回正常。
- 真实滚动条按住、远拖和反向微调正常；停住后再松手保持位置，带速度松手继续按标准滑块规则完成惯性。新 Grid/Masonry 示例保持现有 stopOnThumbRelease=false，不通过禁用惯性让稳定性测试通过。
- 共享图片、授权文件及资源声明保留。
- Flutter 分析、涉及文件格式和 git diff --check 通过。

只检查有效依赖是否清零；历史说明、保留的路由 key、类名或资产名中出现 recycler 不等于仍依赖旧内核。

## 3. 阶段 B：ElScrollView 功能基线

以下已经完成初步源码盘点。执行时用现有调用和测试补充“保留、由 Sliver 承担、暂未覆盖”状态，不把旧参数表和内部类表直接当作新 API。

本表实现路径相对于 lib/src/flutter/views/scroll/；测试路径相对于 test/flutter/views/scroll/，另行标注的除外。

| 能力 | 必须保留的表现 | 当前实现与验收入口 |
| --- | --- | --- |
| 触摸与自定义事件 | 按轴识别、接住惯性、同手势反向、多指/旧指针隔离、真实采样时间和速度；停顿后松手不沿用旧速度 | common/render/scroll_viewport_base.dart；common/pointer/scroll_drag_controller.dart；input_test.dart |
| 默认动作取消 | 用户事件先执行；dragStart 可取消滚动，dragEnd 取消只阻止起飞；dragCancel 和卸载必须完成清理；拖动及触摸惯性避免误触卡片 | _chainDefaultDrag；input_test.dart 的默认动作取消和触摸穿透用例 |
| 鼠标与设备配置 | 尊重 dragDevices；桌面默认给拖选保留鼠标，业务可显式开启鼠标内容拖动；滚轮与鼠标移动分开 | common/viewport/scroll_position_binding.dart；input_test.dart、selection_test.dart |
| 平滑滚轮 | 目标累加、运行中接续、移动鼠标不终止；正文/滚动条/转发区域采用同一策略，输入仅消费一次；横向修饰键按现有配置 | smooth_scroll/；physics_test.dart、smooth_config_test.dart、nested_test.dart |
| 平滑配置继承 | $absent 表示继承、null 表示关闭；切换算法或配置不重挂内容 State | scroll_view.dart、ElViewProvider；smooth_config_test.dart |
| 触控板 | PointerScroll 与原生 PanZoom 分别处理；保留首段、轴分量和时刻，原生 pan 不伪装成滚轮再平滑 | ScrollViewDragController、_handleScrollPanZoom*；input_test.dart、nested_test.dart |
| 位置与控制 | 一份真实 ScrollPosition；jumpTo、animateTo、停止、最新命令接管；方向、reverse、RTL；控制器工厂、attach/detach 与配置换绑 | common/viewport/scroll_engine_position.dart、scroll_position_binding.dart；controller_test.dart、core_test.dart |
| 物理与边界 | 复用 Clamping/Bouncing/Browser 算法；阻尼、回弹、反向、连甩策略按实际配置；bibi 保持显式 Clamping | common/physics/；physics_test.dart、clamping_physics_test.dart |
| 键盘与焦点 | 主焦点上的方向/Page/Home/End；子控件持焦不抢键；未消费事件传祖先；拖动收起软键盘 | _handleFocusedKey、handleKeyboardScroll；input_test.dart |
| 通知与局部观察 | 开始/更新/结束、metrics、活动变化；输入结束和全部运动 settled 分开；无订阅时不建多余观察链，tick 不重建整页 | scroll_state.dart、effects/scroll_mixin.dart；core_test.dart |
| 滚动条 | 各平台外观、显式关闭、拖柄接管、轨道点击、步进、滚轮转发；Windows inset 首帧正确 | scrollbar/；scrollbar_test.dart；新 Sliver 真实 thumb 回归 |
| 普通嵌套与显式协作 | 同轴、交叉轴和效果协作规则分开；一次输入量守恒；取消、释放和惯性归属一致 | common/nested/、effects/nested_scroll_mixin.dart；nested_test.dart |
| 刷新 | Android 悬浮/iOS 让位、leading/trailing、reverse、空内容、阈值、取消、停靠和回位；刷新拖动不穿透点击 | refresh/；refresh_test.dart、refresh_physics_test.dart |
| 效果 | sticky、折叠、大标题、stretch、吸附、reveal、parallax、progress；依据自然几何，只更新相关局部 | effects/；effects_test.dart、large_title_reattach_test.dart |
| 定位、选择与无障碍 | showOnScreen/reveal、正确宿主的选区自动滚动、语义滚动动作和真实范围；常驻/虚拟内容遵守实际挂载边界 | common/render/scroll_semantics.dart；selection_test.dart、render_test.dart、../sliver_list_test.dart、../selection/virtual_mounted_selection_test.dart |
| 生命周期 | 活动中卸载、GlobalKey 重父化、路由变化、尺寸变化、controller/physics 更换后无重复 attach、旧回调回写或死 context 通知 | core_test.dart、content_resize_test.dart、unmount_metrics_notification_test.dart、session_observer_unmount_test.dart、drag_owner_unmount_probe_test.dart |

补充边界：

- 旧 ElScrollView 支持双轴。新壳首先验证单主轴 Sliver 通路；双轴的实际调用、方案和覆盖状态必须单独登记，不能默认一维 Sliver 自然支持完整双轴滚动。
- 像素滚动属于壳；scrollToIndex、可见项、内容插删锚点、pinToEnd 意图需要内容几何依据。不能为了继承旧 API，让壳继续展开 List/Grid 和维护条目高度索引。
- 常驻内容全选可包含已挂载离屏项；虚拟内容不为了复制重新构建已销毁条目。
- 当前 ElScrollDeltaInterceptor 返回消费量，而 ElNestedScrollMixin 的部分钩子返回剩余量。新设计选定一个明确约定，不把两种量混用。

### 普通嵌套与 bibi 协作必须分清

普通嵌套触摸：内层已取得本次手势后，滑到边界不把同一手势或其惯性甩给祖先；下一次手势在边界朝不可滚方向起手时，才允许外层接管。交叉轴不能在同一手势中途补启动，反向应由原宿主响应。以 nested_test.dart 的对应行为用例复核。

bibi 页头和正文属于显式协作：同一笔输入、同一次惯性可以先走页头行程再进入正文。这个需求不能反过来改变普通嵌套的边界规则。滚轮和原生 pan 的行为也要按设备单独验证。

## 4. 用 bibi 作为新壳的完整场景验收

源文件：example/lib/src/pages/examples/bibi/ 下的 bibi.dart、header_motion.dart、feed.dart、chrome.dart、plain.dart。

| 场景 | 必须保留的行为 | 主要归属 |
| --- | --- | --- |
| 页头与正文共享行程 | 搜索栏先消费剩余的 58 px，余量进入正文；短甩能沿同一次惯性跨越折叠边界 | 壳提供输入/运动协作，页头效果消费有限行程 |
| 吸附 | 零速慢拖按中点吸附；短甩按真实运动方向；滚轮空闲后吸附；轻点不取消，实际新输入才接管 | 效果层，依赖可靠的释放/settled 信号 |
| 视口稳定 | 折叠时平移正文视口，保持其布局尺寸与惯性活动；不在每帧重建列表或改变高度 | 页面布局与效果 |
| 横向嵌套 | 正文纵拖不误启动频道；卡片横拖切频道；banner 先消费，从首端向外的新手势可交频道 | 自定义事件/嵌套规则与 ElTabView 协作 |
| 频道切换 | 旧频道失去驱动共享页头的权利；保活不等于仍有运动权限；懒挂载频道恢复位置，Home 同时归零正文并展开页头 | 页面负责同步策略，壳负责接管与取消 |
| 刷新 | 反向撤销/取消不触发；当前频道、页头展开、正文顶部且不横向翻页时显示；离开顶部隐藏圆盘；请求完成后等回顶停稳再替换数据 | 刷新效果 + 页面业务 |
| 常驻追加 | plain.dart 的初始 20 张、近底部追加 10 张，以及旧卡片继续留树的行为 | ElSliverList 与页面加载逻辑 |
| 频道栏 | 横向位置与菜单/搜索栏边界联动保持正确，不把正文折叠变成一次多余频道横滚 | chrome.dart 的页面布局 |

已有主验收文件：

- example/test/bibi_home_test.dart
- example/test/bibi_plain_test.dart

优先迁移“慢拖只移动页头”“短甩跨过折叠边界”“轮播首端交给频道”“换频道保持纵向位置”“刷新中离开顶部”“退出页面取消刷新手势”等行为用例。

bibi 当前没有直接使用 ElNestedScrollMixin；支持它不意味着必须原样移植所有 Nested Mixin 内部。频道请求、数据替换和同步策略继续留在页面。

## 5. ElScrollable 的职责与后续验证顺序

### 5.1 先固定边界，不先堆公共 API

| 层 | 职责 |
| --- | --- |
| ElScrollable | 现有 El 事件入口、输入归属与取消、真实 position、物理/平滑输入桥接、焦点/键盘/通知/生命周期，以及最少的效果协作能力 |
| 官方 Viewport | 根据同一个 ViewportOffset 布局、绘制与命中 Sliver，反馈视口/内容范围并处理布局修正 |
| 内容 Sliver | 常驻或虚拟挂载、自然尺寸、复用、列表/网格/瀑布流、内容几何及锚点 |
| 效果与外观 | 页头折叠、吸附、刷新和滚动条；观察或消费自己负责的行程 |
| 页面 | 频道同步、刷新结果应用、消息未读、加载更多等业务策略 |

不把 controller、physics、pointer listener 和拖拽状态加回 ElSliverRecycler。也不让 ElScrollable 识别 Adapter、List/Grid 内部项或为每个业务效果内置状态机。

可复用现有 ElScrollBehavior、独立 ScrollPhysics、ElSmoothScroll 和 SmoothPointerScrollController；逐项检查依赖后接入。不要整包复制 common/ 或 virtual/。

不整体移植 SegmentPlan、FlatSegmentItemList、旧虚拟挂载/窗口重算、旧坐标投影、旧整套 slot/router/transaction/coordinator 类层级。保留它们曾经解决的具体行为问题，由新边界下的最小实现承担。

### 5.2 后续实现先验证最短通路

下一轮实现按下面顺序推进；本计划本身不写这些实现：

1. El 自定义拖拽事件驱动唯一真实 ScrollPosition，官方 Viewport 使用它作为 ViewportOffset，先承载一个官方 Sliver 和一个 El Sliver。
2. 验证 start/update/end/cancel、hold、惯性和新命令接管；输入不被两个识别器、两套阈值或两个物理阶段重复消费。
3. 接鼠标平滑滚轮、PanZoom 和真实滚动条；各入口互相接管后旧目标不会恢复。
4. 验证 Sliver 混排、reverse/RTL、窗口变化与 scrollOffsetCorrection。布局修正不能当成新的用户输入或重置正在进行的手势。
5. 验证焦点、showOnScreen、语义滚动、选区和卸载；再接 bibi 的有限页头行程、吸附、频道交接和刷新。
6. 核对剩余 ElScrollView 调用和能力矩阵，覆盖后再安排替换旧 ElScrollView。

官方 Sliver 兼容与官方 Scrollable 祖先发现是两个要分别验证的接口。ScrollController/ScrollPosition 可复用，不代表自定义宿主会自动被 Scrollable.of 或 Scrollable.ensureVisible 找到。首个桥接实验必须明确这些调用、第三方滚动条与选择系统的实际支持方式；不可写“完全兼容”后留给页面补丁，也不要为未知需求预建多层兼容框架。

### 5.3 核心不变量

- 任意时刻正文只由一个有效活动写入同一真实 position；新手势、滚动条或程序命令接管后，旧活动不得回写。
- 采用消费量约定时，输入量 = 效果消费 + 正文消费 + 剩余量，方向和范围正确；物理阻尼不等于可再次交给祖先的原始输入。
- 指针释放、取消和所有运动结束是不同事件；终态清理不可被 preventDefault 跳过。
- 普通 rebuild、路由转场和临时重父化不应重建有效内容或丢失测量。
- 每帧更新保持在 position、布局/绘制和真正订阅的局部；不靠整页 setState 驱动滚动。

## 6. 验证、交付与停止条件

### 局部验证顺序

1. 核心解耦后：运行 test/flutter/views/sliver_recycler_test.dart、sliver_recycler_natural_size_test.dart、sliver_recycler_grid_test.dart、sliver_recycler_masonry_stability_test.dart；绑定接线有变时加 sliver_recycler_reuse_test.dart、sliver_recycler_text_test.dart。
2. 文档迁移后：运行 sliver_list_test.dart，以及迁移后的文档、设置、缓存、滚动条页面用例。
3. 业务页迁移后：按涉及页面运行聊天、订单、媒体、商品、选区、外卖等局部回归。只更新内部实现断言，保留行为断言。
4. 最后运行新 Sliver 页面入口及稳定性回归，检查真实预测返回通道和真实 thumb 拖动；不以 controller.jumpTo 代替所有滚动条用例。
5. 对涉及文件分析和格式化，检查 git diff --check 与剩余 import/export。

测试命令采用当前包布局，例如根目录执行 flutter test test/flutter/views/sliver_recycler_masonry_stability_test.dart --no-pub --concurrency=1；example 包内执行 flutter test test/sliver_recycler_masonry_stability_test.dart --no-pub --concurrency=1。运行迁移后的新文件路径，不照搬 scroll 测试 README 中过时的 packages/el_ui 路径。

可分工：核心依赖解耦、文档/设置迁移、独立业务示例迁移并行；catalog/router/export 汇总和最终删除由一个 agent 统一完成，避免互相覆盖。

### 本地 agent 首轮交付

- 一份清晰的旧页面到新入口映射，以及实际删除清单。
- 已独立的新 Sliver 尺寸索引、已迁移页面、已清理旧导出/实现/专属测试。
- 按业务记录保位、目录定位、媒体/商品返回和真实滚动条的验证结果；未覆盖项明确列出。
- 在本文能力矩阵补充当前调用与覆盖状态，列出 ElScrollable 最小桥接尚待决定的问题。
- 此时停止，不把 ElScrollable 的完整重写混入退休旧 RecyclerView 的提交。

当前源码已有的测试结果不能替代迁移后的验证；无头测试耗时也不能当作真机帧耗时。

## 7. 依据

仓库依据：

- lib/src/flutter/views/recycler_view/：extent_index.dart、adapter.dart、viewport.dart、grid_layout_manager.dart。
- lib/src/flutter/slivers/recycler/ 与 lib/src/flutter/slivers/list/ 当前实现和 README。
- example/lib/src/pages/examples/recycler_view/ 中仍运行的页面；catalog.dart、router.dart、settings.dart、doc_scroll_view.dart。
- lib/src/flutter/views/scroll/README.md、scroll_view.dart、scroll_state.dart、common/、effects/、refresh/、scrollbar/。
- example/lib/src/pages/examples/bibi/ 与上述行为测试。
- 历史提交 df0ff06、632b025，以及审计基线 747b8a5；自然尺寸列表不能通过恢复旧精确高度回调或冻结范围来掩盖跳动。

官方接口依据（执行时以本机 Flutter SDK 为准）：

- [Viewport](https://api.flutter.dev/flutter/widgets/Viewport-class.html)：视口接收 ViewportOffset 和 Sliver 子项。
- [ViewportOffset](https://api.flutter.dev/flutter/rendering/ViewportOffset-class.html)：pixels、范围反馈和布局期 correctBy。
- [SliverGeometry](https://api.flutter.dev/flutter/rendering/SliverGeometry-class.html)：scrollOffsetCorrection 要求父视口修正后重新布局。
- [ScrollPosition](https://api.flutter.dev/flutter/widgets/ScrollPosition-class.html)：位置、物理、活动、控制器和通知的桥接。
- [ScrollPosition.drag](https://api.flutter.dev/flutter/widgets/ScrollPosition/drag.html)：启动 drag activity，不等同于替业务决定手势识别。
- [Scrollable](https://api.flutter.dev/flutter/widgets/Scrollable-class.html)：官方交互宿主与 of / ensureVisible 祖先发现的边界。
