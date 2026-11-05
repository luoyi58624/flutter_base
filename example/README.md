# Flutter Base 响应式示例

默认入口保留 flutter_demo 的推荐、分类、消息、我的四个页面，通过 ElComponentProvider 安装 `el.mobileComponents`。可用宽度小于 768 逻辑像素时使用底部导航；达到 768 时切换为左侧桌面导航、64 高度标题栏和居中限宽内容。推荐页在宽屏使用多列卡片，分类页增加内容列数，消息与设置内容限制阅读宽度。

布局按窗口可用宽度判断，不依赖操作系统或物理像素。调整窗口不会重置当前页面、分页、已读及设置状态；详情和聊天等子页面同样限制宽屏内容宽度。

“我的 → 组件示例”可进入原有视图、基础用法和自定义手势页面；桌面侧栏也保留直接入口，性能浮层开关仍在原示例列表中。

组件目录中的 Button 页是文档样板。新页面按[组件文档页规范](lib/src/pages/components/README.md)组织。

页面滚动统一采用 ElScrollView，长列表组合 ElListView.builder。保留推荐刷新与追加、分类联动、消息已读、聊天发送和模拟回复。帮助、关于使用 Flutter 内容页，不依赖源工程的 Android 专用通道。

源码与迁移边界见 [布局说明](lib/src/mobile/README.md)。

无头验证：

```powershell
flutter test test/mobile_shell_test.dart test/responsive_shell_test.dart
```

当前验证覆盖桌面与移动布局切换、状态保留、内容限宽、移动布局跳转、分页刷新、分类定位和聊天贴底；未启动真实桌面窗口或作真机视觉验收。既有手势页面可单独运行 test/custom_gestures_page_test.dart 验证。
