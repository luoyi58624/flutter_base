# 独立手势识别器

`ElPressGestureRecognizer` 与 `ElTransformGestureRecognizer` 直接参加 Flutter
手势竞技场，只依赖 Dart 和 Flutter。它们保留同类手势冒泡，不依赖
`ElEventConfig`、`ElEventCallback`、RenderBox 或元素命中函数。
公共入口是 `package:flutter_base/ui.dart`，也可直接导入本目录的 `recognizers.dart`。

当前 `ElEventView` 与 `ElEventDispatcher` 仍使用旧实现，本次仅整理识别器及调用处。

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
- 祖先列表在本轮开始时冻结，修改 parent 从下一轮生效。路线使用所有者的识别参数，
  不把祖先配置当成继承值；宿主若需独立轴向或阈值，应协调报名关系。
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
| deferTap | 有双击订阅时等待窗口结束再通知单击，不持有竞技场 |
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

元素范围由宿主判断。需要完全按元素范围决定点击时，可将 `tapSlopTolerance`
设为 `double.infinity`，在原始 Move／Up 到来时检查范围，再调用
`cancelPointer(event.pointer, event: event)`。识别器不读取尺寸，也不内置回入业务规则。

`eagerGesture(cancelSelfTap, allowScaleUpgrade)`、`preventDefault` 和 `consumeDelta`
属于上层事件接口，不放入纯手势详情。宿主结合接受／取消原语和回调结果实现对应策略；
官方已判负的候选仍不能被强行复活。Press 与 Transform 独立使用时正常竞争，
跨家族连续转换和跨路线多指合并需要宿主协调。

## 测试组织

只保留 `press_test.dart` 与 `transform_test.dart` 两个识别器测试入口，覆盖独立参数、
官方竞争、各回调冒泡控制、主动取消、坐标、多指、速度和重入清理。
元素范围在示例页宿主测试中验证；旧事件的样式反馈、配置替换、位移消费及重采样
继续由旧实现的测试负责，后续接入 ElEventView 时迁移对应集成验证。
