# Flutter Base 移动端示例

默认入口沿用 flutter_demo 的推荐、分类、消息、我的四栏布局，安装 mobile.dart 的 MyTheme。图标和演示数据保留参考工程内容，排版使用移动端主题。

“我的 → 组件示例”可进入原有视图、基础用法和自定义手势页面；性能浮层开关仍在原示例列表中。

页面滚动统一采用 ElScrollView，长列表组合 ElListView.builder。保留推荐刷新与追加、分类联动、消息已读、聊天发送和模拟回复。帮助、关于使用 Flutter 内容页，不依赖源工程的 Android 专用通道。

源码与迁移边界见 [移动端布局说明](lib/src/mobile/README.md)。

无头验证：

```powershell
flutter test test/mobile_shell_test.dart test/custom_gestures_page_test.dart
```

当前验证覆盖移动布局跳转、分页刷新、分类定位、聊天贴底和既有手势行为；未作真机视觉验收。
