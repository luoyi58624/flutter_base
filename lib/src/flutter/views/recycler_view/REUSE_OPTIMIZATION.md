# 结构复用优化方案

日期：2026-11-06。初稿审计基于 `921ae77`；本轮实施基线为 `ac9ff5b`，包含此前鼠标平滑滚动、配置占位符与稳定宿主更新优化。本文已根据审阅修正为实际实施方案，各阶段状态见第 6 节；最终测试通过数量、前后性能数据由结果报告记录，本文不预填。验收方法见[性能验收](PERFORMANCE_ACCEPTANCE.md)。

RecyclerView 的收益来自「同类型条目换绑时只更新变化的叶子」。内核负责保留 holder 的 Element、State 和 RenderObject；能否真正只更新叶子，还取决于行的写法、双向绑定组件的同步时机，以及组件在换绑和隐藏时是否带出旧状态。本文按这三层列出现状、问题和优化思路。

## 优先级总览

| 优先级 | 项目 | 影响范围 | 改动风险 |
| --- | --- | --- | --- |
| P0 | El 样式动画时钟接入 `TickerMode`，避免池中、离屏和被覆盖路由里的动效继续请求帧 | 所有使用 `ElStyle.transition`、`keyframes` 的组件 | 中，涉及懒创建与生命周期 |
| P0 | `ElModelValue` 同帧回灌，并正确处理外部通知与重入 | 全部受控用法的双向绑定组件 | 中，须保护通知契约 |
| P1 | holder 局部跳过跨记录换绑过渡，保留同记录交互与持续关键帧 | 开关、标签、进度、复选等带过渡的组件 | 中 |
| P1 | 复选框、单选框改为两端轻量品牌实现，移除示例的 generation Key 规避 | 列表中的选择控件 | 中，须保护事件、分组、语义与焦点 |
| P2 | 一批结构通知合并为一次最终类型扫描，保持类型可依赖位置及数据数量的契约 | 聊天加载历史等结构变更 | 中，须覆盖批处理与中途读取 |
| P2 | 重类型首次挂载超出预取预算，只能在进屏帧同步创建 | 复杂卡片等重行 | 中 |
| P3 | 池中子树驻留：主题、字号变化会一起重建；GlobalKey 与隐藏 Hero 旧副本可能重复 | 重行、带 Hero 的行 | 中，须保护隐藏资源生命周期 |
| P3 | 非双向用法的 `ElButton` 等组件也创建模型 Hook、Obs 和监听构建器 | 行内多按钮 | 先测量再决定 |

## 1. 已完成的滚动优化

上一轮分析列出的内核问题，已由此前提交处理：

| 问题 | 现状 | 位置 |
| --- | --- | --- |
| 空修正 `correctBy(0)` 每帧重启惯性 | 已修复：`_correctOffset` 只提交超过容差的修正 | `viewport.dart` `_correctOffset` |
| 每帧为每个可见项新建包装组件 | 已修复：`_host` 按可见性缓存包装描述，稳定项更新被同实例截断 | `viewport.dart` `_host` |
| 稳定项仍进入 `buildScope` 与宿主更新 | `ac9ff5b` 已跳过稳定宿主的重复更新，保留必要布局调用；相同约束下 RenderObject 自行短路 | `viewport.dart` `_obtainAndLayout` |
| 向上滚入未测量区域时以首项为锚导致跳动 | 已修复：优先以已在屏的条目为锚补测 | `viewport.dart` `_layoutLinear` 的 `retainedAnchor` |
| 内容通知全表重建高度索引 | 已修复：`invalidate` 只处理受影响区间 | `viewport.dart` `_ExtentIndex.invalidate` |
| 预取结果与离屏项共用 2 格缓存被挤掉 | 已修复：`_prefetched` 单独计额，`_trimCache` 优先淘汰普通项 | `viewport.dart` `_trimCache` |
| 物理写死 `ClampingScrollPhysics` | 已修复：未传 physics，跟随 `ScrollConfiguration` | `recycler_view.dart` |
| 聊天首屏先按估高猜窗口、多绑定两条 | 已修复：`stackFromEnd` 首次布局从末项实测向前填充 | `viewport.dart` `_layoutInitialTail` |
| 示例行用随业务 ID 变化的 Key，换绑时整棵子树重挂 | 已修复：复选、聊天、卡片改为固定结构加叶子监听 | 示例 `selection.dart`、`chat.dart`、`cards.dart` |

