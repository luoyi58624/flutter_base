# 命令式节点 API 实验计划

日期：2026-11-06。状态：计划，尚未实现。

## 1. 目标与预期

给高频更新的场景（主要是 RecyclerView 行）提供一套原生风格的命令式 UI 节点：节点创建后常驻，通过 `add` / `remove` 组合，通过属性 setter 更新，不经过 Widget 和 Element。

```dart
final title = ElTextNode('标题');
final row = ElBoxNode(layout: ElFlexLayout.row(gap: 12))..add(title);
title.text = '新标题'; // 等价于 setText：不 build、不 diff，直接让文字节点重排
```

Flutter 的三层（Widget → Element → RenderObject）在节点内部收敛为一层：每个节点只有一个渲染对象，加一个很薄的 Dart 句柄（Android 同样是 Java View 加原生 RenderNode 两个对象）。只有挂进 Flutter 树的边界上保留一个 Widget：`ElNodeHost`。

### 实验要回答的问题

1. 去掉 Widget 和 Element 两层后，RecyclerView 换绑和快速甩动时 UI 线程能省多少。
2. 命令式组合在列表行这类热点上的开发体验是否可以接受。

### 预期上限（先说清楚）

命令式更新只省掉 build、Element 比对和 updateRenderObject；样式解析、文字排版、绘制、光栅一步都省不掉。现有主机 Debug 数据给出的信号是矛盾的：

- 纯 TextPainter 换短文本 30–50µs（[TEXT_UPDATE_RESULTS.md](../flutter/views/recycler_view/TEXT_UPDATE_RESULTS.md)）。
- 快速跨屏时每次换绑约 0.6ms，排版只占不到一成。

剩下的时间里有多少属于"可去掉的 Widget 层"，Debug 下看不出来，Profile 下会更小。所以第 0 阶段先做一个最小对照，用数字决定要不要继续投入性能论证。即使性能收益很小，API 实验本身也可以继续，但结论要如实写成"没有性能收益"。

## 2. 范围

**包含**

- 三种节点：`ElBoxNode`（div：盒模型、绘制、子节点布局）、`ElTextNode`、`ElImageNode`。
- 三种布局：Flex（Row / Column）、Grid、Stack。
- 复用现有 ElStyle 全套能力：盒模型、背景边框阴影、变体（hover / tap / disabled / dark）、过渡、关键帧、变量与暗色级联、文本继承。
- 复用 ElEvent 事件、ElSemantics 语义。
- 唯一的边界 Widget `ElNodeHost`，负责把节点树挂进 Flutter 树、推送环境。
- RecyclerView 接入与对照示例。

**不包含（本实验阶段）**

- 节点内嵌 Widget：不接受 Widget 子节点，也不支持 WidgetSpan。
- 命令式版本的业务组件（按钮、复选框等）。示例里的复选标记用 box + 图标文字组合。
- 文本输入。
- 桌面键盘焦点与焦点遍历：第 4 阶段只做调研。移动端默认本来就不创建焦点。
- 自定义布局策略：先封闭为三种，避免过早承诺扩展接口。
- 从 `flutter_base.dart` 导出：实验入口单独导入。

## 3. 关键决策

### D1 复用 hosted ElRenderView，不复制样式引擎

ElRenderView 本身就是完整的渲染层引擎（盒模型、样式级联、动画、事件、语义、文本），而且已经支持不经 Element、由 RenderObject 宿主直接持有：

- 构造函数注释为"render 层正门"，`_hosted` 模式下 textScaler、locale 取平台兜底，Widget 载荷会断言。
- 表格已经这样用它：[table_grid.dart](../flutter/views/table/table_grid.dart) 直接创建 `ElRenderView(style:, child:)` 作为单元格，命令式更新 `style` 和文本，自己负责 dispose。

所以"迁移样式处理"的做法是复用这个渲染对象，而不是把约 1 万行的样式引擎复制一份：复制会让两套引擎分叉，后续每个修复都要做两遍。

