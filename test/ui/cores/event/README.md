# ElEvent 测试合同

本目录验证通用 Press／Transform 识别器、事件传播与手势归属。识别器只依赖 Dart／Flutter，通过官方 PointerRouter、GestureArena 和协作团队处理输入；ElView 直接承载事件，不增加 ElEventView 或额外事件 Render。

生产事件层位于 `lib/src/cores/view/event/`，由四个手写 Dart 文件与模型生成文件组成：`event.dart` 合并声明、配置与业务回调；`press.dart` 包含按压和共用输入／路线；`transform.dart` 处理拖拽、缩放与旋转；`dispatcher.dart` 适配任意 RenderBox 的几何、焦点、键盘、样式反馈与拖拽余量。识别器不引用 ElView、ElStyle 或 ElEventConfig。

`ElEvent`、`ElEventConfig`、`ElDragProxy` 的复制与合并统一由 `ElModelGenerator.copy` 生成到 `event.g.dart`，扩展随公共入口导出。`copyWith` 省略字段时保留原值，可空字段显式传 `null` 时清空；`merge` 按字段合并，对方未声明的可空字段保留本方值，嵌套声明按生成器规则合并。移除回调直接写 `event.copyWith(onTap: null)`，不再提供独立 `clear` 枚举。配置复制、合并与等值读取私有原始声明，不能把 getter 默认值当作显式声明。

公共入口仅从 `event.dart` 导出 11 个业务声明；通用识别器、团队、内部详情、回调类型与分发器均通过 `src` 内部导入。导出声明使用 El 前缀，内部声明不使用 El 前缀，内部接线扩展不对外导出。

通用识别器通过 `callbacks` 按阶段登记强类型回调，例如 `press.callbacks[ElEventPhase.tap] = (details) { ... };`；整表替换可同步清除旧订阅。Press 只接受按压阶段，Transform 只接受拖拽、缩放和旋转阶段。反馈、默认动作和物理释放等生命周期钩子单独保留；组件继续通过 ElEvent 声明事件。

原始输入统一从 `GestureTeam.onPointerEvent` 通知，通过 `currentPointerDetails` 读取共享数据与控制。与识别器共用团队时，实际命中输入从 Down 开始调用 `observePointer`，再向识别器报名；不为观察新增官方竞技场席位。

本目录仅使用默认 `TestWidgetsFlutterBinding`。可选重采样属于应用绑定层，其算法、平台策略及真实组件集成测试位于 `examples/flutter_base/test/binding/` 与 `examples/flutter_base/test/integration/`。

## 权威模型

- PointerDown 冻结 `target -> ancestors` dispatcher 链。
- move/up/cancel/removed 使用同一条链，指针移出再返回不更换 owner。
- 物理席位和输入来源保持原位置；成员销毁可把逻辑所有者移交冻结路线中的存活成员，按压组直接读取路线的所有者。
- 普通 queued/raw/semantic callback 与状态机推进前都检查 pointer membership。
- `eagerGesture()` 先服从官方竞技场归属，确认后同步收缩 membership；loser 先收到合成 PointerCancel，再按已公开状态收到 Tap/Drag/Scale Cancel，之后 raw/semantic 全停。
- Down 中的未决请求在官方关闭报名并完成裁决后提交；已有归属时，eager 事务的 loser terminal 在调用返回前结清。
- `eagerGesture()` 返回 `void`；不存在 callback 外部认领 API。
- 默认 eager 保留 winner 的 TapUp/Tap/Drag；`cancelSelfTap:true` 只取消自身 Tap 激活与连击窗口。
- `stopPropagation()` 按来源阶段锁定后续交互链：PointerDown 截断祖先整个 pointer 序列，TapDown/TapUp 分别截断祖先剩余 Tap 链，Tap 仅截断当前 Tap；DragDown/DragStart 等只建立对应 family route。它不产生 winner，也不清理无关手势状态。
- 祖先先过 Drag 阈值时，后代 `onDragStart` 会先收到同步提案；handler 存在不抢占，只有 stop/eager 改变路由。
- 每个实际执行过的 DragStart 都必须恰好收到一次 DragEnd/DragCancel；配置替换、主动取消、detach、PointerRemoved 与多指换手同样遵守。
- 双指 Scale 成立时保留现有多 pointer 原子接管；单指 Pan 不自动抢祖先 Scroll。

## 必须保持的按钮合同

按钮嵌在祖先拖拽区域时，只在自身 `onDragStart` 调用 `stopPropagation()`：

```text
child: tapDown -> dragStart -> tapUp -> tap
ancestor Drag: start/update/end/cancel 全零
```