另外更正上一轮的一个判断：`_layoutLinear` 末尾每次布局调用 `markNeedsSemanticsUpdate()` 不构成性能问题。语义关闭时它在 `RenderObject` 内立即返回；语义开启时滚动本来就要更新节点坐标，官方 `ListView` 也会每帧更新滚动语义。

## 2. ElModelValue

### 2.1 实施前：三条写入通道

初稿所依据实现中，`ElModelValue` 用 Hook 持有内部 `Obs`，`build` 返回监听该 Obs 的 `ListenableBuilder`，子类 `obsBuilder` 读取 `$obs.value`。三条通道的契约如下；优化调整渲染时机，不改变命令语义。

| 写入来源 | 实施前路径与时机 | 是否回调 `onChanged` |
| --- | --- | --- |
| 父级传入新的 `value` | `didUpdateHook` → `safeCallback(_receiveValue)`；构建期回灌在帧后生效 | 否，父级派生输入不能成为业务命令 |
| 外部写入 `modelValue` | `_linkRawObs` 静默设值后同步通知内部 Obs | 是，外部变更也通知一次，并截断同值回声 |
| 组件自身交互 | `$obs.value = v` 同步通知 | 是 |

相关源码：[hook.dart](../../utils/model_value/hook.dart)、[index.dart](../../utils/model_value/index.dart) 与 [common.dart](../../commons/common.dart)。

### 2.2 现设计的理由

- **构建期通知可能越界。** 在 build 中写 `Obs` 会同步通知全部监听者。监听者可能不在当前构建目标的子树里，例如品牌放进弹层的内容、表单状态、自动收集依赖的 `ObsBuilder`、共享同一个外部 `ValueNotifier` 的其他组件。Flutter 在 debug 下会对这种越界标脏断言「markNeedsBuild called during build」。监听者拓扑无法在运行时廉价确认，`safeCallback` 是一刀切的安全阀。
- **回灌不能变成命令。** `value` 是父级的派生输入，例如分组的全选状态。回灌如果触发 `onChanged`，会被当成用户发出的「清空整组」等命令，所以用 `_receivingValue` 截断。
- **`modelValue` 是共享模型。** 外部写入通常发生在事件阶段，同步通知是安全的。「外部变更也回调一次」让联动和表单能感知变化；当前复选示例的整行点击也依赖它：整行写 `model.checked`，再由复选框的 `onChanged` 更新选择集合。

### 2.3 问题

1. **受控值晚一帧。** 父级改 `value` 后，当帧 `obsBuilder` 读到的仍是旧值；帧后回调写入并通知，再触发一帧，整个组件重建一次。自身交互不受影响，因为交互先在事件阶段写入了 Obs；受影响的是「由外部驱动的变化」，例如全选、表单重置，以及 ListView 或 RecyclerView 的换绑。
2. **两条外部通道时机不一致。** 实施前 `value` 推迟、`modelValue` 同步。示例持有的行内模型监听位于视口后代，绑定时可在对应 buildScope 内同步刷新；这只是示例的已知拓扑，不能推广成公共 ElModelValue 的所有监听者都位于视口后代。
3. **换绑写入会触发回调。** holder 在绑定时写 `modelValue`，会走「外部变更也回调一次」，业务回调必须幂等，或像示例那样用 `receiving` 标志截断。
4. **固定成本。** 每个实例都有 Hook、Obs 和一层 `ListenableBuilder`。`ElButton` 的普通构造也继承这套结构（`super(value: false)`），即使不做双向绑定。

