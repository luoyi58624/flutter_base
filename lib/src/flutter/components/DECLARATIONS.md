# 声明扩充范围

本阶段仅补齐两端已有普通组件所需的公开参数、数据模型、回调、控制器协议及 Builder 登记。新增 Widget 的 build 只转交声明，不提供默认布局、绘制、状态绑定、命令、动画或手势；新 Builder 默认均为 null。两端主题不自动安装新实现。

## 已覆盖

- 基础与布局：Card、LoadingIndicator、Icon、Splitter、ListTile / ListTileGroup、AppBar / AppBarSearch、Scaffold、Sidebar 协议、布局 Drawer。
- 导航：Anchor、Affix、Breadcrumb / Item、BottomNavigationBar、NavigationMenu、Steps / Step、Toolbar、Backtop。
- 数据与表单：Avatar / Group、Calendar、Carousel、Collapse / Item、Countdown、Descriptions、Empty、Pagination、Progress、Rate、Segmented、Slider、Skeleton / Item、Statistic、Tabs / TabBar、Timeline / Item。
- 展示与综合：Alert、Result、Contacts。

Radio / Checkbox 的状态声明新增可空 isLast：null 明确表示当前宿主尚未提供布局信息。本阶段不推导末项、不修改叶子行为，也不启用此前跳过的品牌皮肤。

## 复用现有能力

ElDivider、ElBadge、ElForm 及各通用 View 已有公共接口，继续复用；不在本阶段重建它们。移动端分割线的 align / dashed 差异仍由 MyDivider 保留，未向现有具体 ElDivider 塞入不生效的参数。

ElLoading 是已有的旋转包装器，新加载指示器使用 ElLoadingIndicator；二者职责和名称独立。ElSplitterPanel、ElTabController 等现有模型与控制器继续复用。旧 MyListTile / MyListGroup 保留，新 ElListTile / ElListTileGroup 仅声明。

平台 ContextMenu、Refresher 是现有协议的品牌实现；HTML 文本、滚动效果、过渡和内容准备属于便捷包装或机制，不作为新品牌组件登记。ElApp / ElTheme 属品牌启动与主题基础，继续使用 MyTheme / ElDesktopTheme，不新增通用主题宿主。

## 留到服务阶段

Message、Toast、Dialog、反馈 Drawer、Prompt 及 Router 的 Service、Handle、Ext 和动作类型不在本次定义。布局 ElDrawer 与反馈抽屉服务分别处理。

组件入口继续使用 index.dart，目录内 README.md 记录参数边界。新增声明可经 flutter_base.dart、mobile.dart 或 desktop.dart 导入；实际使用前必须显式提供对应 Builder。