样式继承也天然成立：ElRenderView 沿渲染父链查找 `InheritableNode`，往下传播时也会穿过普通 RenderObject。命令式节点作为真实的 RenderObject 挂在 ElComponentProvider 的 ElView 下面，主题变量、onDark、文本继承都能直接收到，不需要额外代码（第 1 阶段要用测试确认）。

### D2 句柄包装渲染对象，而不是继承它

| 方案 | 优点 | 问题 |
| --- | --- | --- |
| 节点类直接继承 ElRenderView | 零额外对象 | 继承了 RenderObject 和 ElRenderView 的全部公共方法；`add(RenderBox)` 来自 ContainerRenderObjectMixin，无法改成 `add(ElNode)`，`remove` / `insert` / `firstChild` 的语义会和节点子列表冲突；以后想把盒子和布局合成一个渲染对象就得改公共类型 |
| **节点是薄句柄，内部持有渲染对象（采用）** | API 干净，可以自由使用 `add` / `remove` / `children`；渲染实现可替换；和 Android 的 View + RenderNode 模型一致 | 每个节点多一个只有几个字段的 Dart 对象 |

句柄不参与任何框架阶段：没有 build、没有 diff、没有生命周期遍历，只转发属性并维护父子关系，所以不算重新引入一层。

### D3 命名

现有的 `ElView`（Widget）、`ElImageView`（Widget）以及 Flutter 自己的 `View` 都已经被占用，而命令式节点会和 ElView 出现在同一个文件里（宿主就在 Widget 树中），用前缀导入只会制造混淆。因此统一使用 Node 后缀，并按仓库规则加 El 前缀：

| 类 | 职责 |
| --- | --- |
| `ElNode` | 抽象基类：样式、事件、语义、布局参数、可见性、父节点、释放 |
| `ElBoxNode` | div：盒模型 + 子节点 + 布局策略 |
| `ElTextNode` | 文本：String、TextSpan（不含 WidgetSpan）、IconData |
| `ElImageNode` | 图片：ImageProvider、fit、alignment、加载回调 |
| `ElFlexLayout` / `ElGridLayout` / `ElStackLayout` | 布局策略（不可变配置对象） |
| `ElFlexParams` / `ElGridParams` / `ElStackParams` | 子节点布局参数，基类 `ElLayoutParams` |
| `ElGridTrack` | 网格轨道：fixed / fr / auto |
| `ElVisibility` | visible / invisible / gone |
| `ElNodeHost` | 唯一的边界 Widget |

入口参照 `recycler_view.dart`：新增 `lib/view.dart`，导出 `src/view/index.dart`。

### D4 布局是可替换的策略，参数挂在子节点上

`ElBoxNode` 相当于 div，它的 `layout` 相当于 CSS 的 `display`，子节点的 `layoutParams` 相当于 Android 的 LayoutParams。选择策略对象而不是 `ElRowNode` / `ElGridNode` 子类，原因是：

- 命令式树最大的好处之一，是可以在不重建节点的前提下切换布局，比如宽屏用 Row、窄屏用 Column。
- 盒模型和布局是两件事：盒子只有一个类，布局能力以组合的方式加上去。

参数类型和布局不匹配时（比如 Grid 下的子节点挂了 `ElFlexParams`），开发模式下断言并给出可读的提示，发布模式按默认参数处理。

### D5 第一阶段不修改 ElRenderView

现有 ElRenderView 的内容层只认三种情况：文本载荷、单个 RenderBox 子节点、空。多子布局有两种接法：

1. **（第 1–3 阶段采用）** `ElBoxNode` 内部是"盒子 ElRenderView + 一个私有布局 RenderBox"，用户子节点挂在布局 RenderBox 下面。ElRenderView 只看到一个子节点，命中、绘制、内在尺寸、基线都走它现有的单子路径，不需要改它。
2. **（第 4 阶段视测量结果决定）** 给 ElRenderView 加一个内部、可空的内容委托，盒子和布局合成一个渲染对象。

先选方案 1 的原因：render_view.dart 是最热的核心文件，另一个会话还在修改 text_engine 和 RecyclerView viewport。实验期间零侵入，出问题也不会影响现有 ElView。容器节点比叶子少得多，多出来的那个渲染对象要等测量结果证明值得省，才去合并。

