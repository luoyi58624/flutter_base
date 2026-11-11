# ElEvent 测试迁移清单

以下是自研按压与变换识别器时期的迁移记录。当前测试约定见 [ElEvent 测试](README.md)。

## 2026-10-27 阶段 D：解除内部测试对重采样的依赖

- `el_ui` 核心测试统一使用默认测试绑定，移除对 `flutter_base` 的 dev 依赖。
- 全局输入测试绑定迁至 `examples/flutter_base/test/support/global_input_test_binding.dart`；原实现不变。
- `drag_interaction_test.dart` 保留普通交互合同；原文件前 8 项迁至 `examples/flutter_base/test/integration/resampling_integration_test.dart`，名称、输入和断言不变。
- 原 `drag_resampling_policy_test.dart` 与 `global_resampling_test.dart` 全文迁至应用层 integration 目录，仅调整支撑导入；前者更名为 `resampling_policy_test.dart`。
- 混合测试删除 CFG-6、全局采样代理分账、采样下 thumb 重挂、采样位移时间戳、REALDEV-1/2 与全局采样下触控板排除矩阵；普通参数矩阵仅保留 false 分支，不放宽断言。

| 原用例名（原样保留） | 目标文件 |
|---|---|
| `adaptive trailing clamps at the 20ms ceiling on slow touch cadence` | `examples/flutter_base/test/integration/resampling_integration_test.dart` |
| `adaptive trailing never goes shallower than the configured offset floor` | `examples/flutter_base/test/integration/resampling_integration_test.dart` |
| `adaptive cadence estimate ignores sub-min-delta batching noise` | `examples/flutter_base/test/integration/resampling_integration_test.dart` |
| `adaptive keeps a configured floor deeper than the 20ms ceiling pinned at the floor` | `examples/flutter_base/test/integration/resampling_integration_test.dart` |
| `short batched flick keeps its end position and velocity through global input sampling` | `examples/flutter_base/test/integration/resampling_integration_test.dart` |
| `pointer cancel drops the queued global input tail and ends ElView exactly once` | `examples/flutter_base/test/integration/resampling_integration_test.dart` |
| `global input sampling idles while held and resumes on a later real move` | `examples/flutter_base/test/integration/resampling_integration_test.dart` |
| `drag resampling reads refresh rate from owner render view` | `examples/flutter_base/test/integration/resampling_integration_test.dart` |

## 2026-10-26 通用识别器迁移

- 生产实现归入 `lib/src/cores/view/event/`，测试目录保持原位；公共入口仅导出 `event.dart` 的 11 个业务声明。
- 生产入口收敛为 `event.dart`、`press.dart`、`transform.dart`、`dispatcher.dart`；业务声明与配置不再分文件。
- 保留原 521 项基线行为，新增独立识别器合同；历史表中的测试规模仅表示当时快照。
- 裸 Render 宿主先登记实际命中路径，再推进官方 PointerRouter/Arena；额外触点 Down 后等待官方默认裁决微任务，不改变坐标、时间戳或正反断言。
- `ElEventConfig.dragResampling` 与逐节点输出采样已删除。原 CFG-6、采样策略和位移守恒迁到全局输入绑定合同；`examples/flutter_base/test/integration/global_resampling_test.dart` 验证 Flutter 原生手势和 ElView 接收同一批样本，SDK 算法由 `examples/flutter_base/test/binding/resampling_test.dart` 验证。
- 删除旧 Scale 调试注入入口，合同改用真实 PointerDown/Move/Up；旧原始事件身份断言继续保留。
- 行数目标用于生产实现，不通过缩减测试、删除负向断言或转移实现到配置声明文件验收。

下文保留历史去重映射，不再限制新通用识别器的 Flutter 类型名称或新增合同数量。