### 2.4 优化思路

#### 方案 A：同帧渲染，帧后补发其余监听者（本轮实施）

构建期收到不同的 `value` 时，静默写入内部 Obs，使当前构建直接使用新值；组件自身的渲染监听与 Obs 的其余通知分离。帧后补发仍保护子树外监听者，已经渲染过的同值不再使组件自身重复构建。

初稿的全程 `_replaying` 布尔屏蔽不可采用：外部监听者可能在补发过程中同步把值修正为另一个值。如果把整个通知栈都屏蔽，内部值已经改变，界面与业务回调却可能停留在旧值。

实施必须满足：

1. 同值输入直接返回；多次尚未送达的回灌合并，卸载后取消待补通知。
2. 只跳过已经由当前构建渲染过的回放，按值或通知版本识别；真正的新写入仍进入正常更新路径。
3. 补发期间监听者重入写入新值时，新值必须触发自身渲染，并按原契约处理 `onChanged`；不能被“父级输入不产生命令”的守卫误吞。
4. 替换或清除 `modelValue` 时转移监听并保护在途通知，内部写入向外部模型传播时截断同值回声。
5. 继续保护跨组件、表单与弹层监听者的构建期安全；不能假设所有拿到 Obs 的监听者都位于当前 holder 子树。

主要收益是受控值同帧可见，并去掉组件自身为同一回灌额外执行的构建。独立订阅同一 Obs 的其他消费者仍可能在帧后更新，不能将“自身不重复构建”推广为整棵应用不会再产生帧。

#### 方案 B：通道拆分（可选，需要逐个审计）

子树内的监听者在组件自身 build 期间同步通知是合法的，问题只在子树外。可以把通知拆成两类：

- 渲染通道：组件自身和品牌子树使用，构建期同步通知；
- 外部通道：表单、弹层、跨组件联动使用，帧后通知。

前提是确认每个拿到 `$obs` 的品牌实现是否把它交给了子树外。需要审计的位置（按 `$obs` 引用整理）：桌面 `input`、`input_number`、`input_otp`、`input_tag`、`select`、`autocomplete`、`mention`、`nav_menu`、`button_group`，移动 `button_group`，以及 `ElForm` 的 `state._attach(this, $obs)`。复选、单选和列表分组通过 InheritedWidget 交给后代，属于子树内。

方案 A 已经消除了列表换绑的主要问题；方案 B 只在 L1/L2 数据显示「子树外晚一帧」确实造成问题时再做。

#### 方案 C：`onChanged` 语义保持不变，规范换绑写入

不建议取消「外部 modelValue 变更也回调一次」：示例的整行点击依赖它，表单联动也可能依赖它。holder 的写法统一为以下两种之一：

- 业务回调幂等：值没有变化就直接返回，例如复选示例的 `select`；
- 绑定期间设置守卫标志，回调中检查，例如复选示例的 `_SelectionModel.receiving`。

两者都满足时最稳妥。不为此新增「静默写入」API，避免出现与 `modelValue` 同职责的第二条通道。

#### 方案 D：固定成本（先测量）

普通 `ElButton` 可以在非 toggle 构造下跳过模型 Hook 和监听构建器。按「只做少做事、懒加载」的原则，等 L0 或 L1 数据显示行内按钮的固定成本确实可观时再做。

### 2.5 验收

方案 A 对应 L0-7：父级改 `value` 后一次 pump 即使用新值，组件自身不再因同值补发重复构建；普通受控开关、进度等原有合法动画仍允许继续。补充同值去重、合并回灌、通知重入、换模型、卸载与父级回灌不产生命令的反例测试。

## 3. 换绑与隐藏状态的动画治理

### 3.1 El 动画时钟接入 TickerMode（P0）