### D6 所有权与释放

- 节点由创建者持有。`remove` 只摘下，不释放；摘下的节点可以重新 `add`（用于复用）。
- `dispose()` 释放当前节点及其全部后代（渲染对象、图片流、动画时钟、事件分发器）。已释放的节点不能再挂载，开发模式断言。
- `ElNodeHost` 默认不拥有根节点：它卸载时只摘下根节点，由 State 或 ViewHolder 在自己的 dispose 中释放。
- 一个节点同一时刻只能有一个父节点（RenderObject 的 adoptChild 已有断言，句柄层再给一条可读提示）。

### D7 什么时候可以修改

节点修改最终落到 `markNeedsLayout` / `markNeedsPaint` / adoptChild 上，遵守 Flutter 的规则：

- 可以：事件回调、定时器、微任务等帧外时机；祖先布局回调内部，比如 RecyclerView 在 `invokeLayoutCallback` 中执行的 bind。
- 不可以：paint 期间、语义更新期间、和本节点无关的子树布局期间。

同一个事件里多次修改会自然合并到下一帧，不需要额外的批处理 API。

### D8 环境由宿主推送

节点没有 BuildContext，环境由 `ElNodeHost` 从自己的 context 读出来，存成内部的环境快照，节点挂载（attach）时沿渲染父链找到宿主并缓存：

| 环境 | 来源 | 消费者 |
| --- | --- | --- |
| textScaler、boldText | MediaQuery | 文字节点。覆盖 hosted 节点的平台兜底，否则应用层的 MediaQuery 覆写会失效 |
| locale、textDirection | Localizations、Directionality | 文字、Flex 的水平方向、图片 |
| devicePixelRatio、platform | MediaQuery、Theme | 图片的 ImageConfiguration |
| TickerMode | `TickerMode.getValuesNotifier` | El 动画时钟（现有 `bindTickerModeSource` / `refreshTickerMode`），动图帧 |
| 换绑跳过过渡 | `ReuseAnimationScope` | 现有 `skipReuseTransitions` 回调 |
| SelectionRegistrar | `SelectionContainer.maybeOf` | 可选中文本（第 4 阶段） |

环境变化很少发生。变化时宿主遍历一次节点树，只让受影响的节点失效（比如字号缩放变了，只让文字节点重新排版）。

### D9 换绑时跳过过渡

命令式 `bind` 里换样式会触发 ElStyle 过渡。`style` setter 是同步执行 `_reresolve` 的，所以可以用同步作用域：

- `ElNode.withoutTransitions(() { ... })`：作用域内的 setter 直接提交目标值。这相当于 Android 的 `jumpDrawablesToCurrentState`。
- 在 RecyclerView 里不需要手写：宿主的跳过回调读取 `ReuseAnimationScope`，跨记录换绑时自动生效，同一条记录的更新照常播放过渡。

## 4. 架构与目录

```
Flutter Widget 树
  └─ ElNodeHost                       唯一 Widget：读环境、挂根节点
       └─ _RenderNodeHost             RenderBox 单子宿主：环境快照、生命周期
            └─ ElBoxNode（句柄）
                 render: _RenderBoxNode extends ElRenderView     盒模型、样式、事件、语义
                   └─ _RenderNodeLayout                          flex / grid / stack 布局
                        ├─ ElTextNode.render: _RenderTextNode extends ElRenderView（文本载荷）
                        ├─ ElImageNode.render: _RenderImageNode extends ElRenderView
                        │    └─ RenderImageView                  复用现有加载、解码、缓存
                        └─ ElBoxNode.render ...
```

```
lib/view.dart                     实验入口，参照 recycler_view.dart
lib/src/view/
  PLAN.md                         本文件；实现后改写为 README.md
  index.dart                      公共导出清单
  node.dart                       ElNode、ElVisibility、ElLayoutParams、withoutTransitions
  box_node.dart                   ElBoxNode、_RenderBoxNode
  text_node.dart                  ElTextNode、_RenderTextNode
  image_node.dart                 ElImageNode、_RenderImageNode
  host.dart                       ElNodeHost、_RenderNodeHost
  environment.dart                环境快照与变更分发（内部）
  layout/
    layout.dart                   _RenderNodeLayout、策略接口（内部）
    flex.dart                     ElFlexLayout、ElFlexParams
    grid.dart                     ElGridLayout、ElGridParams、ElGridTrack
    stack.dart                    ElStackLayout、ElStackParams
test/view/                        无头测试
```

