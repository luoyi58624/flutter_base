# 组件文档页规范

Button 是首个样板，参数以本仓库的公共接口为准；其余组件沿用同样的分节、交互舞台和独立源码结构。

当前目录中的组件均已接入已有实现或基础 Material 替代；没有对应实现的预设返回原来的空白页。Empty 两端暂留空；移动端数字输入、验证码输入、标签输入和提及，以及桌面端骨架屏继续等待对应实现。Icon、Text、Divider 和 Badge 使用当前公共入口，不新增组件接口。

## 页面与示例

- 一组件一目录。`index.dart` 用 `ComponentDocPage` 装配页面标题、一句概述和有序小节。用 `catalog.dart` 登记一次入口，桌面与移动目录共用页面。
- 一个场景放一个 `examples/` 下的 Dart 文件。迁移已有文档时保留场景顺序、变体对照和交互。相近的变体用 `Wrap` 集中展示，小节说明只补充行为和使用边界。
- 演示只使用 Flutter 与 `flutter_base` 的公共入口。组件实现和 token 由外层的 `ElComponentProvider` 提供。交互状态放在示例内部，有状态示例用 `HookWidget`。

## 排版与源码

- `ComponentDocPage` 统一标题层级、正文滚动、宽屏本页目录和源码展开。窄屏使用单列。独立示例舞台由共享的 `ElCard` 承载。
- 小节的 `source` 指向实际运行的 Dart 文件。新增页面时，把它的 `examples/` 目录登记到 `example/pubspec.yaml` 的 `flutter.assets`，源码查看和复制直接使用该文件。
- 演示本身用原生布局处理可用宽度。代码较长时在代码区横向滚动，纵向滚动统一由文档正文承载。

## 验证

用局部无头测试覆盖窄屏排版、目录定位、源码展开与复制，以及示例实际操作。Button 对应 `example/test/button_doc_page_test.dart`。