实施前 [frame_clock.dart](../view/style/animation/frame_clock.dart) 直接创建 `Ticker(_tick)`，未经过 `TickerProvider`；RecyclerView 的 `TickerMode(enabled: visible)` 因而只能关闭官方 Ticker，无法阻止离屏 El 过渡或无限关键帧请求新帧。被覆盖路由与显式禁用 TickerMode 的标签页也有同样问题。`Offstage` 自身不负责停表，必须有对应的 TickerMode。

实施方案：ElView 在确实创建动画时钟后懒订阅最近的 `TickerMode.getValuesNotifier(context)`，将启用状态及当前 SDK 的 `forceFrames` 传给底层 Ticker，避免无动画静态视图也新增一份常驻监听。祖先替换、deactivate/activate、跨树移动与销毁时都要转移或解除订阅。

静音不会清空动画业务状态。恢复时沿用 Flutter Ticker 的时间语义；已经启动的有限过渡可以追上经过的时间，无限关键帧继续运行。首次就在静音状态创建时尚未取得首个 tick，不能一概承诺恢复时立即完成，应单独测试这一分支。

验收 L0-6：先证明确实只剩池中的加载或过渡行，再等待停表后的尾帧排空，断言无持续请求；同时覆盖重新显示、初始静音、祖先替换、重挂与 `forceFrames`。可见区域中的正常加载指示器仍应持续运行。

### 3.2 仅跨记录换绑跳过状态过渡（P1）

复用同一个 holder 渲染不同记录时，新记录应直接显示自己的选中、开关和进度状态。对同一记录的 `notifyItemChanged`、正常用户交互及可见加载动效仍保留原有动画。

本轮采用内部 `ReuseAnimationScope` 与 `ReuseAnimationState`，每个 holder 有独立状态。只有确认绑定身份跨记录时，在该 holder 的同步绑定、构建和布局区间启用局部“跳过状态过渡”状态；不导出为业务公共 API，也不更改系统 reduced-motion 语义。

初稿的全局计数器与 `reducedMotion` 扩展方案不执行，原因有两点：

- `buildScope` 可能同时刷新其他已标脏 holder，全局开关会错误影响别的可见记录。
- `ElProgress` 等组件的 effect 会依据 reduced-motion 停止无限动画。同步区间退出不一定触发重建，可能让可见的不定进度永久停转。

消费者按职责接入局部状态：

- El 样式引擎只让状态 transition 直达目标值，保留持续 keyframe；样式未改变时不制造额外更新。
- `ElProgress` 的 `fillMotion`、`bufferMotion` 在跨记录时直接赋目标值；不定进度的循环时钟仍依据正常可见性与系统动效偏好运行。
- `ElSwitch` 的 `AnimatedAlign` 在跨记录时跳过位移动画；同记录切换保持正常时长。
- 两端轻量 `ElCheckbox`、`ElRadio` 采用 ElView/ElStyle，复用同一机制，之后移除示例 generation Key；事件、分组、语义、禁用和焦点边界沿用已有接口。

L0-8 不只验证目标值同帧可见，还须验证：无关 holder 的动画不受影响、同 ID 内容更新仍有正常过渡、可见不定进度继续转动、隐藏条目重新显示后持续动效能恢复。没有其他合法动画的隔离场景，才断言 `transientCallbackCount == 0`。

### 3.3 池中条目的其他驻留问题（P3）

- **GlobalKey 与 Hero。** 池中 holder 仍挂载并保留旧内容，本轮在 `_host` 加入 `HeroMode(enabled: visible)`，避免隐藏 holder 参加 Hero 收集。它不能解决业务 ID 派生 GlobalKey 重复；业务行继续禁止这类 Key。HeroMode 也不禁止可见的、按记录唯一的 Hero tag，限制的是隐藏旧副本参与收集。
- **主题、字号变化。** 池中子树仍依赖 Theme 和 MediaQuery，环境变化时会与可见条目一起重建。复杂卡片每棵约 195 个 Element，两种类型各 5 个池位，需要时可以用 `setMaxRecycledViews` 下调重类型的池容量。先用 L2 观察主题切换帧再决定。
- **计时器与订阅。** `TickerMode` 管不到 `Timer` 和 Stream。预取可能绑定后从未进入可见区，不能在 bind/initState 启动资源却只依赖 detach 停止；倒计时、轮询等可见工作在 attach 启动、detach 停止，recycle/dispose 再做幂等清理并取消过期异步结果。池中条目仍保留组件状态，资源释放不得破坏再次 attach 的能力。

