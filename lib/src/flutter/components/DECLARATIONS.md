# 通用组件范围

## 准入原则

Web 组件的逐项对应、端专属形态与待适配缺口见 [my-ui Web 接口基准](WEB_BASELINE.md)。

新增通用接口以 my-ui Web 已有组件为基准，只保留桌面端与移动端职责一致的组件。不能仅因某一端已有实现，或者技术上能够在另一端绘制，就将组件加入公共层。品牌之间可以有外观差异，但不应依赖空实现、忽略参数或替换为另一种组件来满足接口。

端专属导航、布局协议和业务综合页面由对应品牌提供。没有 Web 对应且尚无真实实现或消费者的额外空声明直接移除，不为假想场景预留接口；已有桌面输入实现、模型与视图内核继续保留。

## 已覆盖

通用层定义公开参数、数据模型、回调与 Builder 登记，模型与交互是否由公共宿主持有以各组件契约为准；品牌 Builder 提供具体外观。未登记的 Builder 为 null，各品牌主题按实际支持范围安装实现，不为缺失能力填充占位实现。

- 基础内容：Card、LoadingIndicator、Icon、ListTile / ListTileGroup。
- 流程：Steps / Step。
- 数据与表单：Avatar、Calendar、Collapse / Item、Empty、Progress、Segmented、Slider、Skeleton、Tabs / TabBar。
- 展示与反馈：Alert（对应 Web Notice）。

Radio / Checkbox 的状态声明新增可空 isLast：null 明确表示当前宿主尚未提供布局信息。本阶段不推导末项、不修改叶子行为，也不启用此前跳过的品牌皮肤。

Progress 仅保留 Web 的直线／圆环、value / max / buffer、状态和读数插槽；Skeleton 保留 loading / rows / avatar 及原正文实例。不保留无 Web 对应的 dashboard、色标、独立 SkeletonItem、AvatarGroup 或模板等空参数。Tabs 去掉增删页和侧栏形态；Segmented、Collapse、Tabs、Calendar、Slider 的绑定使用完整模型泛型，Steps 使用 Web 固定下标模型。

## 移除的额外空声明

Anchor、Affix、Backtop、Carousel、Countdown、Descriptions、Pagination、Rate、Statistic、Timeline、Result 的源码、公开导出和 Builder 登记一并移除。这些组件没有 my-ui Web 对应，当前也没有品牌实现或生产消费者；移除依据是本轮以 Web 为基准的范围，不将“Web 没有”混同为“语义上不能跨端”。

## 不进入通用接口

| 原声明 | 处理原因 |
| --- | --- |
| BottomNavigationBar | 移动端底部主导航，不要求桌面端提供同类组件 |
| AppBar / AppBarSearch | 当前契约包含移动端大标题、折叠及滚动渐变导航，搜索框也绑定该导航形态 |
| Scaffold / Sidebar / 布局 Drawer | 当前契约耦合页面骨架、桌面常驻侧栏及移动端边缘抽屉，布局由对应品牌组织 |
| NavigationMenu | 当前契约依赖 Sidebar 的折叠、抽屉和保活协议 |
| Splitter | 面向桌面多面板拖动分区，不作为移动端必备组件 |
| Breadcrumb | 面向桌面层级路径导航，不要求移动端提供相同导航形态 |
| Contacts | 包含字母索引拖动预览等交互的综合通讯录页面，按具体端与业务组织 |
| Toolbar | 当前只有空参数占位，没有明确的两端公共契约 |

上述声明、导出和 Builder 登记均移除；不创建空实现或将其重新包装成另一层公共接口。通用 ElSplitterView 等已有视图内核不在本次品牌组件声明清理范围内。

## 复用现有能力

ElDivider、ElBadge、ElForm 及各通用 View 已有公共接口，继续复用；不在本阶段重建它们。移动端分割线的 align / dashed 旧皮肤保留在内部，未向现有具体 ElDivider 塞入不生效的参数。

ElLoading 是已有的旋转包装器，新加载指示器使用 ElLoadingIndicator；二者职责和名称独立。ElTabController 等现有模型与控制器继续复用。ElListTile<T> 与 ElListTileGroup<D> 复用 ElModelValue 持有完整泛型模型，品牌 Builder 保留泛型；移动端已实现列表布局、选择标记和弹出菜单，ElCard 也已接入移动端布局。

平台 ContextMenu、Refresher 是现有协议的品牌实现；HTML 文本、滚动效果、过渡和内容准备属于便捷包装或机制，不作为新品牌组件登记。ElApp / ElTheme 属品牌启动与主题基础，使用 ElMobileTheme / ElDesktopTheme，不新增通用主题宿主。移动端具体组件与 Builder 留在 src 内部，用户通过公共接口调用。

## 留到服务阶段

Message、Toast、Dialog、反馈 Drawer、Prompt 及 Router 的 Service、Handle、Ext 和动作类型不在本次定义。

组件入口继续使用 index.dart，目录内 README.md 记录参数边界。保留的通用声明可经 flutter_base.dart、mobile.dart 或 desktop.dart 导入；实际使用前必须显式提供对应 Builder。
