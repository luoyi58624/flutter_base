# 响应式示例

布局、图标路径和示例数据来自 `D:/project/my-project/el/examples/flutter_demo/lib`，保留推荐、分类、消息、我的四栏，以及详情、收藏、聊天、账号设置页面。`main.dart` 启动 `ElExampleApp`。

根节点安装 `ElMobileTheme`，文本、标签、开关、卡片和列表使用通用 El* 接口。页面级导航组合现有视图基元，使用移动端配色，不依赖品牌具体实现。

布局以可用宽度 768 逻辑像素为断点：窄屏保留底部四栏；宽屏由 navigation.dart 提供左侧导航，主区采用桌面标题栏和限宽内容。推荐页使用 ElGridView.builder 自适应排列卡片，分类页显示三列内容；消息、设置及子页面限制阅读宽度。布局切换保持同一页面子树，保留 Hook、滚动控制器、分页和已读状态。响应式逻辑只在示例中组合，不新增组件库的端专属接口。

所有示例滚动视口使用 `ElScrollView`；长列表通过直接子段 `ElListView.builder` 虚拟化，推荐页使用内建刷新器，聊天使用反向列表。分类通过真实条目坐标定位，避免依赖 Flutter Scrollable 的祖先协议。

“我的 → 组件示例”进入原有 demo 列表，保留视图、基础用法和自定义手势页面以及性能浮层开关。旧手势页仍保留原生手势识别器对照，滚动容器统一迁移。

不引入源工程专用的 Android WebView、Toast 或字体度量通道。帮助和关于页提供 Flutter 内容，可通过 pageContentBuilder 替换；轻提示由当前应用 ScaffoldMessenger 展示。验证使用无头测试，未启动用户设备或窗口。
