# 独立手势识别器

`ElPressGestureRecognizer` 与 `ElTransformGestureRecognizer` 直接参加 Flutter
手势竞技场，只依赖 Dart 和 Flutter。它们保留同类手势冒泡，不依赖
`ElEventConfig`、`ElEventCallback`、RenderBox 或元素命中函数。
公共入口是 `package:flutter_base/ui.dart`，也可直接导入本目录的 `recognizers.dart`。

`ElEventView` 已通过内部宿主接入这两个识别器，旧点击、拖拽与缩放状态机已移除。

## 职责边界

| 识别器负责 | 宿主／ElEventView 负责 |
| --- | --- |
| 官方竞技场接受、拒绝和取消 | 元素命中范围、禁用及卸载时机 |
| 点击、连击、按钮、长按的判断 | ElEventConfig 到独立识别参数的转换 |
| 拖拽、缩放、旋转与释放速度 | hasTap／hasHover 等样式状态和反馈时间 |
| parent 路线、回调顺序与 stopPropagation | ElGestureDetails 到 ElEventCallback 的适配 |
| 根据各级官方事件变换换算坐标 | 实时元素几何和越界业务策略 |
| 唯一终态、指针路由与计时器清理 | dragProxy、位移消费及帧输出策略 |

## 冒泡与官方规则

- 宿主在命中的 PointerDown 调用 `addPointer`，触控板开始调用 `addPointerPanZoom`。
  后续事件由官方 PointerRouter 投递，不重复转发。
- `parent` 表达同类识别结果的冒泡关系。路线由最深识别器参赛，El 祖先订阅结果；
  官方识别器正常独立竞争，任一方获胜都会排除另一方。
- 每个 Press 回调接收 `ElPressGestureDetails`，每个 Transform 回调接收
  `ElTransformGestureDetails`，均包含 `stopPropagation()`。
- 停止冒泡不等于主动接受竞技场。Update 只截断当前更新，Down／Start／业务点击
  可以建立本轮后续阶段的传播边界。已公开的 Down／Start 必须结清，终态中的 stop
  不吞掉祖先清理；Start 或连击 Down 后发截断会取消祖先已公开的候选。
- 祖先列表在本轮开始时冻结，修改 parent 从下一轮生效。Press 各成员保存自己的
  参数、资格和连击历史；Transform 的同一路线采用所有者参数，宿主只将兼容的
  轴向和阈值连为冒泡链，不同意图独立报名。
- 各成员登记自己的开始事件，识别器使用其官方 transform 换算本地坐标。
  详情沿路线复用，跨回调保存记录时应保存所需数值。

## 按压 API

```dart
final parent = ElPressGestureRecognizer()..onTap = (details) {};
final child = ElPressGestureRecognizer(parent: parent)
  ..onTap = (details) {
    details.stopPropagation();
  };
```

| 参数 | 用途 |
| --- | --- |
| doubleTapInterval／tripleTapInterval | 连击时间窗口 |
| consecutiveTapDistance | 连击间允许的位置间距 |
| longPressDelay | 长按等待时间 |
| tapSlopTolerance／longPressSlopTolerance | 点击与长按的移动容差，缺省采用官方设备值 |
| secondaryTapSlopTolerance | 侧键独立移动容差，缺省沿用主键容差 |
| deferTap | 有双击订阅时等待窗口结束再通知单击，不持有竞技场 |
| isEligible | 提交成员点击历史或请求长按归属前的纯资格检查 |
| cancelTapOnLongPress | 长按是否直接取消本成员点击，默认 true |
| supportedDevices／allowedButtonsFilter | 官方设备和按钮过滤 |

支持主键单／双／三击、长按、右键、中键、前进与后退按钮。
识别参数在按下时冻结；相同参数保留连击窗口，参数变化后重新分组。
普通释放等待官方 sweep，保持官方子 Tap 的竞争优先顺序。
移动容差取消最终点击时，已获胜序列仍可通知 Up；显式取消则终止该指针，不再通知 Up／Tap。

## 变换 API

```dart
final drag = ElTransformGestureRecognizer(
  axis: Axis.horizontal,
  startDistance: 6,
  minFlingVelocity: 50,
  maxFlingVelocity: 8000,
)..onDragUpdate = (details) {
  details.stopPropagation();
};
```

参数为 `axis`、`lockAxis`、`startDistance`、`horizontalAngle`、`minFlingDistance`、
`minFlingVelocity`、`maxFlingVelocity`，设备过滤使用官方 `supportedDevices` 和
`allowedButtonsFilter`。识别参数在本轮开始时冻结。

