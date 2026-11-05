# Flutter Base 响应式示例

默认入口通过 `MaterialApp.router` 与 `GoRouter.routingConfig` 连接首页、组件、示例、设置四个一级页面。路由配置集中在 `lib/src/router/`，一级页面由 `lib/src/router/pages.dart` 声明，组件页面由 `lib/src/pages/components/catalog.dart` 声明。

可用宽度不超过 640 逻辑像素时显示移动导航，更宽时显示桌面侧栏。地址与选中项同步，例如 `/components/button` 在两种布局中均定位 Button 页。移动端详情覆盖一级导航，返回后回到所属目录。设置和阴影工具的路由作用域安装其组件所需的完整移动预设。

## Android 深度链接

安装此 example 后，可以通过 `flutter-base://example` 加页面路径直接启动 App 并进入目标页。App 已经运行时，收到链接也会切换到目标页。Android 的入口配置位于 `android/app/src/main/AndroidManifest.xml`，页面路径由同一套 GoRouter 解析。

首次加入或修改 Manifest 的链接配置后，需要重新构建并安装 example。开发时可以直接指定启动页面，在 `example/` 目录执行下面的命令，将 `设备ID` 换成 `flutter devices` 列出的 Android 设备 ID。

```powershell
flutter run -d "设备ID" --route=/components/button
```

对已安装的新版本，可以用 ADB 打开按钮页。通过 USB 或无线 ADB 连接都适用。

```powershell
adb shell am start -W -a android.intent.action.VIEW -d "flutter-base://example/components/button" com.example.example
```

连接多台设备时，在 `adb` 后面加 `-s "设备ID"`。例如进入按压反馈页。

```powershell
adb -s "设备ID" shell am start -W -a android.intent.action.VIEW -d "flutter-base://example/examples/press-feedback" com.example.example
```

### 一级页面

| 页面 | 路径 | Android 深度链接 |
| --- | --- | --- |
| 首页 | `/home` | `flutter-base://example/home` |
| 组件目录 | `/components` | `flutter-base://example/components` |
| 高级示例目录 | `/examples` | `flutter-base://example/examples` |
| 设置 | `/settings` | `flutter-base://example/settings` |

### 组件页面

所有组件页使用 `/components/<key>`，Android 链接为 `flutter-base://example/components/<key>`。例如按钮是 `/components/button`，按钮组是 `/components/button-group`。

| 分组 | 页面 key |
| --- | --- |
| 开始使用 | `quick-start`、`theme-design`、`shadow-design` |
| 基础组件 | `button`、`button-group`、`icon`、`text`、`tag` |
| 表单组件 | `input`、`input-number`、`input-otp`、`input-tag`、`autocomplete`、`mention`、`select`、`switch`、`radio`、`checkbox`、`segmented`、`slider`、`calendar`、`form` |
| 布局与容器 | `card`、`divider`、`collapse`、`tabs` |
| 列表组件 | `list-tile`、`list-group` |
| 数据展示 | `avatar`、`badge`、`progress`、`skeleton`、`empty`、`steps` |
| 反馈组件 | `alert`、`loading` |

### 独立高级示例

| 页面 | 路径 | Android 深度链接 |
| --- | --- | --- |
| ElView 测试 | `/examples/view` | `flutter-base://example/examples/view` |
| 自定义手势 | `/examples/gestures` | `flutter-base://example/examples/gestures` |
| ElView 基础使用 | `/examples/base` | `flutter-base://example/examples/base` |
| 按压反馈 | `/examples/press-feedback` | `flutter-base://example/examples/press-feedback` |

目录中的普通点击通过原生 Navigator 打开独立示例。直接使用上述地址时，路由会同时建立示例目录与详情页，返回后进入示例目录。新增高级示例只需在 `lib/src/pages/examples/catalog.dart` 登记，深度路由随目录自动生成。

## 独立的应用演示

`lib/src/mobile/` 保留 flutter_demo 的推荐、分类、消息、我的四个页面，通过 ElComponentProvider 安装 `el.mobileComponents`。可用宽度小于 768 逻辑像素时使用底部导航；达到 768 时切换为左侧桌面导航、64 高度标题栏和居中限宽内容。推荐页在宽屏使用多列卡片，分类页增加内容列数，消息与设置内容限制阅读宽度。

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
