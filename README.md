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
`key`），使用一个 RenderObject 完成盒模型与装饰绘制。当前样式字段为
`width`、`height`、`widthFactor`、`heightFactor`、`backgroundColor`、`padding`、`margin`、`border`、`borderRadius`、`clipBehavior`
和过渡配置 `transitions`。

- 宽高接受数值或百分比字符串，包含 padding、不包含 margin；null 为 auto。
  非法或非有限尺寸退回 auto，负尺寸夹到零；边距必须非负且有限。
- widthFactor/heightFactor 接受非负有限数值，null 等同于 1；仅调整对应 auto 轴的
  自然盒尺寸，先加入 padding 再乘因子，最后追加 margin，最终服从父约束。
  显式像素或可解析百分比尺寸优先；无参照百分比回退 auto 时使用因子。
  因子不缩放 child，也不改变 child 约束；小于 1 时 child 可溢出，裁剪仍由 clipBehavior 控制。
  例如父宽 300、child 自然宽 80 且无边距时，width: '60%' 得到 180，widthFactor: .6 得到 48。
- 百分比优先使用扣除 margin 后的父最大约束；无界轴查找最近具有确定内容尺寸的
  ElView 祖先，没有参照则按 auto 布局。像素与百分比过渡保留混合表达式，随参照求值。
- 首次挂载直接应用目标值；重建样式后按属性分别过渡，同一属性采用最后一条匹配配置。
  相同目标不重启，目标改变从当前值接续；移除过渡立即应用目标。
- auto 的动画端点在子组件更新后的真实布局中测量，支持 LayoutBuilder；子内容或约束
  变化时更新快照并保留原截止时间。转入 auto 时起点固定为当前已呈现尺寸；百分比参照
  消失或恢复也从当前尺寸接续，delay 内失去参照不会造成等待期跳变或首帧停顿。
- 背景使用预乘 alpha 插值，透明端点的隐藏 RGB 不污染中间颜色；null 与颜色之间
  平滑淡入淡出，最终 null 停止绘制。支持方向性边距及曲线过冲的有效值约束。
- 边框接受原生 `Border` / `BorderDirectional`，支持独立四边颜色、粗细、none、hairline
  和 `strokeAlign`。它只触发重绘，不占布局空间、不自动增加 padding；粗细过渡不挤压
  child 或移动兄弟元素。方向、粗细、描边位置和预乘 alpha 颜色由 StyleEngine 处理，
  null / none 从零宽透明边过渡，明确的透明 solid 边保留粗细与圆角归属。
  单边接管相邻完整圆弧，共角的两条边各占半角；与椭圆角、超大圆角共用规范形状。
  边框在 child 上方绘制，外描边计入绘制范围，不扩大盒外的命中范围。
- 圆角接受原生 `BorderRadiusGeometry`，支持独立四角、椭圆角和方向性圆角；非负且有限，
  null 或等效方角走矩形快路。超大圆角按实际尺寸统一缩放，作用于背景与边框。
  方向解析与过渡由 StyleEngine 完成，null 按零插值；纯圆角动画只重绘，不触发布局。
- `clipBehavior` 默认为 `Clip.none`；启用后按当前盒形状裁剪背景与 child，不包含 margin，
  同步过滤 child 命中。支持 hardEdge、antiAlias、antiAliasWithSaveLayer，模式立即切换，
  不参与 `ElTransition.all()` 插值。无圆角使用矩形裁剪，无背景也可以裁剪 child；
  边框在该裁剪结束后绘制，center / outside 描边不会被自身裁剪截掉。
- 盒模型属性不级联继承；边距方向通过官方 Directionality 读取。声明式过渡仅由
  transitions 控制，不订阅系统动画开关；此层没有 vars、styleBuilder 或事件系统。

`render/index.dart` 仅导出 ElRenderView；宿主只转交样式、调度协作者并落地 Flutter
布局/绘制协议。每个宿主在构造时立即创建唯一 StyleEngine，声明解析、方向求值、
当前值、目标值、动画轨道与精确失效全部由引擎管理，Render 不读写字段数组或轨道。

- `style/fields.dart` 集中定义字段读取、插值与消费域，样式字段不依赖公开过渡枚举的位序。
- `style/resolved/layout.dart` 输出数值宽高和已解析的物理边距，不向执行器泄漏表达式。
- `layout/box_layout.dart` 的 BoxLayout 统一执行尺寸、内外边距、真实/dry/intrinsic/
  baseline、正式几何和按轴百分比参照依赖；未声明边距时直接复用约束。
- `paint/decoration.dart` 的 DecorationPainter 按需创建并复用背景画笔，矩形背景不构造
  形状、路径或图层。背景、边框或裁剪实际消费圆角时才创建 `paint/shape.dart` 的 ShapeGeometry，
  绘制与自身命中共用规范圆角；仅尺寸或圆角变化重建，颜色、外边距和整体位置变化复用局部形状。
- `paint/border.dart` 由 DecorationPainter 按需持有，复用旧版角归属与中心线算法；
  补齐非均匀粗细、原生描边位置和 hairline，纯颜色变化不重建边框几何。
- `paint/effects.dart` 的 EffectController 仅在实际裁剪时创建，与装饰共用局部形状。
  由 Flutter 根据现有合成需求选择画布或图层，复用可用裁剪层，停用时释放持有权；
  不因 saveLayer 模式强制增加合成层。外层裁剪已定义圆角时，背景画矩形以避免重复抗锯齿。

Ticker 和轨道集合只为实际过渡创建；首次挂载或仅声明 transitions 不启动时钟。
动画只采样活动轨道，不重建 ElStyle 或 child；固定尺寸采样值未变时不请求布局，
纯颜色、圆角或边框变化只重绘，也不重新解析尺寸和边距。

