# 示例导航与页面壳

- `pages.dart` 只声明综合展示、组件文档、高级示例和设置四个一级入口；组件文档的分组与深度路由继续在 `pages/components/index.dart` 声明。
- `desktop.dart`、`mobile.dart` 只组装各自的导航结构，使用同一份声明和正文，不复制页面。
- `src/router/index.dart` 持有唯一的路由实例与断点配置，应用直接导入这个文件。
- `utils/router.dart` 管理路径、叶子遍历、路由生成、导航标题与页面构建。
- `state/index.dart` 保存两端共用的主题和调试状态。

新增导航页面时，在对应标签目录下建立 `<名称>/index.dart`，用 `layout/example_page.dart` 的 `ExamplePage` 包裹正文，再在该标签的 `index.dart` 登记标题、图标和工厂。正文只写一份；间距和列数由可用宽度调整。

首页的综合展示拆在 `pages/home/showcase/`，先保留首屏和按钮两个分区。高级示例单独在 `pages/examples/index.dart` 声明，两端目录都使用移动端的 `ElListGroup` / `ElListTile`。`RouterUtil.push` 通过 `el.router.pushPage` 打开独立示例，GoRouter 共用 `el.navigatorKey`。同一份目录同时生成 `/examples/<key>` 深度路由，直接进入时在根导航器覆盖页面壳，返回后进入示例目录。设置页继续两端共用。

Android 接收 `flutter-base://example/<path>`，由 Flutter 内建深度链接处理器交给现有 GoRouter。启动默认位置只用于没有外部路径的情况。所有页面地址与启动命令见 [example README](../../../README.md)。

两端壳使用同一个根页面标识，切换断点时保留其上命令式推入的示例。独立示例复用 `ExamplePage`，自动提供本页的导航头和返回入口。

桌面壳统一绘制 `layout/desktop/navbar.dart`，导航头横跨整个窗口，左侧 logo 与标题不响应点击，右侧使用公共 `NavbarMenu`；侧栏和正文位于头部下方。移动端由 `ExamplePage` 提供标题、返回按钮和同一组公共菜单，详情仍通过根导航器覆盖底栏。

页面专用操作传给 `ExamplePage.actions`：移动端放进页面导航头，桌面端显示在正文工具区。不要另建导航头，也不要在正文里重复创建全局菜单。
