# 组件文档页规范

Button 是首个样板，参数以本仓库的公共接口为准；其余组件沿用同样的分节、交互舞台和独立源码结构。

当前目录中的组件均已接入已有实现或基础 Material 替代；没有对应实现的预设返回原来的空白页。Empty 两端暂留空；移动端数字输入、验证码输入、标签输入和提及，以及桌面端骨架屏继续等待对应实现。Icon、Text、Divider 和 Badge 使用当前公共入口，不新增组件接口。

## 页面与示例

- 一组件一目录。`index.dart` 用 `widgets/docs_page` 中的 `DocsPage` 声明标题、简介和有序小节。在组件标签入口 `index.dart` 的目录分组登记页面。
- 一个场景放一个 `examples/` 下的 Dart 文件。迁移已有文档时保留场景顺序、变体对照和交互。相近的变体用 `Wrap` 集中展示，小节说明只补充行为和使用边界。
- 演示只使用 Flutter 与 `flutter_base` 的公共入口。组件实现和 token 由外层的 `ElComponentProvider` 提供。交互状态放在示例内部，有状态示例用 `HookWidget`。

## 排版与源码

- `DocsPage` 统一标题层级、正文滚动和宽屏目录，窄屏使用单列。
- `DocsSection.child` 接收正文或演示组件。提供 `source` 时由示例卡展示并读取 Dart 源码。把对应的 `examples/` 目录登记到 `example/pubspec.yaml` 的 `flutter.assets`。
- 演示本身用原生布局处理可用宽度。代码较长时在代码区横向滚动，纵向滚动统一由文档正文承载。

## 验证

用局部无头测试覆盖窄屏排版、目录定位、源码展开与复制，以及示例实际操作。Button 对应 `example/test/button_doc_page_test.dart`。
