# 组件预览示例

沿用旧项目的示例写法：外层 `HookWidget` 组织预览，私有 `_Example` 放真实演示，文件底部写 `code` 源码字符串。预览外壳使用 `ElCodeExample`，纯代码块使用 `ElCodePreview`，不要另造一套卡片、折叠栏或复制按钮。

## 单个演示

一个场景一个 `examples/exampleN.dart` 文件。外层类名与文件序号对应，演示主体统一叫 `_Example`；需要状态的主体也使用 `HookWidget`。

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

// 按示例文件的位置调整相对路径。
import '../../../../../widgets/code_preview/index.dart';

/// 展示按钮的基本用法。
class Example1 extends HookWidget {
  const Example1({super.key});

  @override
  Widget build(BuildContext context) => ElCodeExample(
    code: code,
    children: [_Example()],
  );
}

class _Example extends HookWidget {
  @override
  Widget build(BuildContext context) => ElButton(
    onPressed: () {},
    child: 'Hello',
  );
}

/// 与上方演示保持一致的源码。
String get code => r'''ElButton(
  onPressed: () {},
  child: 'Hello',
);''';
```

`code` 展示实际演示的写法，省略文档卡片本身的装配代码。使用原始字符串 `r'''...'''`，避免演示里的 `$value`、`${value}` 被外层字符串插值；修改演示时同步维护代码字符串。

## 多个演示主体

同一小节有多个对照场景时，外层仍是一个 `HookWidget`，主体按顺序命名为 `_Example1`、`_Example2`、`_Example3`，放进同一个 `ElCodeExample.children`。不要使用没有上下文的 `_Widget1` 等名称。

```dart
@override
Widget build(BuildContext context) => ElCodeExample(
  code: code,
  children: [_Example1(), _Example2(), _Example3()],
);
```

卡片统一管理舞台内边距、子项间距、悬停、折叠动画和代码区。各主体只负责演示组件及其布局、状态和事件；保留原有演示内容、颜色、尺寸、变体顺序与交互。

## 使用现有源码生成器

不想重复维护字符串时，在主体类上标记 `@ElSourceGenerator('code')`，让现有 `gen` 生成同名源码 getter。不要同时手写 `String get code`。

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../../../widgets/code_preview/index.dart';

part 'example1.g.dart';

/// 展示共享状态的切换按钮。
class Example1 extends HookWidget {
  const Example1({super.key});

  @override
  Widget build(BuildContext context) => ElCodeExample(
    code: code,
    children: [_Example()],
  );
}

@ElSourceGenerator('code')
class _Example extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final selected = useState(false);
    return ElButton.toggle(modelValue: selected, child: selected.value.toString());
  }
}
```

注解由 `flutter_base.dart` 导出，构建器是 `flutter_base|sourceGenerator`。在使用注解的包中声明 `build_runner` 开发依赖，确认该包的 `build.yaml` 没有排除示例文件，然后在该包目录执行：

```sh
dart run build_runner build
```

生成器提取整个被标记的类，排除类前的注释和注解，输出到对应 `.g.dart`，不手改生成文件。多个主体分别使用 `@ElSourceGenerator('code1')`、`@ElSourceGenerator('code2')`，同一文件的 getter 名称不能重复。

## 多文件与纯代码块

确实需要并排说明多个源码文件时，用 `ElCodeExample(files: [ElCodeFile(name: 'ui.dart', code: code), ...], children: [...])`；`files` 与 `code` 互斥。文件名必须非空且唯一，默认优先打开 `ui.dart`，没有时打开第一个文件。

只展示源码时直接使用 `ElCodePreview(code: code)`。默认高度随源码展开，横向长行在代码区内滚动；只有确实需要内部纵向滚动时才传 `maxHeight`。Atom One Dark 配色、Consolas 字体和工具栏样式沿用旧实现。
