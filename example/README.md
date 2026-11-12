# Flutter Base 响应式示例

默认入口通过 `MaterialApp.router` 与 `GoRouter.routingConfig` 连接首页、组件、示例、设置四个一级页面。路由配置集中在 `lib/src/router/`，一级页面由 `lib/src/router/pages.dart` 声明，组件页面由 `lib/src/pages/components/catalog.dart` 声明。

可用宽度不超过 640 逻辑像素时显示移动导航，更宽时显示桌面侧栏。地址与选中项同步，例如 `/components/button` 在两种布局中均定位 Button 页。移动端详情覆盖一级导航，返回后回到所属目录。设置和阴影工具的路由作用域安装其组件所需的完整移动预设。

Android 系统字重由 example 自己管理：`main()` 在绑定初始化后调用 `AndroidSystemFontWeight.getWght()`，把非空结果作为 `wght` 轴注入根 `ElView`。ElView 子树与 `context.elMaterialThemeData` 生成的官方主题共用该值，局部字体轴仍可覆盖；非 Android 或插件未取得有效值时保留默认字体。首次加入此原生插件后需重新构建安装，热重载无法加载新增插件。

`/components/icon` 的「全部图标」展示 280 个桌面字体图标和 35 个移动 SVG。按钮组切换图标库，首次显示按当前布局初始化，手动切换后调整窗口宽度仍保留当前选择；每个图标都显示名称，移动 SVG 的线宽沿用祖先注入的字重。

## Android 打包与体积

在 `example/` 目录构建供 ARM64 真机使用的 Profile APK：

```powershell
flutter build apk --profile --target-platform android-arm64
```

产物为 `build/app/outputs/flutter-apk/app-profile.apk`。原生插件的 ABI 过滤跟随 `--target-platform`，例如此命令只打包 `arm64-v8a`；没有指定目标架构时，保留 Flutter 默认的多架构行为。需要分别分发各架构时使用 Flutter 的拆包配置：

```powershell
flutter build apk --profile --split-per-abi
```

拆包时不额外设置 `ndk.abiFilters`，避免与 Flutter 的 ABI splits 冲突。具体机制见 [Flutter 的 ABI 过滤说明](https://docs.flutter.dev/release/breaking-changes/default-abi-filters-android)。

2026-11-12 对现有 ARM64 Profile 包的实测如下，体积按 MiB（1024 × 1024 字节）计算：

| 项目 | 优化前 | 优化后 |
| --- | ---: | ---: |
| APK 文件 | 93.80 MiB | 48.14 MiB |
| 多余的 ARM32、x86_64 原生库 | 27.06 MiB | 0 |
| 增量打包留下的 ZIP 空位 | 17.88 MiB | 0 |
| 图片、字体和示例源码等 Flutter assets | 2.07 MiB | 1.40 MiB |

ARM64 的播放器、Flutter 引擎和 Profile VM 服务均保留；资源减少来自构建命令默认开启的图标字体裁剪。构建后已检查 ZIP 完整性、APK 签名和 16 KB ZIP 对齐；其他架构验证了 Gradle 配置，未分别编译或安装到设备。

频繁增量构建仍可能积累 ZIP 空位，这是 [Android Zipflinger 的增量更新机制](https://android.googlesource.com/platform/tools/base/+/51ca010d6bdf93fd29226aa0ecf161af25fc13bc/zipflinger/README.md)。需要重新压紧默认入口的 ARM64 Profile 包时，在 `example/` 目录执行：

```powershell
.\android\gradlew.bat -p android :app:packageProfile --rerun :app:assembleProfile -Ptarget-platform=android-arm64 -Ptree-shake-icons=true --max-workers=2
```

这里仅强制重跑打包任务，上游编译仍可复用缓存；使用自定义入口或 Dart defines 时，需向 Gradle 传入对应的构建参数。`--rerun` 的行为见 [Gradle 命令行说明](https://docs.gradle.org/current/userguide/command_line_interface.html#sec:rerun_tasks)。

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

目录中的普通点击通过原生 Navigator 打开独立示例。直接使用上述地址时，路由会同时建立示例目录与详情页，返回后进入示例目录。新增高级示例只需在 `lib/src/pages/examples/index.dart` 登记，深度路由随目录自动生成。

## 独立的应用演示

`lib/src/mobile/` 保留 flutter_demo 的推荐、分类、消息、我的四个页面，通过 ElComponentProvider 安装 `el.mobileComponents`。可用宽度小于 768 逻辑像素时使用底部导航；达到 768 时切换为左侧桌面导航、64 高度标题栏和居中限宽内容。推荐页在宽屏使用多列卡片，分类页增加内容列数，消息与设置内容限制阅读宽度。

布局按窗口可用宽度判断，不依赖操作系统或物理像素。调整窗口不会重置当前页面、分页、已读及设置状态；详情和聊天等子页面同样限制宽屏内容宽度。

“我的 → 组件示例”可进入原有视图、基础用法和自定义手势页面；桌面侧栏也保留直接入口，性能浮层开关仍在原示例列表中。

组件目录中的 Button 页是文档样板。新页面按[组件文档页规范](lib/src/pages/components/README.md)组织。

页面滚动采用 ElScrollView，长列表组合 ElScrollView.sliver 和 SliverList.builder。保留推荐刷新与追加、分类联动、消息已读、聊天发送和模拟回复。帮助、关于使用 Flutter 内容页，不依赖源工程的 Android 专用通道。

源码与迁移边界见 [布局说明](lib/src/mobile/README.md)。

无头验证：

```powershell
flutter test test/mobile_shell_test.dart test/responsive_shell_test.dart
```

当前验证覆盖桌面与移动布局切换、状态保留、内容限宽、移动布局跳转、分页刷新、分类定位和聊天贴底；未启动真实桌面窗口或作真机视觉验收。既有手势页面可单独运行 test/custom_gestures_page_test.dart 验证。
