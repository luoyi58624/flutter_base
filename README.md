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

## ElView 基础视图

入口为 `package:flutter_base/ui.dart`。`ElView` 只有 `style`、`child`（以及标准
`key`），使用一个 RenderObject 完成盒模型与背景绘制。首版样式字段为
`width`、`height`、`backgroundColor`、`padding`、`margin` 和过渡配置 `transitions`。

- 宽高接受数值或百分比字符串，包含 padding、不包含 margin；null 为 auto。
  非法或非有限尺寸退回 auto，负尺寸夹到零；边距必须非负且有限。
- 百分比优先使用扣除 margin 后的父最大约束；无界轴查找最近具有确定内容尺寸的
  ElView 祖先，没有参照则按 auto 布局。像素与百分比过渡保留混合表达式，随参照求值。
- 首次挂载直接应用目标值；重建样式后按属性分别过渡，同一属性采用最后一条匹配配置。
  相同目标不重启，目标改变从当前值接续；移除过渡或关闭动画立即应用目标。
- auto 的动画端点在子组件更新后的真实布局中测量，支持 LayoutBuilder；子内容或约束
  变化时更新快照并保留原截止时间。百分比参照消失或恢复也从当前尺寸接续。
- 背景使用预乘 alpha 插值，透明端点的隐藏 RGB 不污染中间颜色；null 与颜色之间
  平滑淡入淡出，最终 null 停止绘制。支持方向性边距及曲线过冲的有效值约束。
- 盒模型属性不级联继承。方向、TickerMode、减少动态效果直接依赖 Flutter 的
  InheritedWidget 机制；此层没有 vars、styleBuilder 或事件系统。

`view/index.dart`、`view/render/index.dart`、`view/style/index.dart` 是独立 library，
依赖方向为 view → render → style。样式引擎负责时间和字段插值，通过捕获起始尺寸、
通知失效两个回调协作；渲染层负责布局参照及目标尺寸测量。内部类型不通过 UI 入口导出。

动画引擎和 Ticker 按需创建，每帧只访问活动轨道，不重建 ElStyle 或 child；颜色变化
只标记绘制，几何变化才标记布局。auto 目标测量可能额外执行一次真实布局；只有登记过
无界百分比参照依赖的节点，才会在参照变化时扫描后代。当前验证为模块测试，未作设备
Profile 性能结论。

`ElStyle` 的 copyWith、merge、比较字段列表通过 `ElModelGenerator` 生成：省略参数
保留原值，copyWith 显式 null 清空，merge 忽略 null 且整体替换过渡列表。
新增属性时补充样式声明、StyleField 的读取/插值/失效规则及渲染消费，并重新生成：

```powershell
dart run build_runner build --build-filter 'lib/src/ui/view/style/index.g.dart'
flutter test test/ui/view_test.dart --concurrency=1
```