按钮默认使用元素边界而不是移动距离：盒内任意距离移动仍可点击；exit 触发 cancel，re-enter 重新 TapDown，up inside 恢复 Tap。

`onTapUp` 是仍持有 pointer 的按压释放通知，不代表 Tap 成功。距离取消、LongPress 或独占 Drag 可以取消最终 Tap，但 winner 的 TapUp 仍应执行。

释放资格回调可以同步取消成员或拒绝点击；返回后不得重新登记该成员的连击、延期 Tap，也不得让祖先继承已取消成员的延期策略。延期计时器由各成员独立持有，取消或销毁一个成员仍保留其他存活成员的通知。

## 测试分层

Primitive 测试分两层：独立识别器直接参加官方竞技场；事件适配使用裸 RenderBox + `EventDispatcher`，通过 `support/dispatcher_test_host.dart` 完成整条命中路径登记后再推进 PointerRouter／Arena。不得将逐宿主 handleEvent 调用冒充完整物理输入。

只有以下 wiring 测试使用真实组件：

- ButtonView / ElWindows caption button；
- Scroll / Refresh / Nested / Scrollbar；
- Selection / Overlay / DnD / Zoom / Preview；
- Tab / Table / Editable / Windows move-resize；
- ElView 的命中、光标、混合宿主坐标与生命周期接线。

上层测试只证明“组件在正确时机调用 primitive”，不得复制 primitive 的 ancestor/descendant/terminal 全矩阵。

## Canonical 文件职责

| 文件 | 唯一职责 |
|---|---|
| `event_propagation_contract_test.dart` | raw/semantic route、stop、坐标、canonical 去重 |
| `pointer_ownership_contract_test.dart` | eager、membership、loser terminal、release、queued recheck |
| `tap_gesture_contract_test.dart` | bounds、TapUp、tap/double/triple/defer/LongPress/侧键 |
| `drag_gesture_contract_test.dart` | passive/stop/eager、free/axis、fling、lock、velocity |
| `drag_proposal_lifecycle_contract_test.dart` | DragStart 提案、跨指针迁移、配置/挂载终态与 exactly-once |
| `drag_interaction_test.dart` | 普通输入下 Tap/Drag 交互、replacement、多指策略、终态、速度与位移守恒 |
| `drag_proxy_test.dart` | pre/driver/overflow、roster、terminal |
| `scale_gesture_contract_test.dart` | 原子 Scale、upgrade、rotation、route、terminal |
| `event_lifecycle_contract_test.dart` | detach/disable/replacement/reentrancy/removed |
| `event_public_contract_test.dart` | public surface、config、equality、metadata、default |
| `event_view_test.dart` | 轻量 Render 宿主、混合冒泡、命中行为、禁用与光标 |
| `support/dispatcher_test_host.dart` | 唯一 primitive 裸 RenderBox 宿主 |

迁移期间旧文件只允许短暂存在；`TEST_MANIFEST.md` 必须记录每一项的目标与状态。最终删除 `event_test.dart`，不得留下新旧两套合同。

## 合同 ID

- `ROUTE-*`：传播、stop 与 family route。
- `OWN-*`：pointer winner、membership 与 loser terminal。
- `TAP-*`：Tap、TapUp、边界、连击、defer 与 LongPress。
- `DRAG-*`：Drag 识别、stop/eager、fling、lock 与 velocity。
- `SCALE-*`：多指原子接管、upgrade、rotation 与 terminal。
- `LIFE-*`：detach/disable/replacement/reentrancy/removed。
- `SCROLL-*`、`SEL-*`、`OVERLAY-*`、`WINDOW-*`：真实组件接线。

每个测试必须同时断言应发生和不得发生，避免实现以另一种错误原因变绿。

## 去重规则

只有同时满足以下条件才能删除旧测试：

1. 前置条件一致；
2. pointer 输入序列一致或新用例更强；
3. 所有正向断言被覆盖；
4. 所有负向断言被覆盖；
5. replacement、平台、pointer kind、嵌套深度等关键维度没有丢失。

测试标题相似不等于重复。移动/合并测试与改变行为预期必须分成不同提交。

## 执行规则

按修改范围运行定向文件，不主动运行全仓测试：

```powershell
$eventTest = Join-Path 'test/cores' 'event/<changed-file>.dart'
flutter test --no-pub --concurrency=1 $eventTest -r compact
```

事件内核修改完成后运行 canonical event 文件集合；消费者只运行对应模块。性能测试只能写在根 `benchmark` 包。

最终收尾时执行：

```powershell
flutter analyze --no-pub
```

只处理本计划引入的问题；其他会话造成的编译错误按仓库重试规则处理。
