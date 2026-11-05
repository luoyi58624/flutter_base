# 示例导航与页面壳

- `pages.dart` 只声明一级导航、页面工厂和现有示例入口；组件分组和叶子继续在 `pages/components/catalog.dart` 声明。
- `desktop.dart`、`mobile.dart` 只组装各自的导航结构，使用同一份声明和正文，不复制页面。
- `index.dart` 持有唯一的路由实例与断点配置，`lib/router.dart` 是统一入口。
- `utils/router.dart` 管理路径、叶子遍历、路由生成、导航标题与页面构建。
- `state/index.dart` 保存两端共用的主题和调试状态。

新增导航页面时，在 `pages/` 建立独立文件，用 `ExamplePage` 包裹正文，再在 `pages.dart` 或组件目录登记标题、图标和工厂。正文只写一份；间距和列数由可用宽度调整。

桌面壳统一绘制 `layout/desktop/navbar.dart`，导航头横跨整个窗口，左侧 logo 与标题不响应点击，右侧使用公共 `NavbarMenu`；侧栏和正文位于头部下方。移动端由 `ExamplePage` 提供标题、返回按钮和同一组公共菜单，详情仍通过根导航器覆盖底栏。

页面专用操作传给 `ExamplePage.actions`：移动端放进页面导航头，桌面端显示在正文工具区。不要另建导航头，也不要在正文里重复创建全局菜单。