## 4. 内核剩余的滚动优化

| 编号 | 问题 | 思路 | 优先级 |
| --- | --- | --- | --- |
| S1 | El 动画时钟不受 TickerMode 控制 | 见 3.1 | P0 |
| S2 | 换绑没有跳过过渡 | 见 3.2 | P1 |
| S3 | 一批 `insert`、`remove`、`move` 每次通知都重扫全部类型 | 记录结构变更，延迟到几何读取或布局时合并为一次最终全表扫描；保留 Fenwick 数值重建与任意 `getItemViewType(position)` 契约。单次结构变更仍是 O(n)，同批多次通知避免重复 O(n) | P2 |
| S4 | 重类型超过当前剩余预取预算时不能提前挂载，首次进屏存在同步创建风险 | 先通过 L2 时间线归因；只有确认创建尖峰后，才考虑业务层固定尺寸占位与分阶段填充。不同阶段会改变展示和语义，不给通用列表默认启用 | 条件项 |
| S5 | 预取预算的真实时钟与测试帧假时钟不同源，可能进入保守预算分支 | 提供仅测试可注入的预算时钟，让 L0-12 可确定地验证预算内预取、超预算跳过及后续补齐；生产保持原时钟路径 | P2 |
| S6 | 初次设置适配器时 `_ExtentIndex` 对全部条目调用 `getItemViewType` | 一万条单次 O(n) 可接受，已在聊天首入文档中说明，暂不处理 | — |
| S7 | 回弹越界期间的数据更新可能打断回弹 | 补测试确认，区分原来已越界的回弹与内容变短导致的失效偏移，只修复前者被错误夹紧的分支 | P3 |
| S8 | 隐藏和显示切换时更新 TickerMode、HeroMode、ExcludeFocus 包装 | 停表、排除焦点与隐藏 Hero 是正确性要求；稳定可见性时复用同一包装实例 | — |

S3 不得改成“只查询新增区间”：`getItemViewType(position)` 可以依赖 `position % 3`、当前数量或邻项，稳定 ID 不保证类型稳定。删除、移动即使没有新项也可能改变已有项的类型。批处理期间一旦调用依赖几何的读取，必须先兑现待处理的类型索引，不能向调用者暴露旧映射。

## 5. 组件复用合格性

### 5.1 合格标准

一个组件或一行内容放进 RecyclerView 换绑时，应满足：

| 编号 | 标准 | 不满足时的表现 |
| --- | --- | --- |
| R1 | 结构稳定：换绑不改变内部 Key 和子树类型 | 换绑退化为整棵新建 |
| R2 | 受控值同帧生效 | 先画上一条记录的值，下一帧再纠正，还多一次重建 |
| R3 | 换绑不播放过渡 | 上一条记录的动画串到新行 |
| R4 | 换绑写入不产生业务命令 | 回调误改选择集合等业务状态 |
| R5 | 隐藏时不工作：Ticker、关键帧、计时器、订阅停止 | 页面无法静止，后台持续调度帧 |
| R6 | 不用数据派生 GlobalKey，隐藏 holder 不参加 Hero 收集 | 与仍挂载的池中旧内容重复，断言崩溃 |
| R7 | 组件内部状态（悬停、按压、焦点、滚动位置）不承载业务含义 | 状态跟着 holder 走，串到别的记录 |
| R8 | 单实例成本与其职责相称 | 每次首次创建都很重，池驻留成本高 |