> 历史迁移基线：`b6984d2a4`（2026-08-24）。
> 统计口径：`packages/el_ui/test/cores` 下 `event/**/*_test.dart` 中以 `test(` 或 `testWidgets(` 开始的测试声明。
> 本批开始：27 个测试文件、394 个测试、15,097 物理行。
> 当时规模：27 个测试文件、432 个测试声明、15,025 物理行；新增的 `prevent_default_contract_test.dart` 作为 `preventDefault` 专用可执行合同，不与手势识别测试混排。

本文件只登记测试迁移，不改变任何行为预期。迁移时必须同时保留原测试的前置条件、pointer 输入序列、正向断言和负向断言；只有更强 canonical 测试完整覆盖后，旧副本才能在同一批次删除。

## 状态说明

- `KEEP`：已经位于目标 canonical 文件，继续作为唯一合同。
- `MOVE`：合同基本独立，迁入目标文件后删除旧文件或旧测试。
- `MERGE`：与其他测试覆盖同一机制，先逐项对账，再合并为最强合同。
- `SPLIT`：当前文件或 group 混合多个职责，必须拆往多个目标。
- `DELETE-GATED`：仅表示最终应删除；所有映射转绿前禁止删除。

组合状态如 `SPLIT+MERGE` 表示先按职责拆分，再在各目标中去重。表中的测试数是当前快照，不是迁移后的目标数量。

## Canonical 批次顺序

| 批次 | 目标文件 | 范围 | 完成门槛 |
|---|---|---|---|
| B1 | `event_propagation_contract_test.dart` | raw/semantic route、stop、坐标、canonical 去重、hover/signal/key/focus route | 源测试与目标测试同跑转绿；旧副本同批删除；保留 ROUTE-4/TAP-8 |
| B2 | `pointer_ownership_contract_test.dart` | eager、membership、loser terminal、release、queued recheck | ancestor/descendant、pending/active、detach/terminal 矩阵覆盖完整 |
| B3 | `tap_gesture_contract_test.dart` | bounds、TapUp、tap/double/triple/defer、LongPress、侧键 | TAP/LONG/side-button 合同唯一化；组件滚动接线移出 primitive 文件 |
| B4 | `drag_gesture_contract_test.dart` | passive/stop/eager、free/axis、fling、pointer lock、velocity | DRAG 合同去重且不混入 resampler/replacement 生命周期 |
| B5 | `examples/flutter_base/test/integration/` | 应用绑定的采样策略、位移守恒与平台门禁 | 阶段 D 已迁出；普通交互留在 `drag_interaction_test.dart` |
| B6 | `drag_proxy_contract_test.dart` | pre/driver/overflow、roster、delta、terminal | `consumeDelta` 与 pipeline 矩阵统一，删除旧 `drag_proxy_test.dart` |
| B7 | `scale_gesture_contract_test.dart` | 双指原子接管、upgrade、rotation、rebaseline、route、terminal | 两个 Scale 文件及散落生命周期测试去重 |
| B8 | `event_lifecycle_contract_test.dart` | attach/detach/disable/dispose、replacement、reentrancy、removed | 所有配置代际与 terminal exactly-once 合同集中 |
| B9 | `event_public_contract_test.dart` / `prevent_default_contract_test.dart` | public surface、config、equality、metadata、default、callback 数据 | 公开面与 metadata 文件合并；`preventDefault` 的作用域、阶段隔离与内建动作单独成组 |
| B10 | 消费者对应测试目录 | ElView/Button/Scroll/Selection/Overlay 等真实 wiring | primitive 不再挂真实组件；`event_test.dart` 清空并删除；总测试 LOC 下降 |

每批按“登记逐测试映射 → 移动/合并 → 同跑源与目标 → 删除旧副本 → 再跑目标”的顺序执行，不允许先复制后长期并存。

## 历史迁移文件清单

