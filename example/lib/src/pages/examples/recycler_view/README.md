# RecyclerView 长列表示例

入口为「示例 → RecyclerView」，两端共用目录和页面。纯文本可通过 `/examples/recycler-text` 直接打开，外卖页为 `/examples/recycler-takeaway`。

## 万条纯色矩形

第一项为 `/examples/recycler-rectangles`。三种滚动容器都使用一万条高 64 的双色交替矩形，每条仅由一个叶子 RenderBox 绘制。RecyclerView 按颜色回收，换绑没有数据更新。可在「帧耗时记录」选择「万条纯色矩形」采集 UI 和 Raster 耗时，作为轻量内容的滚动基线。

## 复杂滚动对照

| 示例 | 路由后缀 | 可重复的操作 |
| --- | --- | --- |
| 社交动态流 | `recycler-social-feed` | 快滑穿过长文、九宫格、转发与投票，展开正文后反向滚动 |
| 实时群聊 | `recycler-live-chat` | 先滚离底部，再播放或单步执行八拍脚本，同时插入历史、收消息和增长气泡 |
| 订单管理台 | `recycler-orders` | 勾选订单，播放八秒压力脚本，同时滚动并增删头部订单 |
| 商品瀑布流 | `recycler-product-waterfall` | 延迟释放 12 张图的尺寸，拖动滑块，再打开详情并返回 |
| 富文本文档 | `recycler-rich-document` | 展开源码，切换示例状态，再用目录从首节跳到第 240 节 |
| 单帧尖峰压力 | `recycler-spike` | 选择 4、8、12、20 ms，在拖动、惯性或 600 ms 等速脚本中注入一次 |

路由后缀拼到 `/examples/` 后即可打开。线性示例共用同一份业务内容，菜单切换 `ListView`、`ElScrollView` 和 `RecyclerView`。商品瀑布流使用两列 `SliverGrid` 与 `StaggeredGridLayoutManager`，初始列布局可对照，图片补测后分别沿用各自的列分配策略。

「帧耗时记录」中可选这六个页面。单帧尖峰在 Timeline 标记 `RecyclerSpike.work`，可按容器、阶段和注入时长关联轨迹。屏幕呈现间隔从系统轨迹读取，应用的 UI、Raster 耗时由记录器采集。

## 万条纯文本列表

- 共 10,000 条，内容只有 `ElView(child: 'Item - $index')`，index 从 0 开始。
- 不添加行样式、固定高度、内边距或额外卡片，作为纯文本渲染基线。
- 沿用三种容器和滚动条切换；官方 ListView 不传 itemExtent，ElListView 不开启 fixedSize。

## 万条复选列表

- 创建 10,000 条不同编号、标题和描述的业务记录，按需挂载条目 Widget。
- `Adapter` 提供稳定 ID，`ViewHolder` 保留结构，`onBindViewHolder` 更新本次记录和选中状态。
- 勾选状态存在按业务 ID 索引的集合中，离屏或复用 holder 不会把旧状态带给另一条记录。
- 标题、说明和空白处均可点击切换，复选框自身的点击不再冒泡触发第二次切换；拖动滚动不会误选。
- 导航头显示紧凑计数，图标下拉菜单提供清空、首尾跳转和按 1 开始的序号定位；输入在定位弹窗中完成，不占列表高度。
- holder 保留固定卡片、Row 与文字布局框架，绑定只更新文案、语义和勾选状态等叶子。Key 不跟数据 ID 改变。
- 不同记录且选中值不同时仅重置复选叶子，避免上一条记录的过渡动画带到新行；相同选中状态的跨记录绑定保留原复选 State，同一记录的用户勾选继续正常过渡。

## 聊天长列表

- 初始 10,000 条长短不同、方向不同的消息，从末端显示。
- 「更早 50 条」在顶部插入历史，使用稳定 ID 与范围插入通知保留当前阅读锚点。
- 底部阅读时发送或收到消息会跟随末端；阅读旧消息时保持位置，并显示新消息数量。
- 历史、模拟接收和最新消息均在导航头的图标下拉菜单里，未读量用徽标显示，不会撑高工具栏或缩小列表。
- 消息按方向使用两种结构类型，同类型重新绑定时更新正文与时间。
- 两种方向各保留气泡、LayoutBuilder、Align 和卡片结构；绑定只通知正文和时间叶子。

## 外卖商家列表

- 共 10,000 家商家，信息与每店 10–12 道餐品在访问时按固定种子生成。默认使用和 Web 外卖示例相同的 12 格离线餐品图集，整页共用一次解码。菜单可切换到原有的 Lorem Picsum 网络图片。
- 店标和固定红包位于左列，店铺信息、配送与店内横向菜单位于右列；评分、销量、起送价、地址、标签、优惠、描述和评价共同形成密集文本场景。
- 默认的组件卡片使用 `ElCard`。店名 14px，主体文字 9.5–12px，卡片内边距 8px、内容间距 4px，商品列宽 94px。
- 右上角「纯 RenderObject 卡片」独立于滚动容器切换。每张卡片只有一个叶子 RenderBox，直接绘制文字、图标和共享图集。支持菜单拖拽与惯性、加购和语义操作，切换时沿用商家数据、横向位置和购物车。网络图片只在组件卡片中提供。
- 三种外层容器共享相同商家和餐品内容，不指定整行高度；字号放大时横向菜单同步增加宽高，菜单本身按需创建餐品。
- 店内菜单位置按商家身份保存；换绑保留滚动宿主、卡片、图片与餐品槽位，只更新实际变化的叶子，停止旧活动并恢复新店的位置。内层按已知餐品宽度布局，仅挂载当前横向可见项。
- 支持分类筛选、添加餐品和清空购物车。图片未就绪时区域留白，解码后淡入。RecyclerView 关闭这个页面的同步预取，避免在可见卡片之后又准备一张隐藏卡片。
- 性能采样页增加「外卖商家列表」选项；真实帧耗时须使用目标设备的 Profile 构建，网络请求和首次图片解码也会影响首次滚动。

