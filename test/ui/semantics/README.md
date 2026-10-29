# 语义行为测试

所有无障碍语义测试统一放在本目录，按组件命名为 `xxx_test.dart`。不要把 CSS 值解析等非无障碍含义的“semantics”测试混入这里。

| 文件 | 负责内容 |
| --- | --- |
| `common.dart` | 最终提交包录制、增量树重放、孤儿／重复父节点／循环检查、遍历与命中矩阵、Windows 遍历序命中、容器留白捕获、DPI 换算、几何断言、热重载、UTF-16 完整性 |
| `view_test.dart` | 角色和状态、属性与动作、合并／排除／排序、焦点同步、样式变换、尺寸变化、卸载与 GlobalKey 重挂 |
| `card_test.dart` | 无样式区域容器、留白命中、外边距排除与动态更新、独立子节点和动作、默认焦点中性、嵌套区域、尺寸变换、滚动裁剪、浮层层序、名称更新与语义启停 |
| `scroll_test.dart` | 静态／虚拟列表、横向／纵向／双轴／反向、嵌套正文、固定／流内导航菜单与正文独立滚动、部分裁剪、往返滚动、可见项坐标与命中、动作和边界、候选缓存、视口变化、语义启停与热重载 |
| `overlay_test.dart` | 自动面板容器、模态／选区窗口、子控件动作、owner 与同层置顶、投影开关与回退、移动／缩放／裁剪逃逸、宿主重挂、层序命中、导航覆盖整屏滚动正文、菜单定位壳穿透、同步焦点刷新、不透明遮挡、隐藏恢复、Portal 开关／锚卸载、语义启停与热重载 |
| `editable_test.dart` | 文本与选区、焦点和输入连接、真实编辑动作、密码、隐藏正文、失效动作、语义窗口边界 |
| `semantics_test.dart` | `ElSemantics` 配置等值合同 |

## 三层检查

`ElCardView` 是无默认样式的区域基元，直接继承 `ElView`，通过 `semanticLabel` 可选命名；自动建立容器并保留子节点，事件与焦点由调用方显式声明。测试不再手动补容器配置，也不能用合并后代凑出区域尺寸。

1. **语义行为**：断言角色、名称、状态、可执行动作；调用 `SemanticsOwner.performAction` 后检查真实业务结果和更新后的语义，不能只检查回调非空。
2. **引擎输入**：Widget 测试入口创建 `ElSemanticsTestBinding`，每个用例清空记录。公共绑定在每一批提交时检查树关系；几何用 `expectGeometry` 与独立绘制矩形对照。`hitTestSemantics` 使用命中树及 `hitTestTransform`；`hitTestWindowsSemantics` 使用遍历树及 `transform`，模拟当前 Windows MSAA 的先到先得规则。两者都不借用 RenderObject 命中结果，也不模拟全部平台行为。
3. **Windows 原生接口**：`examples/benchmark/lib/semantics_scroll_debug.dart` 配合 `tool/semantics_windows.ps1` 检查滚动行；`lib/semantics_header_debug.dart` 配合 `tool/semantics_header_windows.ps1` 检查真实 element_docs 首页导航。两组均读取 MSAA 的实际元素矩形和 `accHitTest`，独立进程运行，不操作用户正在调试的应用。Widget 测试通过不能代替这一层。

Windows 重叠场景必须同时调用两种命中检查：当前 SDK 的 `HitTestSync` 遍历 AXTree 的 `children()`，没有采用 Flutter 提交的 `childrenInHitTestOrder`。只验证命中顺序会漏掉“节点和矩形都正确，原生先命中底层整屏容器”的错误。源码和真实复现见 `examples/benchmark/reports/2026-09-13-semantics-header.md`。

## 新组件的最低覆盖

- 冷启动 → 属性更新 → 隐藏／卸载 → 恢复，检查名称、状态、动作、唯一性和旧节点消失。
- 对可移动组件检查平移、缩放、滚动与裁剪；至少使用 DPR 1 和 1.75，预期值来自实际绘制结果或明确的几何合同。
- 对有焦点的组件检查获取、转移、禁用、关闭及卸载；焦点状态和语义动作资格必须一起变化。
- 动态场景包含语义从关闭到开启，以及开启期间的重建／热重载；关闭句柄使用 `try/finally`，测试结束前释放。
- 检查每次操作后的提交，而非只看循环结束；往返操作应恢复等价的可见语义内容。不要固定分配出的节点 ID，也不要通过扩大误差或排除孤儿节点掩盖失败。
- 重叠布局应包含整屏正文上方的导航、小面板外的穿透、异步内容填入／清空／恢复、层序改变和关闭当帧；隐藏持焦面板时，在下一次 `pump` 前检查同步提交，防止焦点刷新先送出旧边界。
- 浮层测试的内容根不手写 `ElSemantics(container: true)`，验证底层自动容器。使用 `expectContainerHit` 检查留白处命中和独立绘制尺寸，同时执行子控件语义动作，避免靠合并全部按钮“凑出”一个容器。分别覆盖显式局部 `ElSelectionView` 和模态遮罩。
- 层级预期必须写明应命中的窗口，覆盖父级路径优先于子层数值、同层激活、负层级、隐藏／恢复和父层关闭；不能只检查存在 zIndex 字段或节点列表顺序变化。
- 几何断言必须确认至少检查到一个目标；列表测试要确认多个可见行，禁止空集合“全通过”。

## 运行

在 `packages/el_ui` 下执行整个语义模块，或仅执行改动对应的组件文件：

```powershell
flutter test --no-pub test/semantics
flutter test --no-pub test/semantics/scroll_test.dart
```

Windows 原生验证在 `examples/benchmark` 下执行：

```powershell
flutter build windows --debug --no-pub --target lib/semantics_scroll_debug.dart
pwsh -File tool/semantics_windows.ps1

flutter build windows --debug --no-pub --target lib/semantics_header_debug.dart
pwsh -File tool/semantics_header_windows.ps1
```

原生结果分别保存在该包 `.dart_tool/semantics_scroll_native/` 和 `.dart_tool/semantics_header_native/`，报告不提交用户控制台全文。导航探针在滚动和重组前后检查同一组 9 个控件，随后打开外观／语言菜单以及两个重叠菜单，动态调整 zIndex。无名称容器也必须采集；从原生 `accHitTest` 返回对象沿父链检查真实面板尺寸，不能把整屏遮罩或正文同名按钮误当面板。两个菜单的重叠点必须命中当前前景窗口；无实际重叠则探针报错，防止空验证。原生矩形允许最多 2 个物理像素的整数取整误差；Widget 几何仅允许 0.01 像素的矩阵计算误差。