| 当前文件 | 测试数 | 当前职责 | 目标 canonical 文件 | 状态 / 批次 |
|---|---:|---|---|---|
| `config_inheritance_test.dart` | 7 | 全局/局部配置回落、替换失效、resampling 配置策略 | `event_public_contract_test.dart`；CFG-6 的运行门禁与 B5 对账 | `MOVE+MERGE` / B9（CFG-6 交 B5） |
| `drag_pointer_lock_test.dart` | 3 | mouse accepted Drag 上锁、touch 不上锁、cancel/dispose 解锁 | `drag_gesture_contract_test.dart` | `MOVE+MERGE` / B4 |
| `drag_proposal_lifecycle_contract_test.dart` | 16 | proposal exactly-once、跨 sibling 多指换手、replacement/detach/Removed、Scale 重入 | `event_lifecycle_contract_test.dart` 与 `drag_gesture_contract_test.dart` 最终对账 | `KEEP` / B4、B8 canonical boundary |
| `drag_proxy_test.dart` | 24 | roster、pre/main/overflow、delta 守恒、hot swap、cutoff、terminal | `drag_proxy_contract_test.dart` | `MOVE+MERGE` / B6 |
| `drag_replacement_tap_test.dart` | 12 | pending/active Tap/Drag 的 event replacement 与 terminal | `event_lifecycle_contract_test.dart`；纯 Drag 接受条件与 B4 对账 | `SPLIT+MERGE` / B8（少量交 B4） |
| `drag_resampling_policy_test.dart` | 3 | Android 默认策略、采样 offset builder、非法刷新率 | `drag_resampling_contract_test.dart` | `MERGE` / B5 |
| `drag_interaction_test.dart` | 历史 62 | 普通输入下 passive/eager Tap、replacement、多指策略、LongPress/cancelAllPending | 普通交互继续与 B3/B4/B8 对账；采样合同已迁至应用 integration | 阶段 D 已分离采样；B3/B4/B8 保留 |
| `drag_velocity_test.dart` | 4 | up 跳点、average-boundary 合帧/刷新率/fallback 速度 | `drag_gesture_contract_test.dart` | `MERGE` / B4 |
| `eager_raw_phase_test.dart` | 8 | eager 淘汰、winner 离场、LongPress loser、pointerDown stop、ancestor drag snapshot | `pointer_ownership_contract_test.dart` 与 `event_propagation_contract_test.dart` | `SPLIT+MERGE` / B2、B1 |
| `event_callback_order_contract_test.dart` | 2 | raw、Tap cancel、Drag、PointerCancel 的可观察顺序 | `event_propagation_contract_test.dart`；terminal 代际与 B8 对账 | `MERGE` / B1 |
| `event_callback_test.dart` | 3 | `consumeDelta` 钳制、反向消费、本地余量换算 | `drag_proxy_contract_test.dart` | `MERGE` / B6 |
| `event_dispatch_reentrancy_test.dart` | 17 | handler 内 replacement/removal 的队列、代际与不重定向合同 | `event_lifecycle_contract_test.dart` | `MOVE+MERGE` / B8 |
| `event_dispatcher_public_api_test.dart` | 1 | 从 src 验证内部宿主 `EventDispatcher` 可独立使用 | `event_public_contract_test.dart` | `MERGE` / B9 |
| `event_feature_contract_test.dart` | 15 | passive/eager Drag、loser terminal、TapUp、queue recheck、LongPress、bounds、连击窗口 | `pointer_ownership_contract_test.dart`、`tap_gesture_contract_test.dart`、`drag_gesture_contract_test.dart` | `DONE+DELETED` / B2、B3、B4 |
| `event_metadata_test.dart` | 35 | originalEvent/buttons/localDelta/pointerCount/config interval，同时混有 removal/replacement terminal | `event_public_contract_test.dart` 与 `event_lifecycle_contract_test.dart`；route 坐标交 B1 | `SPLIT+MERGE` / B9、B8、B1 |
| `event_propagation_contract_test.dart` | 1 | ROUTE-4/TAP-8：button DragStart.stop、ancestor Drag 全零、self Tap 完整 | `event_propagation_contract_test.dart` | `KEEP` / B1 canonical anchor |
| `event_public_surface_contract_test.dart` | 4 | phase/reason/三态 copyWith（省略=保留，null=清空，传值=替换）/callback/config 默认公开面 | `event_public_contract_test.dart` | `MOVE+MERGE` / B9 |
| `event_side_button_cancel_test.dart` | 1 | 侧键 cancel 后不误触发 forwardTap | `tap_gesture_contract_test.dart` | `MERGE` / B3 |
| `event_test.dart` | 171 | 历史总集：公开面、Tap/Drag/Scale/raw/focus/bubble/lifecycle/真实 ElView wiring 全混合 | 九个 canonical 文件及消费者目录，详见下一节 | `SPLIT+MERGE+DELETE-GATED` / B1–B10 |
| `recognizer_metadata_test.dart` | 3 | side-button/Scale/takeover cancel 的 originalEvent | `event_public_contract_test.dart`、`scale_gesture_contract_test.dart` | `DONE+DELETED` / B7、B9 |
| `scale_atomic_upgrade_test.dart` | 8 | allowScaleUpgrade、多 pointer 零提交、winner removal、shadow/cutoff、pointerCount | `scale_gesture_contract_test.dart` | `MERGE` / B7 |
| `scale_two_finger_test.dart` | 12 | scale/rotation/rebaseline/velocity/log-scale、双指独占与单指放行 | `scale_gesture_contract_test.dart` | `MERGE` / B7 |
| `tap_bounds_cancel_test.dart` | 17 | bounds exit/re-enter、距离取消、TapUp、宿主漂移；混有 Scroll/真实 ElView wiring | primitive 进 `tap_gesture_contract_test.dart`；Scroll/ElView wiring 进对应消费者测试 | `SPLIT+MERGE` / B3、B10 |