### 5.2 库组件审查

| 组件 | 实施前问题 | 涉及标准 | 本轮处理 | 验证重点 |
| --- | --- | --- | --- | --- |
| `ElCheckbox`、`ElRadio` | 两端 Material 回退成本与换绑过渡不可控 | R2、R3、R8 | 两端轻量品牌实现，接入局部 transition 跳过 | 三态、分组、事件阻止默认、语义、禁用、焦点与同 ID 动画 |
| `ElSwitch`（移动） | 样式与 AnimatedAlign 换绑时过渡旧状态 | R2、R3 | 方案 A 加局部跳过两条过渡路径 | 普通受控切换仍有动画 |
| `ElTag`（移动） | 颜色状态跨记录过渡 | R3 | 接入样式引擎局部 transition 处理 | 同记录过渡不受影响 |
| `ElProgress`（移动） | fill、buffer 控制器跨记录过渡 | R3 | 直接设置换绑目标值，保留不定进度循环 | 可见循环不断，系统 reduced-motion 不变 |
| `ElLoadingIndicator`、`ElSkeleton`（移动） | El 无限关键帧未停表 | R5 | 动画时钟接入 TickerMode | 隐藏不持续请求帧，恢复后继续运行 |
| 带 transition、keyframes 的 `ElView` | 时钟未停表、换绑过渡旧状态 | R3、R5 | 3.1 与 3.2 分别处理可见性和记录身份 | transition 跳过不取消持续 keyframe |
| `ElCollapse` | Material 回退用 Key 重建展开状态 | R1 | 保留为独立组件改进项，不为列表优化扩张展开组件接口 | 后续需要受控展开与完整品牌实现设计 |
| `ElButton` 普通构造 | 不双向绑定仍持有模型 Hook | R8 | 方案 D：先测固定成本，再决定是否拆分 | 保留普通与 toggle 的现有调用方式 |
| `Text`、ElView 文本 | 原地更新 RenderParagraph | 合格 | 保持现有结构复用 | Element 与段落身份保留 |
| `ElCardView` | 容器语义与结构稳定 | 合格 | 数据驱动过渡使用 3.2 | 激活、按压与换绑职责不混淆 |
| 数据驱动的 `Image` | 换图空白与驻留解码资源取决于业务 | R3、R8 | 按场景选择占位、gapless、解码尺寸和资源释放 | 不默认改变图像展示与缓存语义 |

### 5.3 示例审查与实施边界

**万条复选** [selection.dart](../../../../../example/lib/src/pages/examples/recycler_view/selection.dart)

- 结构固定、叶子监听、`modelValue` 同步链路都符合要求。
- 本轮在局部换绑机制与轻量品牌复选框接入后移除 `checkboxGeneration`，跨记录勾选变化也应保留控件子树。
- 阻止冒泡的 `ElView(event: ElEvent(onTap: stopPropagation))` 与记录无关，本轮移到 `model.item` 的 `ValueListenableBuilder` 外层，builder 只保留依赖标题的 `Semantics`。
- 卡片的 `ElEvent` 闭包在每次勾选变化时重建，影响很小，可以提到 `build` 中作为局部变量。
- 整行点击依赖「外部 modelValue 写入也回调」，与 2.4 方案 C 的规范一致；`select` 幂等，`receiving` 守卫保留。

**聊天** [chat.dart](../../../../../example/lib/src/pages/examples/recycler_view/chat.dart)

- 按方向分两种类型，正文和时间是叶子，消息字段延迟计算，合格。
- 每行一个 `LayoutBuilder` 求 80% 最大宽度。它不随换绑重建，只在约束变化时重建，预取路径也已支持，保留即可。

**复杂卡片** [cards.dart](../../../../../example/lib/src/pages/examples/recycler_view/cards.dart)

