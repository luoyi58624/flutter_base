<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

TODO: Put a short description of the package here that helps potential users
know whether this package might be useful for them.

## Features

TODO: List what your package can do. Maybe include images, gifs, or videos.

## Getting started

TODO: List prerequisites and provide or point to information on how to
start using the package.

## Usage

TODO: Include short and useful examples for package users. Add longer examples
to `/example` folder.

```dart
const like = 'sample';
```

## Additional information

TODO: Tell users more about the package: where to find more information, how to
contribute to the package, how to file issues, what response they can expect
from the package authors, and more.

## 代码生成

注解和序列化辅助通过 `package:flutter_base/dart.dart` 导出；构建器通过
`package:flutter_base/builder.dart` 加载，与业务入口分开。

当前仅提供两个通用构建器：

- `elModelBuilder`：处理 `ElModelGenerator`、`ElFieldGenerator`，生成模型的 JSON
  转换、默认实例、`copyWith`、`merge` 和属性列表，具体输出由注解配置决定。
- `elSourceGeneratorBuilder`：处理 `ElSourceGenerator`，将类声明源码生成到指定的
  字符串 getter，支持读取同一 library 的 part 文件。

模型字段取自无名构造的命名参数，支持 `this`、`super` 以及同名字段的初始化参数。
位置参数、泛型模型、抽象类或缺少无名构造的模型会在生成阶段报告具体位置。
JSON Map 的键须为 `String` 或 `dynamic`；嵌套 List、Set、Map 按类型逐层编解码，
其中的模型和自定义序列化器同样生效，Set 输出为 JSON 数组。

自定义 `ElSerialize` 注解保留完整表达式，包括构造参数、命名构造和导入前缀；
JSON 键及字符串默认值支持引号、反斜杠、换行和 `$`。
构建选项 `ext_suffix` 默认为 `Ext`，每个构建器实例独立持有配置。
模型构建器的中间产物标识为 `model_generator`，最终输出仍合并到 `.g.dart`。

生成并验证本仓库的测试样例：

```powershell
dart run build_runner build --build-filter 'test/generator/generates/**'
dart test test/dart/gen test/generator --concurrency=1 --fail-fast
```
