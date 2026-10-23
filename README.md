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

## 可选的 Android 全局触摸重采样

由现有入口 `package:flutter_base/flutter_base.dart` 导出，显式初始化才启用；
采样实现仅依赖 Flutter SDK，不依赖 ElEvent、ElView 或其他第三方库。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

void main() {
  ElWidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}
```

这行必须先于其他绑定或插件初始化。重复调用复用当前实例；已有其他绑定时会
明确报错。未接入时使用官方事件管线。接入后仅采样 Android 原生 touch 输入，
其他平台、鼠标、触控板和触笔直接分发；不再提供 Windows 采样分支。

按下即时分发，移动使用原有自适应尾随、插值及最多 8ms 的有界外推；多指共享
采样时刻，抬起前结清真实移动，取消后不再输出帧。官方手势、滚动组件、Listener
和 ElEvent 共同接收这一条事件流，ElEvent 不再单独进行输出重采样。
若应用显式启用 Flutter 官方 `resamplingEnabled`，此管线自动让位，避免重复采样。

重采样后的事件参与官方识别与估速，纯预测帧标记为 `synthesized`，不向官方速度
估计器伪造新输入；实际拖拽阈值和甩出手感仍需在目标 Android 设备验证。

Binding 接入位于 `lib/src/flutter_base/sdk/binding.dart`，重采样实现位于同目录
`touch_resampling.dart`；相关测试集中在 `test/flutter_base/sdk/touch_resampling_test.dart`。

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
`width`、`height`、`minWidth`、`maxWidth`、`minHeight`、`maxHeight`、`widthFactor`、`heightFactor`、`aspectRatio`、`backgroundColor`、`gradient`、`boxShadow`、`opacity`、`transform`、`transformAlignment`、`padding`、`margin`、`border`、`outline`、`borderRadius`、`clipBehavior`
和过渡配置 `transitions`。

- 宽高接受数值或百分比字符串，包含 padding、不包含 margin；null 为 auto。
  非法或非有限尺寸退回 auto，负尺寸夹到零；边距必须非负且有限。
- minWidth / maxWidth / minHeight / maxHeight 接受相同的数值或百分比，限制包含 padding
  的视觉盒；margin 外加，border / outline 不占尺寸。min 缺省为零，max 缺省无穷，
  自身 min 大于 max 时 max 优先，父约束最终优先。自身 min 仅撑视觉盒、不强拉 child；
  max 在 child 布局前收窄约束，确保 Wrap 等内容正确重排，auto 仍保留父最小约束。
  显式宽高先限幅；factor 在自然盒上生效后限幅，factor 为零时仍受 min 限制。
  四个独立过渡通道复用旧版合同：有限数值和百分比正常混合插值，null 在中点切换，
  不把无穷参与 lerp；无参照百分比不增加限制，参照恢复后按原进度继续。
- widthFactor/heightFactor 接受非负有限数值，null 等同于 1；仅调整对应 auto 轴的
  自然盒尺寸，先加入 padding 再乘因子，最后追加 margin，最终服从父约束。
  显式像素或可解析百分比尺寸优先；无参照百分比回退 auto 时使用因子。
  因子不缩放 child，也不改变 child 约束；小于 1 时 child 可溢出，裁剪仍由 clipBehavior 控制。
  例如父宽 300、child 自然宽 80 且无边距时，width: '60%' 得到 180，widthFactor: .6 得到 48。
- aspectRatio 是正有限的视觉盒宽高比，包含 padding、不包含 margin。单显式轴派生另一轴，
  双 auto 以自然盒宽派生高；双显式轴或有效 auto 倍数优先。先按比例派生，再应用自身
  min/max 和父约束，因此 width: 100、maxWidth: 80、aspectRatio: 2 得到 80×50。
  真实、dry、intrinsic 与基线共用算法；双 auto 只测一次自然宽，再按派生盒限制 child。
  数值间线性插值，null 在中点切换；非法或非正值不启用比例。
- 百分比优先使用扣除 margin 后的父最大约束；无界轴查找最近具有确定内容尺寸的
  ElView 祖先，没有参照则按 auto 布局。像素与百分比过渡保留混合表达式，随参照求值。
- 首次挂载直接应用目标值；重建样式后按属性分别过渡，同一属性采用最后一条匹配配置。
  相同目标不重启，目标改变从当前值接续；移除过渡立即应用目标。
- auto 的动画端点在子组件更新后的真实布局中测量，支持 LayoutBuilder；子内容或约束
  变化时更新快照并保留原截止时间。转入 auto 时起点固定为当前已呈现尺寸；百分比参照
  消失或恢复也从当前尺寸接续，delay 内失去参照不会造成等待期跳变或首帧停顿。
- 背景使用预乘 alpha 插值，透明端点的隐藏 RGB 不污染中间颜色；null 与颜色之间
  平滑淡入淡出，最终 null 停止绘制。支持方向性边距及曲线过冲的有效值约束。
- gradient 接受原生三类渐变及 GradientTransform，覆盖背景色，空白域仍露出背景。
  使用原生 Gradient.lerp，包括 null 淡出和跨类型的淡出再淡入；改向立即更新 shader，
  不重启过渡。未声明或全透明时不创建 shader，尺寸、渐变和方向之外的变化复用 shader。
- boxShadow 接受原生 BoxShadow 列表，也可混用 ElBoxShadow(inset: true)。绘制顺序为
  外阴影、背景色、渐变、内阴影、child、border、outline；同类阴影按声明顺序覆盖。
  内阴影始终受盒形状裁剪，外阴影不受自身 clipBehavior 裁剪；模糊外溢计入 paintBounds，
  不占布局或增加命中区域。null 和列表增减同时退去颜色与几何，内外类型切换经过透明中点；
  颜色使用预乘 alpha，负 spread 收缩至空时停止绘制，负模糊过冲归零。
- opacity 限制到 0～1，null 为 1；对全部装饰与 child 进行整组合成，保持重叠区域颜色。
  零值跳过绘制和命中，保留布局及语义子树；完全不透明时直接绘制，中间值才启用透明度层。
  null 按 1 插值，曲线过冲限制在有效范围，不裁掉阴影、轮廓或 child 的原有溢出。
- transform 接受 ElTransform，支持 2D / 3D 平移、缩放、旋转、倾斜、透视以及原始矩阵。
  平移单位为逻辑像素，旋转 / 倾斜使用弧度；组合可先用 Matrix4.multiply，再用
  ElTransform.matrix4 快照，输入与输出矩阵互不共享可变状态。它包住整组 opacity、
  装饰与 child，自身裁剪随整组移动，布局、百分比参照、dry 与 intrinsic 均不改变。
  原点按 transformAlignment、transform.origin、Alignment.center 回退，参考包含 padding
  而不包含 margin 的视觉盒；方向性原点由引擎统一解析，RTL 下绘制、命中和语义一致。
  两类原点都连续过渡，独立原点清空时平滑回退当前内部原点；null / identity 变换借用
  对侧原点，不在退出途中跳到中心。同类函数插参数，同轴旋转保留整圈而不取最短路径；
  异类 / 异轴 / 原始矩阵逐分量插值，可能经过退化矩阵，不实现 CSS 矩阵分解。
  绘制、整体命中、后代坐标转换、语义与裁剪共用有效矩阵；视图自身的 localToGlobal
  仍描述布局坐标，后代的坐标链包含其变换。自身语义及裁剪输出有限的近似包围盒，
  动画每帧同步；非有限、奇异、触及或位于视平面后方的投影样本不绘制、不命中且不保留后代
  语义，恢复有效值后重新出现。祖先原有的尺寸和裁剪命中门禁继续生效。
- 边框接受原生 `Border` / `BorderDirectional`，支持独立四边颜色、粗细、none、hairline
  和 `strokeAlign`。它只触发重绘，不占布局空间、不自动增加 padding；粗细过渡不挤压
  child 或移动兄弟元素。方向、粗细、描边位置和预乘 alpha 颜色由 StyleEngine 处理，
  null / none 从零宽透明边过渡，明确的透明 solid 边保留粗细与圆角归属。
  单边接管相邻完整圆弧，共角的两条边各占半角；与椭圆角、超大圆角共用规范形状。
  边框在 child 上方绘制，外描边计入绘制范围，不扩大盒外的命中范围。
- `outline: ElOutline(...)` 聚合 width、color、gradient、offset；默认在盒外绘制，
  正 offset 留出间隙，负值向盒内移动，零宽不绘制。渐变覆盖纯色；支持原生三类渐变、
  方向性几何和 GradientTransform，shader 使用轮廓中心线矩形。
  轮廓位于 border 之后、内容裁剪之外，只重绘，不占布局空间或增加命中区域；
  外缘计入 paintBounds。圆角复用旧版自适应外推，方角保持方角，小圆角大偏移不变胶囊。
  null 双向平滑退去宽度、offset 和透明度；纯色与渐变用固定两项预乘贡献过渡，
  decal 范围外仍保留纯色，支持中断。动画途中改向立即更新渐变，不重启时间线。
- 圆角接受原生 `BorderRadiusGeometry`，支持独立四角、椭圆角和方向性圆角；非负且有限，
  null 或等效方角走矩形快路。超大圆角按实际尺寸统一缩放，供背景、边框与轮廓共用。
  方向解析与过渡由 StyleEngine 完成，null 按零插值；纯圆角动画只重绘，不触发布局。
- `clipBehavior` 默认为 `Clip.none`；启用后按当前盒形状裁剪背景与 child，不包含 margin，
  同步过滤 child 命中。支持 hardEdge、antiAlias、antiAliasWithSaveLayer，模式立即切换，
  不参与 `ElTransition.all()` 插值。无圆角使用矩形裁剪，无背景也可以裁剪 child；
  边框和轮廓在该裁剪结束后绘制，外侧描边不会被自身裁剪截掉。
- 盒模型属性不级联继承；边距方向通过官方 Directionality 读取。声明式过渡仅由
  transitions 控制，不订阅系统动画开关；此层没有 vars、styleBuilder 或事件系统。

`render/index.dart` 实现 ElRenderView；宿主只转交样式、调度协作者并落地 Flutter
布局/绘制协议。每个宿主在构造时立即创建唯一 StyleEngine，声明解析、方向求值、
当前值、目标值、动画轨道与精确失效全部由引擎管理，Render 不读写字段数组或轨道。

- `style/fields.dart` 集中定义字段读取、插值与消费域，样式字段不依赖公开过渡枚举的位序。
- `style/resolved/layout.dart` 输出数值宽高、上下限和已解析的物理边距，不向执行器泄漏表达式。
- `layout/box_layout.dart` 的 BoxLayout 统一执行尺寸、内外边距、真实/dry/intrinsic/
  baseline、正式几何和按轴百分比参照依赖；未声明边距时直接复用约束。
- `paint/decoration.dart` 的 DecorationPainter 按需创建并复用背景画笔，矩形背景不构造
  形状、路径或图层。装饰或裁剪实际消费圆角时才创建 `paint/shape.dart` 的 ShapeGeometry，
  绘制与自身命中共用规范圆角；仅尺寸或圆角变化重建，颜色、外边距和整体位置变化复用局部形状。
- `paint/border.dart` 由 DecorationPainter 按需持有，复用旧版角归属与中心线算法；
  补齐非均匀粗细、原生描边位置和 hairline，纯颜色变化不重建边框几何。
- `paint/outline.dart` 复用旧版外推规则，缓存局部中心线和实际使用的 shader。
  纯色不创建 shader；静态值和 null 过渡保持单次绘制，纯色与渐变的两项贡献同时可见时
  才使用局部透明层预乘相加；颜色、整体位置和仅圆角变化不使无关几何或 shader 重建。
- `paint/shadow.dart` 缓存实际使用的内外阴影几何和画笔，颜色与整体位置不重建几何。
- `style/transform.dart` 保留函数来源与参数，避免矩阵相同却丢失整圈动画；
  `paint/transform.dart` 只补实际视觉盒原点，缓存有效矩阵并检查有限投影。
- `style/filter.dart` 将 ElFilter 的模糊、颜色分量解析为独立的数值输出；
  `paint/filter.dart` 按实际使用创建颜色矩阵与原生滤镜，纯颜色不创建模糊，纯模糊不创建矩阵。
  固定顺序为 grayscale、sepia、saturate、hueRotate、invert、brightness、contrast、opacity，
  最后 blur；hueRotate 使用度数并保留动画圈数，null 端点使用各分量的恒等值。
- `paint/effects.dart` 的 EffectController 仅在实际裁剪或组透明时创建，与装饰共用局部形状。
  由 Flutter 根据现有合成需求选择画布或图层，复用可用裁剪层，停用时释放持有权；
  不因 saveLayer 模式强制增加合成层。裁剪层与透明度层独立释放，组透明使用 OpacityLayer，
  支持 child 自身含合成层；外层已裁剪时，背景、渐变和内阴影不重复裁剪圆角。
  变换层独立持有，纯平移直接调整偏移，其余由 Flutter 按已有合成需求选择画布或图层。
  自身 filter 作用于完整装饰和 child；backdropFilter 仅将盒形状内的背景过滤结果纳入组，
  不将阴影、outline 或溢出 child 一并裁掉。两者同时使用时先形成玻璃与前景，再过滤整组；
  opacity 按 CSS 的整组结果淡出，模糊 sigma 保持不变。背景采样服从 Flutter 实际的祖先隔离边界。
  自定义 clipper 覆盖 borderRadius，裁剪最终滤镜输出并共享实际绘制与命中路径；
  未指定 clipBehavior 时默认 antiAlias，显式 Clip.none 完全停用委托并恢复普通圆角。
  ShapeGeometry 管理 shouldReclip、通知、尺寸变化与挂载监听，语义使用委托的近似裁剪矩形。

Ticker 和轨道集合只为实际过渡创建；首次挂载或仅声明 transitions 不启动时钟。
动画只采样活动轨道，不重建 ElStyle 或 child；固定尺寸采样值未变时不请求布局，
纯颜色、渐变、阴影、透明度、圆角、边框或轮廓变化只重绘，也不重新解析尺寸和边距。
变换与原点也不触发布局，同时更新语义；未声明 transform 时不创建矩阵、几何或变换层。
滤镜和路径变化不重新布局，模糊只扩大绘制边界；路径更新同步重绘与语义，clipper 不参与插值。

```dart
ElView(
  style: ElStyle(
    width: 160,
    height: 80,
    backgroundColor: const Color(0xff409eff),
    borderRadius: BorderRadius.circular(16),
    outline: const ElOutline(width: 2, color: Color(0xff409eff), offset: 3),
    clipBehavior: Clip.antiAlias,
    transitions: const [
      ElTransition.field(ElTransitionField.borderRadius),
      ElTransition.field(ElTransitionField.outline),
    ],
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

新增样式功能测试集中在 `test/ui/cores/view/base_test.dart` 和 `animation_test.dart`，均通过
真实 `ElView(style: ElStyle(...), child: ...)` 环境验证实际布局、绘制与命中。
前者覆盖正常情况下的基础功能，后者覆盖插值中间值、auto/百分比转换、延迟、中断、
方向变化、null/半透明颜色及裁剪联动等边界。测试不依赖内部状态、调用次数、缓存身份或
图层复用情况；不编写持久性能测试，真机流畅度由使用者体验验收。

`ElStyle` 的 copyWith、merge、比较字段列表通过 `ElModelGenerator` 生成：省略参数
保留原值，copyWith 显式 null 清空，merge 忽略 null 且整体替换过渡列表。
新增属性时补充样式声明、StyleField 的解析/插值/失效规则及对应执行器消费，保持
Render 调度骨架稳定，再重新生成模型代码。相关验证只运行本次文件：

```powershell
dart run build_runner build --build-filter 'lib/src/ui/cores/view/style/index.g.dart'
flutter test test/ui/cores/view --concurrency=1
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

事件实现在 `lib/src/ui/cores/event/`，只依赖 Dart、Flutter 和自身目录，不依赖 ElView、
样式、滚动、投影或选区模块。交互状态由后代自行用于改变样式；本次不包含键盘、
焦点或全局指针屏障。
内部 dispatcher 与状态机不从公共入口导出。

```powershell
flutter test test/ui/cores/event --concurrency=1
```