- 结构复用合格，刷新统计时固定节点零构建已有测试。
- 每张卡片有阴影、照片裁剪和渐变遮罩。无头测试能观察构建、布局和绘制记录成本，但不能代表真机 GPU 光栅化及图片上传成本，必须用 L2 的 raster 与实际呈现指标确认。
- 卡片样式只对 `transform` 声明了过渡，背景和边框随激活状态直接切换，符合 R3。新增颜色过渡前应先落地 3.2。
- 重类型池容量见 3.3。

**纯文本** [text.dart](../../../../../example/lib/src/pages/examples/recycler_view/text.dart)

- 整行就是一个叶子，`useValueListenable` 重建整行是合理的最小粒度，合格。

**文档页** `example/lib/src/widgets/doc_scroll_view.dart`

- 视图类型等于内容模板，绑定只改间距。这是「内容完全不变」的最好情况，用于观察结构复用的上限，不能代表动态数据列表。

### 5.4 复用行编写规则

1. `itemView` 在 `onCreateViewHolder` 中只构建一次；结构差异用 viewType 区分，不随数据更换 Key 或子树类型。
2. 每个会变的字段一个 notifier；`ValueListenableBuilder` 或 `ObsBuilder` 只包最小消费点，不变部分作为 `child` 传入，靠同实例截断更新。
3. 受控组件用 `modelValue` 连接 holder 模型；业务回调幂等，或在绑定期间设守卫。
4. 选中、展开、进度等状态存放在业务数据里，组件内部状态不承载业务含义。
5. 不使用数据派生 GlobalKey；允许可见记录的唯一 Hero tag，由隐藏 holder 的 HeroMode 排除旧副本。
6. 可见工作在 attach 启动、detach 停止；Flutter 与 El Ticker 都遵循 TickerMode，计时器和订阅另行管理，recycle/dispose 做幂等清理。
7. 跨记录换绑只跳过状态 transition，同 ID 的业务更新和可见持续关键帧保持原有语义。

## 6. 实施顺序

| 阶段 | 实际内容 | 当前状态 | 验收 |
| --- | --- | --- | --- |
| 0 | 系统设置入口、跨页面帧记录器、显式窗口统计、复制 JSON | 已实现，定向测试通过；尚无本轮真机采样 | 记录器逻辑与页面测试、L2 |
| 1 | El 时钟懒接入 TickerMode，处理 forceFrames 与重挂生命周期 | 已实现，定向测试通过 | L0-6 |
| 2 | `ElModelValue` 同帧回灌，保护补发重入与原有通知契约 | 已实现，定向测试通过 | L0-7 与相关组件回归 |
| 3 | holder 局部换绑状态、样式 transition、进度与开关专用路径 | 已实现，定向测试通过 | L0-8 与负向隔离测试 |
| 4 | 两端轻量复选/单选，移除 generation Key，外移静态事件包装，隐藏 HeroMode | 已实现，定向测试通过 | L0-1、L0-2、L0-9、L0-10 |
| 5 | 合并结构通知扫描，预算时钟注入，回弹更新边界回归 | 已实现，定向测试通过 | L0-5、L0-12 与回弹回归 |
| 6 | 汇总本轮结构工作量与定向主机测量，用户按矩阵复测真机 | L0 与五轮 L1 已采集，见 REUSE_RESULTS.md；L2 尚无本轮采样 | 对应层级结果报告 |
| 7 | 渐进式重行、池容量、方案 B、方案 D | 条件项；先归因、测量，再按证据决定 | 对应 L1/L2 与行为回归 |

“全部执行”包括落实确定的优化与完成条件项评估，不把未证实有益、会改变业务展示或扩大公共 API 的备选方案默认打开。阶段 1、2 可以独立推进；移除 generation Key 必须等局部换绑机制与品牌复选框同时具备。此表不替代测试结果，最终通过数量与性能数值仅由实际运行日志填写。

本轮最终结果与条件项决策见 [REUSE_RESULTS.md](REUSE_RESULTS.md)，五轮主机计时未达到预定的稳定差异门槛。