辅助文件 `support/dispatcher_test_host.dart` 不计入 22 个 `*_test.dart`；它保持为唯一 primitive 裸 RenderBox 宿主，迁移期间不得复制第二套宿主。

## 2026-08-25 完成的逐测试对账

| 旧合同 | 最终 canonical | 去重或保留依据 |
|---|---|---|
| `TAP-C1` | `TAP-B6`（`tap_bounds_cancel_test.dart`） | 已更强覆盖距离取消、移回不复活、`TapUp` 保留与单次 `Cancel`。 |
| `ARENA-D1` | `DRAG-1` | 增强既有嵌套 passive Drag 合同，完整断言 `TapDown → Drag → TapUp → Tap`。 |
| `ARENA-D2` + `ARENA-D5` | `OWN-1` | 同一最强合同覆盖 child eager、ancestor active `Cancel`、raw/LongPress/Drag loser 全停与 winner Tap 保留。 |
| `ARENA-D3` | `OWN-2` | 保留 ancestor winner / descendant active Tap loser 的反向层级。 |
| `ARENA-D4` | `OWN-3` | 保留三层 active Tap exactly-once terminal 与 `cancelSelfTap` winner 的 `TapUp`/Drag 终态。 |
| `ARENA-E1` | `OWN-4` | 保留 PointerDown 阶段认领后 winner raw/Drag/`TapUp` 全链与 loser 全零。 |
| `ARENA-Q1` | `OWN-5` | 保留同一 dispatch 已入队 callback 的 membership 重查。 |
| `ARENA-L1` | `LONG-2` | 增强既有真实组件合同，补齐 self `Cancel`、DragUpdate/End 与 ancestor 全零。 |
| `ARENA-F1` | `DRAG-2` | 保留 PointerUp 轻扫救援、无迟到 `Cancel`、`TapUp` 与 Drag terminal。 |
| `ARENA-F2` | `OWN-6` | 保留 ancestor 在 PointerUp 认领并结清 descendant active Tap。 |
| `ARENA-B1` | `TAP-B17`（`tap_bounds_cancel_test.dart`） | 已更强覆盖越界先取消、后续 eager 不重复取消及释放仍有 `TapUp`。 |
| `ARENA-B2` | `TAP-7A` | 保留出界、回入复燃、Drag 认领后二次取消的新 activation。 |
| `ARENA-W1` + `ARENA-W2` | `TAP-7B` | 合为 double/triple 两行参数矩阵，验证 Drag 取消后连击窗口从 count=1 重启。 |
| side-button metadata | `PUBLIC-META-2` | 直接按对象 identity 验证 down/up/Tap 的 raw `originalEvent`。 |
| Scale metadata | `SCALE-META-1` | 四个 Scale/Rotation phase 统一验证 Flutter `ScaleDetails` identity。 |
| Scale takeover metadata | `SCALE-META-2` | 同时锁定 DragStart、DragCancel 与 ScaleStart 的来源事件。 |