单指拖拽与多指变换共用所有权，每根新增指针仍须赢得自己的官方竞技场。
拖拽采用 latestPointer，只有已接受的指针参与驱动、中心、比例和旋转计算。
速度只拟合真实输入：合成 Move 更新位移但不进入拟合，Up 位置跳变不进入速度。
真实停顿按输入时间判断；稀疏采样仍受距离、速度阈值及最大速度约束。

## 宿主控制

- `acceptPointer(pointer)`：主动请求指定指针的官方归属，不覆盖已经确认的其他赢家。
- `cancelPointer(pointer, event: currentEvent)`：取消当前冒泡路线中的该指针，可传入
  触发取消的输入；取消不会恢复。Transform 中其余已接受指针可以继续。
- `cancel()`：取消自身拥有的全部活动手势、连击窗口及待发通知，之后可以复用。
- `dispose()`：销毁识别器，释放自己的路线和计时器。
- Press 的 `rejectTap(pointer)` 只撤销本成员点击资格，保留已经开始的释放通知；
  `cancelMember(pointer)` 则结清本成员，不中止其他成员。
- Transform 的 `cancelMember(pointer, cancelDrag: ..., cancelScale: ...)`
  只结清指定成员和家族，适用于宿主的拖拽升级或动态卸载。
- `onAccepted(pointer)` 表示官方已经接受该路线；Press 的 `onReleased(event)`
  在同步 Up／Tap／连击回调之后触发，延迟单击不推迟该通知。

元素范围由宿主判断。需要完全按元素范围决定点击时，可将 `tapSlopTolerance`
设为 `double.infinity`，将范围结果通过 `isEligible` 提供给识别器；移出／移回
的反馈由宿主控制。若需要永久终止当前成员，调用 `cancelMember`；仅永久取消
点击用 `rejectTap`。`cancelPointer` 会取消整条路线，不能用来暂时表示元素越界。

`eagerGesture(cancelSelfTap, allowScaleUpgrade)`、`preventDefault` 和 `consumeDelta`
属于上层事件接口，不放入纯手势详情。宿主结合接受／取消原语和回调结果实现对应策略；
官方已判负的候选仍不能被强行复活。Press 与 Transform 独立使用时正常竞争；
需要长按后继续拖拽等同次输入协作时，可在报名之前共享 `ElGestureArenaTeam`：

```dart
final team = ElGestureArenaTeam();
final press = ElPressGestureRecognizer()..team = team;
final transform = ElTransformGestureRecognizer()..team = team;
```

团队通过官方 `GestureArenaTeam` 提交一个席位，外部获胜会拒绝整个团队；团队获胜后
各成员仍按自己的条件识别，不恢复已自行退出的成员。上层不同点击意图不能随意
共用席位，否则可能改变中间官方组件的点击优先级。

## ElEventView 的状态与兼容边界

- 仅公开 `context.hasTap`、`context.hasHover`，以及 `ElEventView.maybeOf(context)`。
  按压反馈来自 Down／Up，Cancel、禁用、卸载会清理；读取状态不创建参赛者。
- 只监听主键 Down／Up／Cancel 时通过 PointerRouter 观察；声明 onTap 或连击
  激活回调才参与主键点击竞争。长按与侧键按自己的监听和识别条件竞争。
- 长按先赢得官方竞技场，再通知业务。`preventDefault()` 可保留 El 点击资格并阻止
  El 成员排他，不能恢复已经被官方淘汰的识别器。
- Transform 参数从下一次 Down 生效；Press 识别配置变化会取消当前候选并重置分组。
  同形闭包热替换可继续当前手势，回调结构变化结清旧路线。
  中途新增手势不会补报旧 Down，不会在已经关闭的竞技场重新报名。
- 不同拖拽阈值或轴向独立识别，不再向尚未达标的后代反向发送“提案 Start”。
  同一命中链首个实际接受的拖拽作为输出驱动，其他意图不能随后抢回。
- 宿主在 Drag 升级 Scale 前结清 Drag；触摸指针从两指变为一指时发送 ScaleEnd，
  不再额外合成一次 pointerCount 为 1 的 ScaleUpdate。
- 移动阈值由真实 Move 触发；Up 坐标跳变不补救 DragStart、不加入位移或速度拟合。

## 测试组织

只保留 `press_test.dart` 与 `transform_test.dart` 两个识别器测试入口，覆盖独立参数、
官方竞争、各回调冒泡控制、主动取消、坐标、多指、速度和重入清理。
元素范围、状态反馈、配置替换、位移消费及重采样在 `test/ui/cores/event` 的宿主回归中验证。
`view_test.dart` 覆盖官方 Tap 上下层、样式读取开关、纯 Down 观察者、长按穿插节点、
双向 Drag 竞争和落败后的独占请求；示例页自动化不代表真实设备输入已验收。