依赖方向是 view → flutter（复用样式、文本、图片、事件模块），flutter 不能反向依赖 view。

## 5. API 草案

### ElNode（抽象基类）

| 成员 | 说明 |
| --- | --- |
| `ElStyle? style` | 转发给 ElRenderView.style；identical 早退、同步 diff、可触发过渡 |
| `ElEvent? event` | 复用现有事件分发 |
| `ElSemantics? semantics` | 复用现有语义 |
| `ElLayoutParams? layoutParams` | 父节点布局使用；修改时只让父节点重新布局 |
| `ElVisibility visibility` | visible；invisible 参与布局但不绘制、不命中；gone 不参与布局 |
| `ElBoxNode? get parent` | 父节点 |
| `void removeFromParent()` | 从父节点摘下，不释放 |
| `Object? tag` | 测试与调试标记 |
| `void dispose()` | 释放自身及后代 |
| `static void withoutTransitions(VoidCallback action)` | 作用域内跳过状态过渡 |

### ElBoxNode

```dart
ElBoxNode({ElNodeLayout layout = const ElFlexLayout.column(), ElStyle? style, ElEvent? event,
  ElSemantics? semantics, ElLayoutParams? layoutParams, bool repaintBoundary = false})
```

- `ElNodeLayout layout`：相等时早退，否则只让布局 RenderBox 重新布局。
- 子节点：`add`、`addAll`、`insert(index, node)`、`remove`、`removeAt`、`clear`、`move(node, toIndex)`、`children`（只读视图）、`childCount`。
- `repaintBoundary` 只能在构造时指定。Flutter 要求 `isRepaintBoundary` 在对象生命周期内保持不变，列表行的根节点一般需要开。
- 默认布局是 `ElFlexLayout.column()`，和 Flutter Column 的默认值一致；不模仿 CSS block 的拉伸行为，避免同一个仓库里出现两套默认值。

### ElTextNode

```dart
ElTextNode([Object? text, ElStyle? style])
```

- `Object? text`：String、不含 WidgetSpan 的 InlineSpan、IconData。转发给现有的 `setTextPayload`，由 TextEngine 判断只重绘还是要重排。
- 不能有子节点。文本样式来自 `style`，加上祖先节点和祖先 ElView 的继承。

### ElImageNode

```dart
ElImageNode({ImageProvider? image, BoxFit? fit, AlignmentGeometry alignment = .center,
  bool gaplessPlayback = true, ElStyle? style, ...})
```

- 外层盒子 ElRenderView 负责圆角、边框、占位背景和裁剪；内层 RenderImageView 负责加载、解码、缓存（直接复用 ElImageView 的渲染对象）。
- `image`、`fit`、`alignment`、`color` / `colorBlendMode`、`filterQuality` 都有 setter。
- `onLoad`、`onError` 回调接在现有的 `ImageLoadPhaseCallback` 上。
- 列表里建议显式给宽高，否则图片加载完成后按自然尺寸重新布局，行高会跳。
- 被隐藏时（TickerMode 关闭或 gone）停止接收动图帧，可见后恢复。

### 布局

**ElFlexLayout**：`.row()` / `.column()`，参数 `mainAxisAlignment`、`crossAxisAlignment`（start / center / end / stretch / baseline）、`mainAxisSize`、`gap`。语义对齐 Flutter 的 RenderFlex：

- 非弹性子节点在主轴上用宽松约束测量；弹性子节点按 `ElFlexParams(flex:, fit:)` 分配剩余空间。
- 主轴无界时出现弹性子节点会断言，和 Flutter 一致。
- 水平方向的顺序取 `style.direction`，没有则取宿主环境。
- 溢出不画调试条纹，裁剪交给盒子样式的 clipBehavior。
- 子节点可以用 `ElFlexParams.alignSelf` 覆盖交叉轴对齐。