旧 `ARENA-*` 只是迁移来源标签，不再存在于可执行测试名；当前实现术语统一为 pointer ownership、route 与 gesture phase。Flutter 测试宿主确实调用 `GestureBinding.gestureArena` 或确实使用官方 `*GestureRecognizer` 时，保留这些 Flutter 名称。

## `event_test.dart` group 映射

以下 27 个 group 覆盖全部 171 个测试。`目标合同` 是迁移后的职责，不表示可以按 group 整块盲移；混合 group 必须继续细分到单测试，确认所有负向断言被覆盖。

| 顺序 | 当前 group | 测试数 | 目标合同 | 目标文件 | 状态 / 批次 |
|---:|---|---:|---|---|---|
| 1 | `EventDispatcher basics` | 5 | registry/dispose/detach/active release；event 引用与 hit-test shape | `event_lifecycle_contract_test.dart`；hit-test shape 进 `event_public_contract_test.dart` | `SPLIT+MERGE` / B8、B9 |
| 2 | `ElEvent flags` | 5 | public shape、`hasAnyCallback`/`hasTapLikeCallback`、copy/merge/equality/clear | `event_public_contract_test.dart` | `MERGE` / B9 |
| 3 | `ElView wires event to render dispatcher` | 7 | dispatcher 惰性分配、rebuild 移除、state/focus-only、unmount dispose | `event_lifecycle_contract_test.dart`；保留最小 ElView wiring 后归 B10 | `MERGE` / B8、B10 |
| 4 | `Tap (primary)` | 3 | TapDown→TapUp→Tap；localPosition/祖先 offset | `tap_gesture_contract_test.dart`；坐标断言进 `event_propagation_contract_test.dart` | `SPLIT+MERGE` / B3、B1 |
| 5 | `DoubleTap` | 3 | DoubleTapDown 时机、快速/超时窗口 | `tap_gesture_contract_test.dart` | `MERGE` / B3 |
| 6 | `TripleTap` | 3 | TripleTap/TripleTapDown/超时窗口 | `tap_gesture_contract_test.dart` | `MERGE` / B3 |
| 7 | `ElEventDetails.tapCount` | 5 | tapCount 1/2/3、down metadata、TapDown/TapUp 恒零 | `event_public_contract_test.dart` | `MERGE` / B9 |
| 8 | `LongPress` | 4 | Timer、quick tap、consumer eager 抑制 Tap、down metadata | `tap_gesture_contract_test.dart` | `MERGE` / B3 |
| 9 | `Cancel` | 1 | move 距离取消 Tap | `tap_gesture_contract_test.dart` | `MERGE` / B3 |
| 10 | `Drag` | 19 | free/vertical/horizontal、axis cone/slop、delta/offset/direction、velocity clamp | `drag_gesture_contract_test.dart` | `MOVE+MERGE` / B4 |
| 11 | `Secondary tap` | 4 | secondary down/up/tap、nearest target、LongPress 隔离、移动取消但保留 TapUp | `tap_gesture_contract_test.dart` | `MERGE` / B3 |
| 12 | `Tertiary tap` | 3 | tertiary down/up/tap、nearest target、LongPress 隔离 | `tap_gesture_contract_test.dart` | `MERGE` / B3 |
| 13 | `Forward / Back side buttons` | 5 | forward/back phases、non-bubbling、LongPress 隔离、cancelAllPending | `tap_gesture_contract_test.dart` | `MERGE` / B3 |
| 14 | `Pointer events` | 2 | ROUTE-1/6 raw down/move/up 与 delta/originalEvent | `event_propagation_contract_test.dart` | `MERGE` / B1 |
| 15 | `Pointer signal` | 1 | ROUTE-7 wheel/signal 投递 | `event_propagation_contract_test.dart` | `MOVE` / B1 |
| 16 | `Pointer pan zoom` | 2 | raw panZoom start/update/end 与 per-event delta；后续 route/terminal 配对 | `event_propagation_contract_test.dart`；route terminal 与 `scale_gesture_contract_test.dart` 对账 | `SPLIT+MERGE` / B1、B7 |
| 17 | `Mouse Enter / Exit` | 8 | ROUTE-8 enter/exit、hover state 清理、防振荡、MouseTracker surface | `event_propagation_contract_test.dart`；状态生命周期/公开 getter 分进 B8/B9 | `SPLIT+MERGE` / B1、B8、B9 |
| 18 | `Focus / Blur` | 20 | ROUTE-7 focus/key bubble/stop；节点 attach/remove、traversal/scope、reason/semantics | `event_propagation_contract_test.dart`、`event_lifecycle_contract_test.dart`、`event_public_contract_test.dart`；真实 traversal wiring 归 B10 | `SPLIT+MERGE` / B1、B8、B9、B10 |
| 19 | `Bubble along RenderObject parent chain` | 23 | ROUTE-1/2/3/4/6、坐标重定向、direct 去重；OWN-4/8；DRAG-2/3 与轴竞争 | `event_propagation_contract_test.dart`、`pointer_ownership_contract_test.dart`、`tap_gesture_contract_test.dart`、`drag_gesture_contract_test.dart` | `SPLIT+MERGE` / B1–B4 |
| 20 | `ElView event risk coverage` | 6 | 真实 ElView bubble/stop/hit-test；TAP-1/2 bounds/active；hover wiring | primitive 分进 B1/B3，最小真实 ElView wiring 归消费者层 | `SPLIT+MERGE` / B1、B3、B10 |
| 21 | `preventDefault` | 1 | 旧用例仅验证 callback flag；阶段作用域、PointerDown 无默认动作、PointerSignal、LongPress 与传播边界已由专用合同覆盖 | `prevent_default_contract_test.dart`；Button/Link/Overlay/Scroll 默认动作仍归各消费者目录 | `MOVE+MERGE` / B9、B10 |
| 22 | `Lazy lifecycle` | 23 | event replacement/removal、deferred Tap/连击窗口、Scale/Drag/PanZoom cancel/end、dispose/reentrancy | `event_lifecycle_contract_test.dart`；手势专属识别断言与 B3/B4/B7 对账 | `SPLIT+MERGE` / B8（交 B3/B4/B7） |
| 23 | `Style and event independence` | 1 | ElView style rebuild 保持 dispatcher/event | `event_lifecycle_contract_test.dart`，作为最小 wiring 后归 B10 | `MERGE` / B8、B10 |
| 24 | `isTapPressed immediate release (CSS-aligned)` | 5 | pressed 初值、down/up、Tap/TapUp 即时、快速双击翻转 | `tap_gesture_contract_test.dart` | `MERGE` / B3 |
| 25 | `deferTap = false (default behaviour)` | 2 | immediate single Tap、double 中两次 Tap + DoubleTap | `tap_gesture_contract_test.dart` | `MERGE` / B3 |
| 26 | `deferTap = true (defer single tap)` | 4 | 延迟窗口、DoubleTap 抑制 pending Tap、TapUp 即时、无 DoubleTap 时忽略 defer | `tap_gesture_contract_test.dart` | `MERGE` / B3 |
| 27 | `long press owns the chain and keeps winner terminal phases` | 6 | LONG-2/3/4、consumer eager、TapUp/self Drag、ancestor loser、deferred Tap | `tap_gesture_contract_test.dart` 与 `pointer_ownership_contract_test.dart`；self Drag 生命周期与 B4 对账 | `SPLIT+MERGE` / B3、B2、B4 |
|  | **合计** | **171** |  |  | `event_test.dart` 最终 `DELETE-GATED` / B10 |

