# 声明扩充范围

## 准入原则

只有桌面端与移动端都存在合理使用场景、职责一致的组件才能定义为通用接口。不能仅因某一端已有实现，或者技术上能够在另一端绘制，就将组件加入公共层。品牌之间可以有外观差异，但不应依赖空实现、忽略参数或替换为另一种组件来满足接口。

端专属导航、布局协议和业务综合页面由对应品牌提供；未迁入的实现继续留在源库，本次不新增品牌实现。已有品牌实现暂未适配某个通用组件，不影响它的通用语义；声明与实现接入仍分别处理。

## 已覆盖

本阶段仅定义公开参数、数据模型、回调与 Builder 登记。新增 Widget 的 build 只转交声明，不提供默认布局、绘制、状态绑定、命令、动画或手势；33 个新 Builder 默认均为 null。两端主题不自动安装新实现。

- 基础内容：Card、LoadingIndicator、Icon、ListTile / ListTileGroup。
- 内容定位与流程：Anchor、Affix、Steps / Step、Backtop。
- 数据与表单：Avatar / Group、Calendar、Carousel、Collapse / Item、Countdown、Descriptions、Empty、Pagination、Progress、Rate、Segmented、Slider、Skeleton / Item、Statistic、Tabs / TabBar、Timeline / Item。
- 展示与反馈：Alert、Result。

Radio / Checkbox 的状态声明新增可空 isLast：null 明确表示当前宿主尚未提供布局信息。本阶段不推导末项、不修改叶子行为，也不启用此前跳过的品牌皮肤。

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

ElDivider、ElBadge、ElForm 及各通用 View 已有公共接口，继续复用；不在本阶段重建它们。移动端分割线的 align / dashed 差异仍由 MyDivider 保留，未向现有具体 ElDivider 塞入不生效的参数。

ElLoading 是已有的旋转包装器，新加载指示器使用 ElLoadingIndicator；二者职责和名称独立。ElTabController 等现有模型与控制器继续复用。ElListTile<T> 与 ElListTileGroup<D> 复用 ElModelValue 持有完整泛型模型，品牌 Builder 保留泛型；移动端已实现列表布局、选择标记和弹出菜单，并移除通用目录中的旧 MyListTile / MyListGroup 简版入口。

平台 ContextMenu、Refresher 是现有协议的品牌实现；HTML 文本、滚动效果、过渡和内容准备属于便捷包装或机制，不作为新品牌组件登记。ElApp / ElTheme 属品牌启动与主题基础，继续使用 MyTheme / ElDesktopTheme，不新增通用主题宿主。

## 留到服务阶段

Message、Toast、Dialog、反馈 Drawer、Prompt 及 Router 的 Service、Handle、Ext 和动作类型不在本次定义。

组件入口继续使用 index.dart，目录内 README.md 记录参数边界。保留的通用声明可经 flutter_base.dart、mobile.dart 或 desktop.dart 导入；实际使用前必须显式提供对应 Builder。