**ElGridLayout**：`columns: List<ElGridTrack>`，或 `.count(n)`（等于 n 个 `fr(1)`）；另有 `rowGap`、`columnGap`、`autoRows`。

- 轨道：`fixed(px)`、`fr(n)`、`auto`。`auto` 需要查询内在宽度，放在第 2 阶段后半。
- 子节点 `ElGridParams(column:, row:, columnSpan:, rowSpan:, alignment:)`；未指定位置时按行优先自动放置，跳过已占用的格子（不做 dense 回填）。
- 行高：自动行取本行单行子节点的最大高度。跨行子节点超出时，把差值补到它跨越的最后一行。这是简化规则，文档里写明。
- 宽度无界时使用 `fr` 会断言，发布模式下按 `auto` 处理。

**ElStackLayout**：`alignment`、`fit`（loose / expand）。

- `ElStackParams(left, top, right, bottom, width, height)` 中只要有一个非空就是定位子节点。
- 尺寸规则和绘制顺序对齐 Flutter Stack：按子节点顺序绘制，命中测试逆序。

所有布局都要实现 dry layout、四个内在尺寸和基线，否则放进 IntrinsicHeight、基线对齐的 Row 这类父级时会出错。

### 使用示例（复选行）

```dart
class SelectionRow {
  SelectionRow(VoidCallback onToggle)
    : root = ElBoxNode(
        layout: ElFlexLayout.row(gap: 14, crossAxisAlignment: .center),
        style: ElStyle(height: 88, padding: .symmetric(horizontal: 16)),
        event: ElEvent(onTap: (_) => onToggle()),
        repaintBoundary: true,
      ) {
    root
      ..add(mark..add(check))
      ..add(texts..add(title)..add(description));
  }

  final ElBoxNode root;
  final mark = ElBoxNode(layout: ElStackLayout(alignment: .center), style: _unchecked);
  final check = ElTextNode(Icons.check, ElStyle(iconSize: 14, iconColor: Colors.white));
  final texts = ElBoxNode(layout: ElFlexLayout.column(gap: 4), layoutParams: ElFlexParams(flex: 1));
  final title = ElTextNode(null, ElStyle(fontWeight: .w600));
  final description = ElTextNode(null, ElStyle(fontSize: 12, maxLines: 1, textOverflow: .ellipsis));

  // 换绑只改数据；样式对象预先创建，identical 早退几乎零成本。
  void bind(Item item, bool checked) {
    title.text = item.title;
    description.text = item.description;
    mark.style = checked ? _checked : _unchecked;
    check.visibility = checked ? .visible : .invisible;
  }
}

class _Holder extends rv.ViewHolder {
  _Holder(this.row) : super(ElNodeHost(root: row.root));
  final SelectionRow row;
}
```

## 6. 与现有机制的衔接

| 机制 | 处理方式 | 阶段 |
| --- | --- | --- |
| 样式级联、变体、过渡、关键帧 | ElRenderView 原样提供 | 1 |
| 主题变量、onDark、文本继承 | 沿渲染父链自动继承，测试确认穿透宿主和布局 RenderBox | 1 |
| 命令式读取主题变量 | 新增渲染层 `getVar` 和变量监听。现有 `getVar` 依赖 Element 订阅，需要在 ElRenderView 加一条渲染层通知，会碰核心文件。在此之前优先用 onDark 变体，让引擎处理 | 4 |
| ElEvent、hover、按压样式 | 渲染层分发器原样可用，`requestFocusForEvent` 留空 | 1 |
| 语义 | 渲染层原样可用 | 1 |
| TickerMode | 宿主环境通过 `bindTickerModeSource` 提供，attach 时调用 `refreshTickerMode` | 1 |
| 换绑跳过过渡 | `skipReuseTransitions` 回调 = 节点作用域 ∪ 宿主的 ReuseAnimationScope | 1 |
| RecyclerView | `ViewHolder(ElNodeHost(root: ...))`，bind 里直接调用 setter | 3 |
| 文本选择 | 宿主提供 registrar | 4 |
| 键盘焦点 | 需要 FocusNode 子类，用节点自己的几何覆盖 `rect`，再挂到宿主 context 下面。`ensureVisible` 按 context 滚动，可能定位到宿主而不是节点，先调研 | 4 |