```dart
ElView(
  style: ElStyle(
    width: 160,
    height: 80,
    backgroundColor: const Color(0xff409eff),
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    transitions: const [ElTransition.field(ElTransitionField.borderRadius)],
  ),
)
```

auto 等待 delay 时不测量端点；活动阶段可能逐帧额外执行真实 child 布局，因为任意
child 在紧约束下可以独立更新，父 dirty 不能作为可靠的跨帧内容版本。相同帧、相同
请求共享测量结果；不同截止时间的双 auto 按截止时间单向求值，避免循环重测。
端点变化区分外部内容/约束更新与引擎自身的连续几何动画；相同端点不重置剩余曲线。
临时测量使用临时内容参照，最后恢复正式布局，不污染后代已呈现几何和动画时间线。

无界百分比仅订阅实际查询经过的候选祖先，按轴使依赖节点失效，不扫描整个后代树；
未使用相对尺寸就不创建引用登记；普通像素尺寸不计算百分比参照。文本和事件子系统暂不处理。

测试仅保留 `test/ui/view/base_test.dart` 和 `animation_test.dart` 两个文件，均通过
真实 `ElView(style: ElStyle(...), child: ...)` 环境验证实际布局、绘制与命中。
前者覆盖正常情况下的基础功能，后者覆盖插值中间值、auto/百分比转换、延迟、中断、
方向变化、null/半透明颜色及裁剪联动等边界。测试不依赖内部状态、调用次数、缓存身份或
图层复用情况；不编写持久性能测试，真机流畅度由使用者体验验收。

`ElStyle` 的 copyWith、merge、比较字段列表通过 `ElModelGenerator` 生成：省略参数
保留原值，copyWith 显式 null 清空，merge 忽略 null 且整体替换过渡列表。
新增属性时补充样式声明、StyleField 的解析/插值/失效规则及对应执行器消费，保持
Render 调度骨架稳定，再重新生成模型代码。相关验证只运行本次文件：

```powershell
dart run build_runner build --build-filter 'lib/src/ui/view/style/index.g.dart'
flutter test test/ui/view --concurrency=1
```

## 独立事件 Widget

通过 `package:flutter_base/ui.dart` 使用 `ElEventView`。它只有 `event`、
`child` 和标准 `key`，以一个 RenderObject 承载事件，沿用子组件的尺寸，
可包裹任意 Flutter Widget。

```dart
ElEventView(
  event: ElEvent(
    cursor: SystemMouseCursors.click,
    onTap: (event) => print(event.localPosition),
    onLongPress: (event) => print('长按'),
  ),
  child: Builder(
    builder: (context) => ColoredBox(
      color: context.hasTap
          ? const Color(0xffbbbbbb)
          : context.hasHover
          ? const Color(0xffeeeeee)
          : const Color(0xffffffff),
      child: const SizedBox(width: 120, height: 40, child: Text('点击我')),
    ),
  ),
)
```

- 保留原始指针、进入/悬停/离开、滚轮、触控板 PanZoom，以及主键、右键、
  中键和前进/后退键点击；支持单击、双击、三击、长按及取消原因。
- 支持自由/水平/垂直拖拽、多指缩放与旋转、速度估计和接受拖拽后的帧重采样。
  `ElEventConfig` 只配置当前节点；重采样默认仅在 Android 启用，可按平台覆写。
- 命中行为由 `event.behavior` 控制，默认 opaque；`event.disabled` 禁用时吸收
  盒内指针命中，并结清当前节点及后代事件宿主的活动手势和延迟点击。
- 嵌套事件宿主按各自本地坐标传播；`stopPropagation()` 截断相应事件家族，
  `eagerGesture()` 独占当前 pointer 的事件成员。原始 Move、DragUpdate 不作通用冒泡，
  侧键点击由最近的订阅节点处理。独占只作用于这套事件系统，不参与官方 gesture arena。
- `ElDragProxy` 提供祖先预消费、当前节点消费、祖先接收余量三段协作；使用
  `consumeDelta` / `consumePrimaryDelta` / `consumeAllDelta` 分配拖动位移。
- 重建时同结构的新闭包热替换并保留手势；`copyWith` 的 null 表示保留，
  清除回调使用 `clear: {ElEventClearField.onTap}`。卸载、禁用和结构变化均结算已开始的手势。
- `ElEventView.maybeOf(context)` 读取最近祖先的只读 `ElEventState`，没有宿主时返回 null。
  `context.hasTap`、`context.hasHover` 按字段订阅状态，没有宿主时返回 false；
  `hasLongPress`、`hasDrag` 表示已配置的相应手势是否处于活动状态。
  必须使用 child 内部的 context（例如上述 Builder）；创建 ElEventView 的外层 context
  无法读取它自己的状态。状态变化只通知实际订阅字段的后代，静态 child 不重建。
- `ElEventConfig.delayTouchDown` 默认 0ms，控制触摸按压反馈的进入延迟；
  `delayTouchUp` 默认 100ms，表示从最初按下起算的最短反馈时间。
  这些配置只影响 `hasTap`，不延迟点击回调。短于进入延迟的触摸不补播反馈，
  取消、禁用和卸载立即清理；鼠标和笔即时响应。

事件实现在 `lib/src/ui/event/`，只依赖 Dart、Flutter 和自身目录，不依赖 ElView、
样式、滚动、投影或选区模块。交互状态由后代自行用于改变样式；本次不包含键盘、
焦点或全局指针屏障。
内部 dispatcher 与状态机不从公共入口导出。

```powershell
flutter test test/ui/event --concurrency=1
```