[外卖性能记录](TAKEAWAY_PERFORMANCE.md)包含旧源码同条件对照、实际图片缓存命中和快速滚动的无头测试，区分结构复用结论与尚未验收的生产 8ms 目标。

## 同内容容器对比

前六页的下拉菜单都提供 `ListView`、`ElScrollView` 和 `RecyclerView`，默认使用后者。两个 Grid 页面对应为官方 GridView、ElScrollView 内的 ElGridView、RecyclerView 的 GridLayoutManager；只有瀑布流没有其它滚动容器菜单。同一示例的三种容器共享相同条目内容，按需渲染。

切换容器保留勾选状态、聊天消息与输入内容，并将复选列表定位到首项、聊天定位到最新消息，从相同起点比较。复选行固定 88 高，官方列表可按真实行高精确定位；聊天的官方列表采用反向索引，顶部历史追加在远端，阅读期间收到新消息则按已挂载消息几何补偿位置。

两页不受文档页面的滚动选择或重复倍率影响；10,000 表示实际记录数量。无头测试的耗时不能代替手机 FrameTiming 或实际呈现间隔，真机是否达到约 1ms 需在 Profile 版本复测。

[真实示例行性能记录](PERFORMANCE.md)保存修复前后的内部结构复用与实际绑定工作量，不再用简化测试行代替这两个页面。

外卖相关无头回归测试：

```powershell
cd example
flutter test test/recycler_takeaway_test.dart test/recycler_takeaway_performance_test.dart --no-pub --concurrency=1 --timeout 60s
```

## Grid 视频流卡片与本机相册

- 路由为 `/examples/recycler-video-grid` 和 `/examples/recycler-gallery-grid`。视频流使用本机照片和文件名构成紧凑卡片，顶部横幅横跨全部列，点击卡片以 Hero 进入图文详情。
- 相册显示图片与视频；图片进入支持双指缩放和拖动的 Hero 预览，视频进入带控制栏的本地播放器，离开页面释放播放器，应用转到后台时暂停。
- Android / iOS 使用 [photo_manager](https://pub.dev/packages/photo_manager) 查询系统相册，并处理拒绝和部分授权。桌面使用 [file_selector](https://pub.dev/packages/file_selector) 选择文件夹，递归收集子目录里的图片与视频，跳过链接和无权访问的子目录；整个根目录不可读时显示错误。
- 所有媒体记录在首次读取时一次进入列表，滚动期间不分页、不追加、不重新枚举目录。桌面按路径排序，不逐张预读原图尺寸和文件属性；系统相册沿用媒体数据库的日期、方向与尺寸。缩略图按可见范围解码并交给 Flutter ImageCache，文件缩略图限制在 320 × 320 内，长截图也有高度上限。
- 图片原图只在详情或预览中请求，预览解码也有宽高上限。桌面视频缩略图使用 [fc_native_video_thumbnail](https://pub.dev/packages/fc_native_video_thumbnail)，播放使用 [media_kit](https://pub.dev/packages/media_kit)，缩略图失败仍保留视频入口。
- 卡片使用 ElCard，保留品牌底色；标题 13px，来源 10.5px。窄屏使用双列视频卡片和约五列相册，宽屏增加列数，字体放大后卡片页脚同步增高。

新增原生插件后需要重新构建应用，热重载无法安装这些插件。Android 已声明图片、视频与部分相册授权，iOS 已提供照片使用说明，macOS 使用所选文件夹的只读授权。

## 瀑布流

路由为 `/examples/recycler-waterfall`，使用 StaggeredGridLayoutManager。默认提供 10,000 条包内离线图片与长短文案，只挂载可见卡片；也可从文件夹切换到本机图片。本地图片沿用缩略图解码后的自然比例排版，并限制过长图片的卡片高度，不额外预读整目录原图尺寸。该页只使用 RecyclerView，图文详情和 Hero 转场与视频流共用。

媒体示例的无头检测覆盖真实临时文件、子目录、超过 64 项的一次读取、首尾定位、照片预览、正确的本地视频 URI、三种网格容器、Hero 路由、暗色和窄屏大字号：

```powershell
cd example
flutter test --no-pub --concurrency=1 test/recycler_media_test.dart test/recycler_long_examples_test.dart test/recycler_takeaway_initial_rebind_test.dart
```

原生系统授权弹窗、视频解码和实际设备帧率尚未进行前台验收；无头测试使用可替换播放器验证视频路由与 URI，不把它当作真实解码性能结果。