## 跨文件优先去重对

这些项目标题或机制高度重叠，但仍必须逐断言对账，不能直接删除：

| 合同 | 当前候选 | canonical 处理 |
|---|---|---|
| ROUTE-4/TAP-8 | `event_propagation_contract_test.dart`；`event_test.dart` Bubble 中 DragStart.stop；历史 `event_feature_contract_test.dart` D5 已改成 eager | 以新 propagation 文件为唯一 stop-only 组合合同；Bubble 中只保留其额外 route 维度，不能保留完整副本 |
| eager ancestor/descendant | `pointer_ownership_contract_test.dart` OWN-1～OWN-6；`eager_raw_phase_test.dart` | canonical 分别保留 active/pending、两种 winner 层级、同轮 queue recheck 和 terminal 负向断言 |
| queued loser recheck | `pointer_ownership_contract_test.dart` OWN-5；`event_dispatch_reentrancy_test.dart` 的 replacement queue | ownership 只测 membership drop；lifecycle 只测 generation/replacement drop，禁止混成一个原因 |
| bounds exit/re-enter | `tap_bounds_cancel_test.dart` TAP-B1～B17；`tap_gesture_contract_test.dart` TAP-7A | primitive 保留 boundary/eager 交叉项；真实 ElView/Scroll 只留 wiring |
| Drag 与 Tap | `drag_gesture_contract_test.dart` DRAG-1/2；`pointer_ownership_contract_test.dart` OWN-1/6；`drag_interaction_test.dart` accepted/eager Tap | passive、stop-only、eager、fling rescue 四个前置条件分开保留，不能因标题相似合并 |
| replacement/reentrancy | `drag_replacement_tap_test.dart`；`drag_interaction_test.dart` 后半；`event_dispatch_reentrancy_test.dart`；`event_test.dart` Lazy lifecycle | 统一进 B8，按 pending/accepted/terminal 与 shape-equal/structural/null 维度建矩阵 |
| metadata | `event_metadata_test.dart`；`event_public_contract_test.dart`；`event_public_surface_contract_test.dart`；`scale_gesture_contract_test.dart` | 数据字段和公开 surface 进 B9；手势胜负/terminal 本身仍归对应 canonical，不用 metadata 测试替代 |
| Scale | `scale_atomic_upgrade_test.dart`；`scale_two_finger_test.dart`；`event_metadata_test.dart` Scale 项；`event_test.dart` Lazy lifecycle | B7 统一原子接管、upgrade、rebaseline、rotation、velocity、removed/replacement terminal |
| resampling | `examples/flutter_base/test/integration/`；`examples/flutter_base/test/binding/resampling_test.dart` | 阶段 D 已迁出应用采样合同；混合文件中的采样专项用例已移除，普通交互不依赖应用绑定 |

## 删除门槛与记账要求

1. 每次迁移前，把具体测试补充为“当前测试名 → contract id → 目标测试名 → 保留断言”的逐测试记录；本文件的文件/group 映射不能替代该步骤。
2. `event_test.dart` 的 group 只有在表内所有目标批次完成后才能删除；禁止按 group 标题直接批量删除。
3. 真实组件测试若只是重复 primitive 矩阵，缩成一条 wiring 断言；若覆盖真实 hit-test、focus traversal、Scroll 或样式状态，则迁到对应消费者目录，不得丢失。
4. 每批提交必须让旧文件数量或测试 LOC 实际下降；迁移期临时复制只能存在于同一提交的编辑过程。
5. 每批只运行源文件、目标文件和受影响 consumer；最终九个 canonical 文件全部通过后，再删除 `event_test.dart`。
6. 该历史批次曾以测试总 LOC 低于 16,043 验收；本次迁移按行为覆盖验收，`GestureArena`/`Recognizer` 用于准确描述实际官方协作与通用识别器。
