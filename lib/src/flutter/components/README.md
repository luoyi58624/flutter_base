# Components

本目录是桌面端、移动端共用的组件接口层：只声明组件的语义参数与值模型，外观与结构由各品牌登记的 Builder 实现。本文是组件接口的设计规范，新增或修改组件前先对照本文；与源码不一致的地方见末尾「迁移清单」。

## 分层

| 层 | 位置 | 职责 |
| --- | --- | --- |
| 基元 | `flutter/views`、`flutter/widgets`、`flutter/utils` | ElView、ElButtonView、ElCardView、ElModelValue、ElFormModelValue、弹层、焦点、事件 |
| 组件接口 | `flutter/components` | 公共声明 `ElXxx`：语义参数 + 值模型，通过 ElComponentProvider 分派到 Builder |
| 品牌实现 | `ui/desktop`、`ui/mobile` | 用基元搭结构、用 ElStyle 定外观，登记为默认 Builder |

ElView 相当于 Web 的 div，负责盒模型、文本、样式、事件与语义；多子布局直接用 Flutter 的 Row / Column / Stack / Wrap 等官方 Widget。组件接口和品牌实现都不自造同职责的协议。

## 准入

按组件的交互形态决定位置，而不是按当前哪一端写了实现：

- 默认进入本目录。按钮组、列表行、标签输入、提及等两端都可能用到的组件都是通用组件，外观差异由品牌各自实现。
- 只有交互形态本身只存在于一端的组件才放在对应品牌目录，由 desktop.dart / mobile.dart 导出，不进入 ElComponents。例如桌面端的菜单栏（MenuBar），移动端的底部导航栏。
- 两端外观相同、无需品牌分派的组件（如纯文本、字体图标）做成基元层的普通 Widget，不登记 Builder。
- 判断标准是组件是否适合出现在某一端，不以当前是否已有实现为依据。

公共组件暂时缺少某一端实现时，必须登记在该品牌完整性测试的已知缺口清单中，清单只减不增。

## 注入与覆写

带 `style` 的 `ElComponents` 是完整预设，同时安装组件实现和样式。省略 `style` 时，组件实现按项继承，`themeMode` 可以独立声明。变量通过 `ElStyle.vars` 声明，状态差量写入对应变体的 `vars`。

```dart
ElComponentProvider(
  components: ElComponents(button: (context, widget, model) => MyButton(widget)),
  child: page,
);
```

- 解析顺序：最近的 Provider → 外层 Provider → 品牌主题在根部安装的完整默认表。
- 用户只注入想替换的那一项，可作用于任意子树，其余组件不受影响。
- 品牌默认表的完整性由测试保证：遍历默认表，除已知缺口外不允许出现 null。
- 组件读取到 null 时抛出带组件名的错误，例如「ElSwitch 未登记实现」。
- Builder 以顶层函数或静态方法登记；不要在 build 中创建闭包，否则每次重建都会通知全部组件。

## 声明结构

| 组件类型 | 基类 | Builder 签名 |
| --- | --- | --- |
| 无值组件 | StatelessWidget | `Widget Function(BuildContext context, ElButton widget)` |
| 双向绑定组件 | ElModelValue\<D\> | `Widget Function(BuildContext context, ElSwitch widget, Obs<bool> model)` |
| 可接入表单的双向绑定组件 | ElFormModelValue\<D\> | 同上 |

- 双向绑定一律由 ElModelValue 持有，模型以 `Obs<D>` 交给 Builder，品牌直接读写，不另建绑定。
- 声明只保存参数，不暴露可写状态，不在声明层包裹事件、语义或布局；交互由品牌用 ElButtonView 等基元实现，两端一致性由基元保证。
- 跨组件协调属于模型逻辑，留在接口层，例如 Radio / Checkbox 的 Group。
- 业务值使用泛型，不限制为 String；多选使用完整 List 模型。

## 参数规范

参数在精不在多，每个参数都要两端生效、含义相同；不为单端或单一品牌的特性增设参数。

**外观只用 style**