## 7. 开发体验上的代价

这些是声明式框架本来替你解决的问题，实验结论里必须一起评估：

- **热重载**：节点在构造代码里只创建一次，热重载不会重新执行。宿主提供 `onReassemble` 回调，让调用方重建节点树；否则只能热重启。
- **调试工具**：Widget Inspector 只能看到 `ElNodeHost`。节点要实现 `debugFillProperties` 和 `toStringDeep`，在 Render Tree 里可读。
- **测试**：`find.text` 找不到节点里的文字。需要提供测试辅助（按文本、按 tag 查找节点）。
- **状态一致性**：命令式最常见的 bug 是换绑时漏改某个字段，导致显示上一条记录的数据。示例和文档要求 bind 方法一次性写全所有字段，测试覆盖"换绑后不残留旧数据"。
- **适用范围**：建议只用在列表行这类经过测量的热点上；页面级 UI 继续用 Widget。

## 8. 分阶段实施

每个阶段只跑本阶段相关的无头测试。Linux 侧不运行 Flutter 工具链，命令统一在 Windows 执行。

### 阶段 0：最小对照（门槛）

用测试内的原型对比三种行：HookWidget + ElView 字符串、ValueListenableBuilder + Text、渲染层直接绑定。看换绑工作量和同步布局耗时，然后用户在手机上用 DevTools CPU profiler 录一段快速甩动，看 build / Element 更新占每行成本的比例。

- 退出条件：拿到 Profile 下的比例。比例小于 20% 时，后续阶段只作为 API 实验推进，不再以性能为卖点。

### 阶段 1：骨架与 Flex

- 入口 `lib/view.dart`；`ElNode`、`ElBoxNode`、`ElTextNode`；`ElNodeHost` 与环境；`_RenderNodeLayout` + `ElFlexLayout`；可见性；`withoutTransitions`。
- 测试：
  - 增删改与父子约束；
  - 几何对照：和等价的 Flutter Row / Column 比较子节点偏移，覆盖 gap、各种对齐、flex、RTL、基线；
  - 文本更新的工作量；
  - 祖先 ElView 的变量、暗色、文本继承能否穿透到节点；
  - tap、hover 变体、stopPropagation；
  - dispose 与泄漏；
  - 非法时机修改时的断言。
- 退出条件：L0 中的 V0-1 至 V0-7、V0-9、V0-10 通过。

### 阶段 2：Stack 与 Grid

- `ElStackLayout`、`ElGridLayout`（先做 fixed / fr / count，再做 auto 轨道和跨格）。
- 所有布局补齐 dry layout、内在尺寸、基线。
- 测试：和 Flutter Stack、固定列网格做几何对照；自动放置；跨行补高；无界约束下的断言。

### 阶段 3：图片节点与 RecyclerView 对照

- `ElImageNode`：复用 RenderImageView，环境提供 ImageConfiguration，加载回调，隐藏时暂停动图。
- 示例：在纯文本、复选、复杂卡片三个页面的容器菜单里增加"RecyclerView（命令式）"模式。数据和外观与现有行一致，复选标记用 box + 图标文字组合。
- 测试：
  - 换绑时零 Element 增删、零 build；
  - 跨记录换绑跳过过渡，同一记录的更新保留过渡；
  - 回收池中 El 动画时钟静音、图片监听暂停；
  - 换绑后不残留旧数据。
- 退出条件：L0 全部通过，L1 对照数据写入结果文档。

### 阶段 4：真机验收与取舍

- 用户在手机上用现有帧耗时记录器，按 [PERFORMANCE_ACCEPTANCE.md](../flutter/views/recycler_view/PERFORMANCE_ACCEPTANCE.md) 的 L2 流程采样。
- 视结果决定：
  - 是否把盒子和布局合成一个渲染对象（D5 方案 2）；
  - 是否做渲染层变量监听、文本选择、桌面焦点；
  - 实验是继续、冻结还是删除。

### 阶段 5（仅在成功时）

用 README.md 替换本计划，补齐对外文档和测试辅助。是否从主入口导出，另行决定。

## 9. 验收

### L0 结构门禁（无头、确定性，阶段 1–3 的硬门槛）

| 编号 | 断言 |
| --- | --- |
| V0-1 | 宿主子树中 Element 数恒为 1（宿主自身），和节点数量无关 |
| V0-2 | `text.text = 新值`：0 次 Widget build；该节点 1 次文字排版；重新布局只传播到最近的 relayout boundary |
| V0-3 | 设置相同文本或 identical 样式：0 次布局、0 次绘制 |
| V0-4 | 只影响绘制的样式变化（例如颜色）：0 次布局、1 次绘制 |
| V0-5 | Flex / Stack / Grid 和等价 Flutter 布局的子节点偏移一致（含 RTL、基线、gap） |
| V0-6 | 祖先 ElView 的 vars、onDark 切换会传到节点，不需要重建宿主 |
| V0-7 | 节点上的 tap、hover 变体、stopPropagation 和 ElView 行为一致 |
| V0-8 | RecyclerView 换绑：0 次 Element 增删、0 次 build；跨记录换绑跳过过渡；回收池中动画时钟静音、图片监听暂停 |
| V0-9 | `dispose` 后全部渲染对象已释放，图片流、动画时钟、监听都已移除 |
| V0-10 | 在 paint 期间或无关子树布局期间修改节点会触发可读的断言 |

### L1 主机相对基准（仅作诊断）

沿用 [REUSE_RESULTS.md](../flutter/views/recycler_view/REUSE_RESULTS.md) 的协议：

- 对比矩阵：三种行（纯文本、复选、卡片）× 三种容器（ListView Widget 行、RecyclerView Widget 叶子、RecyclerView 命令式）。
- 场景：快速跨屏（关闭缓存）和 3px 小幅滚动。
- 交替运行 5 轮，丢弃 20% 作为预热。
- 记录 P50 / P95、轮间范围，以及 build 次数、更新次数、排版次数。
- Debug JIT 的数字不能写成"提速百分比"。

### L2 真机（用户执行，Profile）

- 成功判据：快速甩动时，命令式行的 UI P99 比 RecyclerView Widget 叶子行低，且差值大于 max(10%, 轮间范围)；正常滚动的帧不变差；单行驻留对象数和内存不增加。
- 如果达不到：结论写成"在这台设备上没有可感知的性能收益"，再决定是否为了 API 本身保留实验。

## 10. 风险与开放问题

1. **hosted 模式的成熟度**：目前只有表格单元格在用，它覆盖的能力有限。焦点、选区注册、Widget 层的 `ElView.of` 订阅都假定有 Element。阶段 1 要先列出 hosted 模式下可用 / 不可用的能力清单，并用测试固定下来。
2. **单节点体积**：ElRenderView 字段很多，命令式只去掉了 Widget 和 Element，渲染对象本身没有变轻。驻留数量和内存要实际测量。
3. **平台兜底与宿主推送并存**：hosted 节点的 textScaler 在没有推送时读平台值，宿主推送后会永久关闭兜底。节点挂到不同宿主之间（复用、移动）时，环境要重新取值，需要专门测试。
4. **主题变量的命令式读取**需要改 ElRenderView，和其他会话的改动有冲突风险，所以放在第 4 阶段。
5. **焦点**可能需要自定义 FocusNode 和滚动定位，桌面端能否接受还不确定。
6. **和在途工作的协调**：阶段 1–3 不修改 `render_view.dart`、`text_engine.dart`、`recycler_view/viewport.dart`。阶段 4 如果要改，先确认其他会话的改动已经提交。

## 11. Windows 侧命令

阶段内只格式化、分析和测试本次涉及的文件：

```powershell
dart format lib/view.dart lib/src/view test/view
flutter analyze lib/view.dart lib/src/view test/view
flutter test test/view --no-pub --concurrency=1 --timeout=90s
```

阶段 3 的示例测试：

```powershell
cd example
flutter test test/recycler_node_rows_test.dart --no-pub --concurrency=1 --timeout=90s
```