- 每个组件只有一个 `style: ElStyle?`，在品牌默认样式之后合并。
- 不声明颜色、尺寸、间距、圆角、阴影、形状字段；圆角、通栏宽度等由 style 表达，悬停、按压、焦点、禁用、暗色等变化交给 ElStyle 的状态变体。
- 子部位样式默认不开放；两端都存在且确有调整需求的部位，才增加一个 `xxxStyle`。

**语义参数**

- 语义色统一为 `type: ElThemeType?`，只用于语义色有意义的组件。
- 形态枚举只保留两端能一一对应的取值；一端专属的形态放进品牌扩展组件。

**通用参数表**

| 类别 | 参数 | 规则 |
| --- | --- | --- |
| 值 | `value`、`modelValue`、`onChanged` | 由 ElModelValue 提供，`value` 与 `modelValue` 互斥 |
| 动作 | `onPressed` 等 | 回调为空不等于禁用 |
| 状态 | `disabled`、`loading` | 仅在有意义的组件上声明；loading 不等于禁用 |
| 内容 | `child` 及具名插槽 | `Object?`，交给 ElView 内容桥接：String、IconData、Widget、行内 Iterable |
| 外观 | `style` | 见上 |
| 事件 | `event` | 可交互组件必备，品牌合并到交互根节点；与默认动作组合执行，preventDefault 可阻止默认动作 |
| 无障碍 | `semanticLabel` | `String?`；默认文案由品牌按 locale 提供，接口层不写死文字 |
| 焦点 | `focusNode` | 仅可聚焦组件，节点由调用方持有并释放 |

**类型与占位**

- `Object?` 只用于交给 ElView 渲染的内容插槽，其他参数使用具体类型。
- 需要区分「未传入」与显式 null 时统一用 `$absent`，不借用空 Widget 或其他哨兵。
- 平台输入法回调等一端专属的细节留在编辑内核，不进入公共参数。

## 变体

- 命名构造形态（如 `.toggle`）由维护者指定，迁移时保留，不得擅自拆成独立组件；切换形态由声明上的标志（如 `isToggle`）告诉品牌。
- 同一概念只保留一套值模型，不并存按值与按索引两种绑定。

## 文档

- 公共 API 用中文 `///`，一句话说明用途；关键决策说明原因，不写实现细节。
- 每个组件目录的 README 只记录用法与参数边界，不重复本文的通用规则。

## 新增组件检查清单

1. 按「准入」确认组件应放在本目录、品牌目录还是基元层。
2. 选择基类与 Builder 签名，参数逐项对照「参数规范」。
3. 在 ElComponents 增加字段并运行 `dart run build_runner build`。
4. 两端品牌登记默认实现；暂缺的一端写入完整性测试的已知缺口清单。
5. 补组件 README 与局部测试。

## 迁移清单

当前源码尚未完全符合本规范，按以下归类逐步迁移：

| 归类 | 组件 | 状态 |
| --- | --- | --- |
| 保留并按本规范重写 | Button（含 .toggle）、Switch | 已完成 |
| 保留并按本规范重写 | Steps、Avatar、Calendar、Collapse、Empty、Segmented、Tabs / TabBar、Alert、Tag、ButtonGroup、Checkbox / Group、Radio / Group、Input、InputNumber、InputOtp、InputTag、Select、Autocomplete、Mention、ListTile / ListGroup、Card、LoadingIndicator、Progress、Skeleton、Slider | 待迁移 |
| 直接使用 Flutter Text | Text | 已完成 |
| 改为基元层普通组件 | Icon | 已完成 |

机制调整：

- ElComponentProvider 与祖先自动合并，缺实现时抛出带组件名的错误：已完成。
- 两端品牌默认表完整性测试见 `test/ui/brand_completeness_test.dart`：已完成，已知缺口清单随迁移缩减。
- 双向绑定组件在 `obsBuilder` 中把 `$obs` 作为模型参数传给 Builder；ElModelValue 本身不改签名。待迁移组件声明上的 `currentValue` setter 随迁移删除。
