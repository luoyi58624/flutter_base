# example 页面与旧测试 API 迁移报告

日期：2026-10-30。状态：全部代码迁移与验收完成；.codex 最终汇报文件写入被沙箱阻止。

## 结果与验收

已完成白名单迁移。全仓与 example 独立工程 analyze 均为 0 error、0 warning、0 info，原始输出均为 No issues found。lib/**（含 my_ui）、test/my_ui 与 pubspec/锁文件受保护快照前后无差异（共 397 个已有文件）。未删减页面能力，重采样断言未改变。

| 验收项 | 结果 |
|---|---|
| 根工程 flutter analyze --no-pub（全仓） | 通过，0 error / 0 warning / 0 info，退出码 0 |
| resampling_test.dart | 30 通过，退出码 0 |
| test/flutter/hooks | 9 通过，退出码 0 |
| model_value_test.dart（额外覆盖本次 import 删除） | 7 通过，退出码 0 |
| example 独立工程 flutter analyze --no-pub | 通过，0 error / 0 warning / 0 info，退出码 0 |
| example 既有 custom_gestures_page_test.dart | 12 通过，1 默认截图预览跳过，退出码 0 |

**明确的导入例外：**独立识别器没有公共导出，custom_gestures.dart:3 对该内核导入使用唯一一条 implementation_imports 单行豁免；保留页面自行决定范围、移出后永久取消、直接释放识别器和六种底层取消原因。没有全局 ignore、没有用忽略诊断处理任何旧 API 错误。该页依赖的底层类型以后再变化时仍需跟随迁移。



## 执行计划与边界

1. 自定义手势页保留独立识别器、父子 parent 关系、Listener.addPointer、越界 cancelPointer、重置和 dispose；改用 PressRecognizer / PressGestureCallback / PressGestureDetails / PressCancelReason，按 callbacks[ElEventPhase.*] 注册阶段。该底层识别器不由 ui.dart 导出，演示页直接精确导入当前 press.dart，不扩大库的公共导出。
2. view.dart 的两个 ElStyle.backgroundColor 改为 bgColor，保留颜色与动画。
3. view/base.dart 外层 ElEventView 改为 ElView；Builder 内用 ElView.of(context) 读取最近外层视图的 hasTap / hasHover，保留颜色、缩放与过渡优先级。
4. resampling_test.dart 的事件详情列表改为 ElEventDetails，宿主改为 ElView；依赖边界测试遍历目录同步为 lib/src/ui/cores/view/event，断言不变。
5. 仅删除 7 个 hooks 文件与 model_value_test.dart 的冗余 flutter_hooks import。
6. 串行执行全仓 analyze、resampling、hooks、model_value、example analyze 和既有手势页测试；使用 --no-pub 避免解析依赖修改锁文件，测试使用 expanded 输出与 concurrency=1。完整原始 stdout/stderr 和退出码写入本报告。

仅主动修改用户白名单内的源码和报告；不对工作仓库执行 git 命令或提交，不修改 lib/**、test/my_ui 或 pubspec。未添加或修改白名单外的测试文件；不运行前台窗口测试。

## 已核对的源码依据

- lib/src/ui/cores/view/event/event.dart:16：ElEventHandler = void Function(ElEventDetails event)。
- lib/src/ui/cores/view/event/press.dart:2150、2269：PressRecognizer 与阶段回调表；:246、267、681：PressCancelReason / PressGestureCallback / PressGestureDetails。
- lib/src/ui/cores/view/event/press.dart:818：cancelPointer 保留宿主主动越界取消通道。
- lib/src/ui/cores/view/event/dispatcher.dart:626-682：内核同样按 ElEventPhase 构建识别器 callbacks，业务详情由适配层转换。
- lib/src/ui/cores/view/view.dart:17、69：ElView(event: ...) 与 ElView.of(context)。
- lib/src/ui/cores/view/style/style.dart:55：ElStyle.bgColor。
- lib/src/ui/cores/view/style/style_context.dart:20-23：hasHover / hasTap 读取 ViewState 位。
- lib/src/ui/cores/view/render/render_view.dart:1029-1052 与 style/state/view_state.dart:94-116：读取 hover/tap 状态即登记依赖并启用事件跟踪，无需添加空回调。
- lib/flutter_base.dart:10：已重新导出 flutter_hooks。

## 工程结构

根包 flutter_base 与 example 均有独立 pubspec.yaml；example 通过 path: ../ 依赖根包。根 pubspec 未声明 workspace。example 有既有 test/custom_gestures_page_test.dart，可额外验证交互行为，预览截图用例默认跳过。

## 执行环境

默认命令工具两次在进程创建前失败：`Rejected("Failed to create unified exec process: helper_unknown_error: setup refresh had errors")`。后续改用可用 Node 进程通道，PowerShell 后台启动 Flutter，保留输出并设置 10 分钟进程树超时；没有提权。系统 Get-CimInstance 进程查询被拒绝访问，与源码或测试无关。

## 红色条目前后对照

行号以本次修改前的现场内容与当前修改后内容为准；原始 31 error + 8 info 来自用户提供的清单，本次未把失败的启动尝试记为基线分析结果。

### A. 自定义手势演示页

保留独立识别器和全部手势功能。旧的 `El*` 识别器类型现在对应底层 `Press*` 类型；它们不是业务回调类型 `ElEventDetails`。由于公共 `ui.dart`（含 view/index.dart 的间接导出）未导出独立识别器，页面改为精确导入 `package:flutter_base/src/ui/cores/view/event/press.dart`，并在页面注明原因。该跨包内核导入有一处精确的 `// ignore: implementation_imports`（example/lib/src/pages/custom_gestures.dart:3）；这是为保留独立识别器演示而声明的 lint 例外，没有更改全局分析配置或屏蔽其他诊断。

| 修改前 file:line 与引用 | 修改后 file:line 与引用 |
|---|---|
| example/lib/src/pages/custom_gestures.dart:25 `late ElPressGestureRecognizer _basic;` | example/lib/src/pages/custom_gestures.dart:33 `late PressRecognizer _basic;` |
| example/lib/src/pages/custom_gestures.dart:26 `late ElPressGestureRecognizer _bubbleParent;` | example/lib/src/pages/custom_gestures.dart:34 `late PressRecognizer _bubbleParent;` |
| example/lib/src/pages/custom_gestures.dart:27 `late ElPressGestureRecognizer _bubbleChild;` | example/lib/src/pages/custom_gestures.dart:35 `late PressRecognizer _bubbleChild;` |
| example/lib/src/pages/custom_gestures.dart:28 `late ElPressGestureRecognizer _elInOfficial;` | example/lib/src/pages/custom_gestures.dart:36 `late PressRecognizer _elInOfficial;` |
| example/lib/src/pages/custom_gestures.dart:29 `late ElPressGestureRecognizer _elOutsideOfficial;` | example/lib/src/pages/custom_gestures.dart:37 `late PressRecognizer _elOutsideOfficial;` |
| example/lib/src/pages/custom_gestures.dart:30 `late ElPressGestureRecognizer _scrollPress;` | example/lib/src/pages/custom_gestures.dart:38 `late PressRecognizer _scrollPress;` |
| example/lib/src/pages/custom_gestures.dart:53 `ElPressGestureRecognizer _press(` | example/lib/src/pages/custom_gestures.dart:61 `PressRecognizer _press(` |
| example/lib/src/pages/custom_gestures.dart:56 `ElPressGestureRecognizer? parent,` | example/lib/src/pages/custom_gestures.dart:64 `PressRecognizer? parent,` |
| example/lib/src/pages/custom_gestures.dart:59 `return ElPressGestureRecognizer()` | example/lib/src/pages/custom_gestures.dart:67 `return PressRecognizer()` |
| example/lib/src/pages/custom_gestures.dart:72 `ElPressGestureCallback _handler(` | example/lib/src/pages/custom_gestures.dart:80 `PressGestureCallback _handler(` |
| example/lib/src/pages/custom_gestures.dart:121 `Iterable<ElPressGestureRecognizer> get _recognizers => [` | example/lib/src/pages/custom_gestures.dart:163 `Iterable<PressRecognizer> get _recognizers => [` |
| example/lib/src/pages/custom_gestures.dart:132 `ElPressGestureDetails event, {` | example/lib/src/pages/custom_gestures.dart:174 `PressGestureDetails event, {` |
| example/lib/src/pages/custom_gestures.dart:143 `ElGestureCancelReason.longPressAccepted => '长按已成立',` | example/lib/src/pages/custom_gestures.dart:185 `PressCancelReason.longPressAccepted => '长按已成立',` |
| example/lib/src/pages/custom_gestures.dart:144 `ElGestureCancelReason.arenaRejected => '其他手势取得所有权',` | example/lib/src/pages/custom_gestures.dart:186 `PressCancelReason.arenaRejected => '其他手势取得所有权',` |
| example/lib/src/pages/custom_gestures.dart:145 `ElGestureCancelReason.rejected => '移动、按钮或指针条件不满足',` | example/lib/src/pages/custom_gestures.dart:187 `PressCancelReason.rejected => '移动、按钮或指针条件不满足',` |
| example/lib/src/pages/custom_gestures.dart:146 `ElGestureCancelReason.ineligible => '暂时不满足点击条件',` | example/lib/src/pages/custom_gestures.dart:188 `PressCancelReason.ineligible => '暂时不满足点击条件',` |
| example/lib/src/pages/custom_gestures.dart:147 `ElGestureCancelReason.pointerCanceled => '平台取消指针',` | example/lib/src/pages/custom_gestures.dart:189 `PressCancelReason.pointerCanceled => '平台取消指针',` |
| example/lib/src/pages/custom_gestures.dart:148 `ElGestureCancelReason.canceled => '宿主取消或生命周期结束',` | example/lib/src/pages/custom_gestures.dart:190 `PressCancelReason.canceled => '宿主取消或生命周期结束',` |
| example/lib/src/pages/custom_gestures.dart:515 `ElPressGestureRecognizer recognizer,` | example/lib/src/pages/custom_gestures.dart:557 `PressRecognizer recognizer,` |
| example/lib/src/pages/custom_gestures.dart:529 `ElPressGestureRecognizer recognizer, {` | example/lib/src/pages/custom_gestures.dart:571 `PressRecognizer recognizer, {` |


旧 `..onTapDown = handler` 等 setter 改为 `..callbacks[ElEventPhase.tapDown] = handler`；同样迁移 tapUp、tap、tapCancel、doubleTapDown、tripleTapDown、doubleTap、tripleTap、longPress 与右键/中键/前进/后退各 Down/Up/Tap（共 23 处注册）。`parent`、`stopPropagation`、`deferTap`、`tapSlopTolerance = double.infinity`、Listener 输入和页面 `_cancelOutside`、重置、dispose 均保留。六种底层取消原因及日志文案逐一保留，无能力删除。完整改动行见下文。

### B. view.dart 背景色

| 修改前 | 修改后 |
|---|---|
| example/lib/src/pages/view.dart:32 `backgroundColor: flag.value` | example/lib/src/pages/view.dart:32 `bgColor: flag.value` |
| example/lib/src/pages/view.dart:53 `backgroundColor: flag.value` | example/lib/src/pages/view.dart:53 `bgColor: flag.value` |

两处实际位于 ElStyle 构造参数内；颜色、尺寸、圆角、裁剪和过渡未变。Flutter Scaffold / AppBar / BottomSheet 自身的 backgroundColor 参数保持不变。

### C. base 页读取状态

| 修改前 | 修改后 |
|---|---|
| example/lib/src/pages/view/base.dart:17 `ElEventView(...)` | example/lib/src/pages/view/base.dart:17 `ElView(...)` |
| 旧 Builder 直接读取 BuildContext 扩展 | example/lib/src/pages/view/base.dart:21 `final state = ElView.of(context);`，订阅最近外层 ElView |
| example/lib/src/pages/view/base.dart:25 `backgroundColor: context.hasTap` | example/lib/src/pages/view/base.dart:27 `bgColor: state.hasTap` |
| example/lib/src/pages/view/base.dart:27 `context.hasHover` | example/lib/src/pages/view/base.dart:29 `state.hasHover` |
| example/lib/src/pages/view/base.dart:32 `context.hasTap` | example/lib/src/pages/view/base.dart:34 `state.hasTap` |
| example/lib/src/pages/view/base.dart:34 `context.hasHover` | example/lib/src/pages/view/base.dart:36 `state.hasHover` |
| example/lib/src/pages/view/base.dart:38 `context.hasTap`（过渡时长） | example/lib/src/pages/view/base.dart:42 `state.hasTap`（过渡时长） |

保留按下优先于悬停的颜色与缩放：绿/紫/蓝、0.9/1.5/1.0；按下无过渡，其余 250ms。内层依然是展示样式的 ElView；Builder 读取它之上的事件宿主状态。读取 hasTap/hasHover 即可启用宿主状态观察，不添加无业务意义的空回调。

### D. resampling 测试

| 修改前 | 修改后 |
|---|---|
| test/flutter_base/sdk/binding/resampling_test.dart:402 `<ElEventCallback>[]` | test/flutter_base/sdk/binding/resampling_test.dart:402 `<ElEventDetails>[]` |
| test/flutter_base/sdk/binding/resampling_test.dart:408 `ElEventView(...)` | test/flutter_base/sdk/binding/resampling_test.dart:408 `ElView(...)` |
| test/flutter_base/sdk/binding/resampling_test.dart:649 `Directory('lib/src/ui/cores/event')` | test/flutter_base/sdk/binding/resampling_test.dart:649 `Directory('lib/src/ui/cores/view/event')` |

前两处恢复对现事件内核的接入；最后一处使既有依赖边界断言继续遍历真正的事件实现，而不是读取不存在的旧目录。事件原始对象同一性、采样位置、结束次数与所有其他断言均不变。

### E. 8 个 unnecessary_import

只删冗余 import 行，不改测试主体，不对这些文件执行格式化。

| 原位置 | 修改 |
|---|---|
| test/flutter/hooks/add_listener_test.dart:3 | 删除 `import 'package:flutter_hooks/flutter_hooks.dart';`；保留 `flutter_base.dart`（重新导出 hooks） |
| test/flutter/hooks/animation_status_listener_test.dart:3 | 删除 `import 'package:flutter_hooks/flutter_hooks.dart';`；保留 `flutter_base.dart`（重新导出 hooks） |
| test/flutter/hooks/curve_animation_test.dart:3 | 删除 `import 'package:flutter_hooks/flutter_hooks.dart';`；保留 `flutter_base.dart`（重新导出 hooks） |
| test/flutter/hooks/did_update_test.dart:3 | 删除 `import 'package:flutter_hooks/flutter_hooks.dart';`；保留 `flutter_base.dart`（重新导出 hooks） |
| test/flutter/hooks/hook_state_test.dart:3 | 删除 `import 'package:flutter_hooks/flutter_hooks.dart';`；保留 `flutter_base.dart`（重新导出 hooks） |
| test/flutter/hooks/simple_hooks_test.dart:3 | 删除 `import 'package:flutter_hooks/flutter_hooks.dart';`；保留 `flutter_base.dart`（重新导出 hooks） |
| test/flutter/hooks/watch_test.dart:3 | 删除 `import 'package:flutter_hooks/flutter_hooks.dart';`；保留 `flutter_base.dart`（重新导出 hooks） |
| test/flutter/model_value/model_value_test.dart:5 | 删除 `import 'package:flutter_hooks/flutter_hooks.dart';`；保留 `flutter_base.dart`（重新导出 hooks） |


### 完整改动行（无工作仓库 git 操作）

以下对比由本次读取的原文与修改后文件直接计算；`-旧行号` / `+新行号` 表示修改前后。

#### example/lib/src/pages/custom_gestures.dart

```diff
+2: // 独立识别器未由公共入口导出；此页演示内核，保留自行判断范围与取消的行为。
+3: // ignore: implementation_imports
+4: import 'package:flutter_base/src/ui/cores/view/event/press.dart'
+5:     show
+6:         ElEventPhase,
+7:         PressRecognizer,
+8:         PressGestureCallback,
+9:         PressGestureDetails,
+10:         PressCancelReason;
-2: import 'package:flutter_base/ui.dart';
+33:   late PressRecognizer _basic;
+34:   late PressRecognizer _bubbleParent;
+35:   late PressRecognizer _bubbleChild;
+36:   late PressRecognizer _elInOfficial;
+37:   late PressRecognizer _elOutsideOfficial;
+38:   late PressRecognizer _scrollPress;
-25:   late ElPressGestureRecognizer _basic;
-26:   late ElPressGestureRecognizer _bubbleParent;
-27:   late ElPressGestureRecognizer _bubbleChild;
-28:   late ElPressGestureRecognizer _elInOfficial;
-29:   late ElPressGestureRecognizer _elOutsideOfficial;
-30:   late ElPressGestureRecognizer _scrollPress;
+61:   PressRecognizer _press(
-53:   ElPressGestureRecognizer _press(
+64:     PressRecognizer? parent,
-56:     ElPressGestureRecognizer? parent,
+67:     return PressRecognizer()
-59:     return ElPressGestureRecognizer()
+70:       ..callbacks[ElEventPhase.tapDown] = _handler(source, pressed: true)
+71:       ..callbacks[ElEventPhase.tapUp] = _handler(source, pressed: false)
+72:       ..callbacks[ElEventPhase.tap] = _handler(source, counter: tapCounter)
+73:       ..callbacks[ElEventPhase.tapCancel] = _handler(
-62:       ..onTapDown = _handler(source, pressed: true)
-63:       ..onTapUp = _handler(source, pressed: false)
-64:       ..onTap = _handler(source, counter: tapCounter)
-65:       ..onTapCancel = _handler(
+80:   PressGestureCallback _handler(
-72:   ElPressGestureCallback _handler(
+91:       ..callbacks[ElEventPhase.doubleTapDown] = _handler('basic')
+92:       ..callbacks[ElEventPhase.tripleTapDown] = _handler('basic')
+93:       ..callbacks[ElEventPhase.doubleTap] = _handler(
+94:         'basic',
+95:         counter: 'doubleTap',
+96:       )
+97:       ..callbacks[ElEventPhase.tripleTap] = _handler(
+98:         'basic',
+99:         counter: 'tripleTap',
+100:       )
+101:       ..callbacks[ElEventPhase.longPress] = _handler(
+102:         'basic',
+103:         counter: 'longPress',
+104:         pressed: true,
+105:       );
-83:       ..onDoubleTapDown = _handler('basic')
-84:       ..onTripleTapDown = _handler('basic')
-85:       ..onDoubleTap = _handler('basic', counter: 'doubleTap')
-86:       ..onTripleTap = _handler('basic', counter: 'tripleTap')
-87:       ..onLongPress = _handler('basic', counter: 'longPress', pressed: true);
+110:           ..callbacks[ElEventPhase.tapDown] = (event) {
-92:           ..onTapDown = (event) {
+114:           ..callbacks[ElEventPhase.tap] = (event) {
-96:           ..onTap = (event) {
+125:       ..callbacks[ElEventPhase.secondaryTapDown] = _handler(
+126:         'basic',
+127:         pressed: true,
+128:       )
+129:       ..callbacks[ElEventPhase.secondaryTapUp] = _handler(
+130:         'basic',
+131:         pressed: false,
+132:       )
+133:       ..callbacks[ElEventPhase.secondaryTap] = _handler(
+134:         'basic',
+135:         counter: 'secondaryTap',
+136:       )
+137:       ..callbacks[ElEventPhase.tertiaryTapDown] = _handler(
+138:         'basic',
+139:         pressed: true,
+140:       )
+141:       ..callbacks[ElEventPhase.tertiaryTapUp] = _handler(
+142:         'basic',
+143:         pressed: false,
+144:       )
+145:       ..callbacks[ElEventPhase.tertiaryTap] = _handler(
+146:         'basic',
+147:         counter: 'tertiaryTap',
+148:       )
+149:       ..callbacks[ElEventPhase.forwardTapDown] = _handler(
+150:         'basic',
+151:         pressed: true,
+152:       )
+153:       ..callbacks[ElEventPhase.forwardTapUp] = _handler('basic', pressed: false)
+154:       ..callbacks[ElEventPhase.forwardTap] = _handler(
+155:         'basic',
+156:         counter: 'forwardTap',
+157:       )
+158:       ..callbacks[ElEventPhase.backTapDown] = _handler('basic', pressed: true)
+159:       ..callbacks[ElEventPhase.backTapUp] = _handler('basic', pressed: false)
+160:       ..callbacks[ElEventPhase.backTap] = _handler('basic', counter: 'backTap');
-107:       ..onSecondaryTapDown = _handler('basic', pressed: true)
-108:       ..onSecondaryTapUp = _handler('basic', pressed: false)
-109:       ..onSecondaryTap = _handler('basic', counter: 'secondaryTap')
-110:       ..onTertiaryTapDown = _handler('basic', pressed: true)
-111:       ..onTertiaryTapUp = _handler('basic', pressed: false)
-112:       ..onTertiaryTap = _handler('basic', counter: 'tertiaryTap')
-113:       ..onForwardTapDown = _handler('basic', pressed: true)
-114:       ..onForwardTapUp = _handler('basic', pressed: false)
-115:       ..onForwardTap = _handler('basic', counter: 'forwardTap')
-116:       ..onBackTapDown = _handler('basic', pressed: true)
-117:       ..onBackTapUp = _handler('basic', pressed: false)
-118:       ..onBackTap = _handler('basic', counter: 'backTap');
+163:   Iterable<PressRecognizer> get _recognizers => [
-121:   Iterable<ElPressGestureRecognizer> get _recognizers => [
+174:     PressGestureDetails event, {
-132:     ElPressGestureDetails event, {
+185:       PressCancelReason.longPressAccepted => '长按已成立',
+186:       PressCancelReason.arenaRejected => '其他手势取得所有权',
+187:       PressCancelReason.rejected => '移动、按钮或指针条件不满足',
+188:       PressCancelReason.ineligible => '暂时不满足点击条件',
+189:       PressCancelReason.pointerCanceled => '平台取消指针',
+190:       PressCancelReason.canceled => '宿主取消或生命周期结束',
-143:       ElGestureCancelReason.longPressAccepted => '长按已成立',
-144:       ElGestureCancelReason.arenaRejected => '其他手势取得所有权',
-145:       ElGestureCancelReason.rejected => '移动、按钮或指针条件不满足',
-146:       ElGestureCancelReason.ineligible => '暂时不满足点击条件',
-147:       ElGestureCancelReason.pointerCanceled => '平台取消指针',
-148:       ElGestureCancelReason.canceled => '宿主取消或生命周期结束',
+557:     PressRecognizer recognizer,
-515:     ElPressGestureRecognizer recognizer,
+571:     PressRecognizer recognizer, {
-529:     ElPressGestureRecognizer recognizer, {
```

#### example/lib/src/pages/view.dart

```diff
+32:                           bgColor: flag.value
-32:                           backgroundColor: flag.value
+53:                                 bgColor: flag.value
-53:                                 backgroundColor: flag.value
```

#### example/lib/src/pages/view/base.dart

```diff
+17:                 ElView(
-17:                 ElEventView(
+20:                       // 读取外层视图状态，并按实际读取的属性订阅更新。
+21:                       final state = ElView.of(context);
+27:                           bgColor: state.hasTap
-25:                           backgroundColor: context.hasTap
+29:                               : state.hasHover
-27:                               : context.hasHover
+34:                             state.hasTap
-32:                             context.hasTap
+36:                                 : state.hasHover
-34:                                 : context.hasHover
+40:                           transitions: [
+41:                             .all(
+42:                               state.hasTap
+43:                                   ? .zero
+44:                                   : Duration(milliseconds: 250),
+45:                             ),
+46:                           ],
-38:                           transitions: [.all(context.hasTap ? .zero : Duration(milliseconds: 250))],
```

#### test/flutter_base/sdk/binding/resampling_test.dart

```diff
+402:     final updates = <ElEventDetails>[];
-402:     final updates = <ElEventCallback>[];
+408:           child: ElView(
-408:           child: ElEventView(
+649:     final eventFiles = Directory('lib/src/ui/cores/view/event')
-649:     final eventFiles = Directory('lib/src/ui/cores/event')
```

#### test/flutter/hooks/add_listener_test.dart

```diff
-3: import 'package:flutter_hooks/flutter_hooks.dart';
```

#### test/flutter/hooks/animation_status_listener_test.dart

```diff
-3: import 'package:flutter_hooks/flutter_hooks.dart';
```

#### test/flutter/hooks/curve_animation_test.dart

```diff
-3: import 'package:flutter_hooks/flutter_hooks.dart';
```

#### test/flutter/hooks/did_update_test.dart

```diff
-3: import 'package:flutter_hooks/flutter_hooks.dart';
```

#### test/flutter/hooks/hook_state_test.dart

```diff
-3: import 'package:flutter_hooks/flutter_hooks.dart';
```

#### test/flutter/hooks/simple_hooks_test.dart

```diff
-3: import 'package:flutter_hooks/flutter_hooks.dart';
```

#### test/flutter/hooks/watch_test.dart

```diff
-3: import 'package:flutter_hooks/flutter_hooks.dart';
```

#### test/flutter/model_value/model_value_test.dart

```diff
-5: import 'package:flutter_hooks/flutter_hooks.dart';
```

## 验收运行方式与环境限制

原 SDK 安装目录的 cache 不可写，直接启动的 Flutter 工具输出如下：

```text
Flutter failed to open a file at "D:\app\fvm\default\bin\cache\lockfile". The flutter tool cannot access the file or directory.
Please ensure that the SDK and/or project is installed in a location that has read/write permissions for the current user.
```

为完成实际验收，使用原 SDK 自带 Dart 与原 flutter_tools.snapshot 启动相同 Flutter CLI；只将 FLUTTER_ROOT 指向本次临时运行目录，缓存元数据复制至临时目录，SDK 包和引擎文件通过目录联接读取。Flutter 与 Dart 的版本未替换（Flutter 3.47.5 / Dart 3.13.4）。分析器使用其支持的 ANALYZER_STATE_LOCATION_OVERRIDE；测试子进程补齐受限环境缺失的 Windows Program Files 变量。原 SDK 源码和工作仓库的 pubspec 均未修改。

实际公共启动前缀：

```text
D:/app/fvm/default/bin/cache/dart-sdk/bin/dart.exe --packages=D:/app/fvm/default/packages/flutter_tools/.dart_tool/package_config.json D:/app/fvm/default/bin/cache/flutter_tools.snapshot --no-version-check <Flutter 子命令与参数>
```

本次运行环境覆盖：

```text
FLUTTER_ROOT=C:\Users\luoyi\AppData\Local\Temp\flutter-example-api-fix-20261030
ANALYZER_STATE_LOCATION_OVERRIDE=C:\Users\luoyi\AppData\Local\Temp\flutter-example-api-fix-20261030\analysis-state
PROGRAMFILES(X86)=C:\Program Files (x86)
PROGRAMFILES=C:\Program Files
PROGRAMW6432=C:\Program Files
```

下文的 flutter 命令均指该原版 Flutter CLI 的实际执行。--no-pub 用于沿用已有依赖和锁文件，未省略 analyze 的仓库范围或测试中的用例。所有测试无头执行，concurrency=1；没有运行全仓测试、应用窗口或设备集成测试。最初静默挂起的本次启动进程树已仅按父子进程关系停止。没有对工作仓库执行 git 操作；SDK 版本探测过程中 Flutter 自身对 SDK 目录执行了只读 git log。

### 环境修复与导入例外前的输出

以下是失败尝试的原始输出，单独列出，不作为最终验收结果。

### --no-version-check analyze --no-pub

工作目录：`D:/project/flutter/flutter_base`；退出码：`1`。

```text

Oops; flutter has exited unexpectedly: "Null check operator used on a null value".
A crash report has been written to D:\project\flutter\flutter_base\flutter_01.log
This crash may already be reported. Check GitHub for similar crashes.
https://github.com/flutter/flutter/issues?q=is%3Aissue+Null+check+operator+used+on+a+null+value

To report your crash to the Flutter team, first read the guide to filing a bug.
https://flutter.dev/to/report-bugs

Create a new GitHub issue by pasting this link into your browser and completing the issue template. Thank you!
https://github.com/flutter/flutter/issues/new?title=%5Btool_crash%5D+_TypeError%3A+%28%230++++++MaterialFonts.updateInner+%28package%3Aflutter_tools%2Fsrc%2Fflutter_cache.dart%3A155%3A49%29%29&body=%23%23+Command%0A%60%60%60sh%0Aflutter+--no-version-check+analyze+--no-pub%0A%60%60%60%0A%0A%23%23+Steps+to+Reproduce%0A1.+...%0A2.+...%0A3.+...%0A%0A%23%23+Logs%0A_TypeError%3A+%28%230++++++MaterialFonts.updateInner+%28package%3Aflutter_tools%2Fsrc%2Fflutter_cache.dart%3A155%3A49%29%29%0A%60%60%60console%0A%230++++++MaterialFonts.updateInner+%28package%3Aflutter_tools%2Fsrc%2Fflutter_cache.dart%3A155%3A49%29%0A%231++++++CachedArtifact.update+%28package%3Aflutter_tools%2Fsrc%2Fcache.dart%3A959%3A11%29%0A%232++++++Cache.updateAll+%28package%3Aflutter_tools%2Fsrc%2Fcache.dart%3A818%3A24%29%0A%3Casynchronous+suspension%3E%0A%233++++++FlutterCommand._updateCacheAndRunPubGet+%28package%3Aflutter_tools%2Fsrc%2Frunner%2Fflutter_command.dart%3A2010%3A7%29%0A%3Casynchronous+suspension%3E%0A%234++++++FlutterCommand.verifyThenRunCommand+%28package%3Aflutter_tools%2Fsrc%2Frunner%2Fflutter_command.dart%3A1977%3A17%29%0A%3Casynchronous+suspension%3E%0A%235++++++FlutterCommand.run.%3Canonymous+closure%3E+%28package%3Aflutter_tools%2Fsrc%2Frunner%2Fflutter_command.dart%3A1663%3A27%29%0A%3Casynchronous+suspension%3E%0A%236++++++AppContext.run.%3Canonymous+closure%3E+%28package%3Aflutter_tools%2Fsrc%2Fbase%2Fcontext.dart%3A154%3A19%29%0A%3Casynchronous+suspension%3E%0A%237++++++CommandRunner.runCommand+%28package%3Aargs%2Fcommand_runner.dart%3A212%3A13%29%0A%3Casynchronous+suspension%3E%0A%238++++++FlutterCommandRunner.runCommand.%3Canonymous+closure%3E+%28package%3Aflutter_tools%2Fsrc%2Frunner%2Fflutter_command_runner.dart%3A496%3A9%29%0A%3Casynchronous+suspension%3E%0A%239++++++AppContext.run.%3Canonymous+closure%3E+%28package%3Aflutter_tools%2Fsrc%2Fbase%2Fcontext.dart%3A154%3A19%29%0A%3Casynchronous+suspension%3E%0A%2310+++++FlutterCommandRunner.runCommand+%28package%3Aflutter_tools%2Fsrc%2Frunner%2Fflutter_command_runner.dart%3A431%3A5%29%0A%3Casynchronous+suspension%3E%0A%2311+++++FlutterCommandRunner.run.%3Canonymous+closure%3E+%28package%3Aflutter_tools%2Fsrc%2Frunner%2Fflutter_command_runner.dart%3A307%3A33%29%0A%3Casynchronous+suspension%3E%0A%2312+++++run.%3Canonymous+closure%3E.%3Canonymous+closure%3E+%28package%3Aflutter_tools%2Frunner.dart%3A104%3A11%29%0A%3Casynchronous+suspension%3E%0A%2313+++++AppContext.run.%3Canonymous+closure%3E+%28package%3Aflutter_tools%2Fsrc%2Fbase%2Fcontext.dart%3A154%3A19%29%0A%60%60%60%0A%60%60%60console%0A%5B%21%5D+Flutter+%28Channel+stable%2C+3.47.5%2C+on+Microsoft+Windows+%5B%E7%89%88%E6%9C%AC+10.0.19044.3086%5D%2C+locale+zh-CN%29+%5B472ms%5D%0A++++%E2%80%A2+Flutter+version+3.47.5+on+channel+stable+at+C%3A%5CUsers%5Cluoyi%5CAppData%5CLocal%5CTemp%5Cflutter-example-api-fix-20261030%0A++++%21+Warning%3A+%60flutter%60+on+your+path+resolves+to+D%3A%5Capp%5Cfvm%5Cversions%5Cstable%5Cbin%5Cflutter%2C+which+is+not+inside+your+current+Flutter+SDK+checkout+at+C%3A%5CUsers%5Cluoyi%5CAppData%5CLocal%5CTemp%5Cflutter-example-api-fix-20261030.+Consider+adding+C%3A%5CUsers%5Cluoyi%5CAppData%5CLocal%5CTemp%5Cflutter-example-api-fix-20261030%5Cbin+to+the+front+of+your+path.%0A++++%21+Warning%3A+%60dart%60+on+your+path+resolves+to+D%3A%5Capp%5Cfvm%5Cversions%5Cstable%5Cbin%5Cdart%2C+which+is+not+inside+your+current+Flutter+SDK+checkout+at+C%3A%5CUsers%5Cluoyi%5CAppData%5CLocal%5CTemp%5Cflutter-example-api-fix-20261030.+Consider+adding+C%3A%5CUsers%5Cluoyi%5CAppData%5CLocal%5CTemp%5Cflutter-example-api-fix-20261030%5Cbin+to+the+front+of+your+path.%0A++++%E2%80%A2+Upstream+repository+https%3A%2F%2Fgithub.com%2Fflutter%2Fflutter.git%0A++++%E2%80%A2+Framework+revision+6a19cca564+%28%29%2C+2026-09-17+14%3A13%3A22+-0400%0A++++%E2%80%A2+Engine+revision+af7e796e16%0A++++%E2%80%A2+Dart+version+3.13.4%0A++++%E2%80%A2+DevTools+version+2.60.0%0A++++%E2%80%A2+Feature+flags%3A+enable-web%2C+enable-linux-desktop%2C+enable-macos-desktop%2C+enable-windows-desktop%2C+enable-android%2C+enable-ios%2C+cli-animations%2C+enable-native-assets%2C+enable-record-use%2C+enable-swift-package-manager%2C+omit-legacy-version-file%2C+enable-lldb-debugging%2C+enable-uiscene-migration%0A++++%E2%80%A2+If+those+were+intentional%2C+you+can+disregard+the+above+warnings%3B+however+it+is+recommended+to+use+%22git%22+directly+to+perform+update+checks+and+upgrades.%0A%0A%5B%E2%9C%93%5D+Windows+Version+%28Windows+10%2C+21H2%2C+2009%29+%5B23.1s%5D%0A%0A%5B%E2%9C%93%5D+Android+toolchain+-+develop+for+Android+devices+%28Android+SDK+version+37.0.0%29+%5B1%2C390ms%5D%0A++++%E2%80%A2+Android+SDK+at+D%3A%5Capp%5CAndroidStudio%5CAndroid%5CSDK%0A++++%E2%80%A2+Emulator+version+37.1.11.0+%28build_id+15917651%29+%28CL%3AN%2FA%29%0A++++%E2%80%A2+Platform+android-37.0%2C+build-tools+37.0.0%0A++++%E2%80%A2+Java+binary+at%3A+C%3A%5CProgram+Files%5CCommon+Files%5COracle%5CJava%5Cjavapath%5Cjava.exe%0A++++++This+JDK+was+found+in+the+system+PATH.%0A++++++To+manually+set+the+JDK+path%2C+use%3A+%60flutter+config+--jdk-dir%3D%22path%2Fto%2Fjdk%22%60.%0A++++%E2%80%A2+Java+version+Java%28TM%29+SE+Runtime+Environment+%28build+17.0.11%2B7-LTS-207%29%0D%0A++++%E2%80%A2+All+Android+licenses+accepted.%0A%0A%5B%E2%9C%97%5D+Chrome+-+develop+for+the+web+%28Cannot+find+Chrome+executable+at+.%5CGoogle%5CChrome%5CApplication%5Cchrome.exe%29+%5B20ms%5D%0A++++%21+Cannot+find+Chrome.+Try+setting+CHROME_EXECUTABLE+to+a+Chrome+executable.%0A%0A%5B%E2%98%A0%5D+Visual+Studio+-+develop+Windows+apps+%28the+doctor+check+crashed%29%0A++++%E2%9C%97+Due+to+an+error%2C+the+doctor+check+did+not+complete.+If+the+error+message+below+is+not+helpful%2C+please+let+us+know+about+this+issue+at+https%3A%2F%2Fgithub.com%2Fflutter%2Fflutter%2Fissues.%0A++++%E2%9C%97+Error%3A+%25PROGRAMFILES%28X86%29%25+environment+variable+not+found.%0A++++%E2%80%A2+%230++++++throwToolExit+%28package%3Aflutter_tools%2Fsrc%2Fbase%2Fcommon.dart%3A34%3A3%29%0A++++++%231++++++VisualStudio._vswherePath+%28package%3Aflutter_tools%2Fsrc%2Fwindows%2Fvisual_studio.dart%3A264%3A7%29%0A++++++%232++++++VisualStudio._visualStudioDetails+%28package%3Aflutter_tools%2Fsrc%2Fwindows%2Fvisual_studio.dart%3A355%3A9%29%0A++++++%233++++++VisualStudio._bestVisualStudioDetails.%3Canonymous+closure%3E+%28package%3Aflutter_tools%2Fsrc%2Fwindows%2Fvisual_studio.dart%3A445%3A40%29%0A++++++%234++++++VisualStudio._bestVisualStudioDetails+%28package%3Aflutter_tools%2Fsrc%2Fwindows%2Fvisual_studio.dart%3A462%3A4%29%0A++++++%235++++++VisualStudio._bestVisualStudioDetails+%28package%3Aflutter_tools%2Fsrc%2Fwindows%2Fvisual_studio.dart%29%0A++++++%236++++++VisualStudio.isInstalled+%28package%3Aflutter_tools%2Fsrc%2Fwindows%2Fvisual_studio.dart%3A46%3A27%29%0A++++++%237++++++VisualStudioValidator.validateImpl+%28package%3Aflutter_tools%2Fsrc%2Fwindows%2Fvisual_studio_validator.dart%3A27%3A23%29%0A++++++%238++++++DoctorValidator.validate+%28package%3Aflutter_tools%2Fsrc%2Fdoctor_validator.dart%3A58%3A43%29%0A++++++%239++++++Doctor.startValidatorTasks.%3Canonymous+closure%3E+%28package%3Aflutter_tools%2Fsrc%2Fdoctor.dart%3A204%3A72%29%0A++++++%2310+++++asyncGuard.%3Canonymous+closure%3E+%28package%3Aflutter_tools%2Fsrc%2Fbase%2Fasync_guard.dart%3A108%3A32%29%0A++++++%2311+++++_rootRun+%28dart%3Aasync%2Fzone_root.dart%3A35%3A13%29%0A++++++%2312+++++_CustomZone.run+%28dart%3Aasync%2Fzone.dart%3A810%3A35%29%0A++++++%2313+++++_runZoned+%28dart%3Aasync%2Fzone_api.dart%3A165%3A6%29%0A++++++%2314+++++runZonedGuarded+%28dart%3Aasync%2Fzone_api.dart%3A151%3A12%29%0A++++++%2315+++++asyncGuard+%28package%3Aflutter_tools%2Fsrc%2Fbase%2Fasync_guard.dart%3A106%3A3%29%0A++++++%2316+++++Doctor.startValidatorTasks+%28package%3Aflutter_tools%2Fsrc%2Fdoctor.dart%3A194%3A9%29%0A++++++%2317+++++DoctorText._validatorTasks+%28package%3Aflutter_tools%2Fsrc%2Fdoctor.dart%3A834%3A60%29%0A++++++%2318+++++DoctorText._validatorTasks+%28package%3Aflutter_tools%2Fsrc%2Fdoctor.dart%29%0A++++++%2319+++++DoctorText._runDiagnosis+%28package%3Aflutter_tools%2Fsrc%2Fdoctor.dart%3A839%3A32%29%0A++++++%2320+++++DoctorText.text+%28package%3Aflutter_tools%2Fsrc%2Fdoctor.dart%3A830%3A36%29%0A++++++%2321+++++DoctorText.text+%28package%3Aflutter_tools%2Fsrc%2Fdoctor.dart%29%0A++++++%2322+++++_createLocalCrashReport+%28package%3Aflutter_tools%2Frunner.dart%3A329%3A51%29%0A++++++%2323+++++_handleToolErrorImpl+%28package%3Aflutter_tools%2Frunner.dart%3A290%3A31%29%0A++++++%3Casynchronous+suspension%3E%0A++++++%2324+++++AppContext.run.%3Canonymous+closure%3E+%28package%3Aflutter_tools%2Fsrc%2Fbase%2Fcontext.dart%3A154%3A19%29%0A++++++%3Casynchronous+suspension%3E%0A++++++%2325+++++main+%28package%3Aflutter_tools%2Fexecutable.dart%3A103%3A3%29%0A++++++%3Casynchronous+suspension%3E%0A%0A%0A%5B%E2%9C%93%5D+Connected+device+%281+available%29+%5B429ms%5D%0A++++%E2%80%A2+Windows+%28desktop%29+%E2%80%A2+windows+%E2%80%A2+windows-x64+%E2%80%A2+Microsoft+Windows+%5B%E7%89%88%E6%9C%AC+10.0.19044.3086%5D%0A%0A%5B%21%5D+Network+resources+%5B21.3s%5D%0A++++%E2%9C%97+A+network+error+occurred+while+checking+%22https%3A%2F%2Fmaven.google.com%2F%22%3A+%E4%BF%A1%E5%8F%B7%E7%81%AF%E8%B6%85%E6%97%B6%E6%97%B6%E9%97%B4%E5%B7%B2%E5%88%B0%0A%0A%21+Doctor+found+issues+in+4+categories.%0A%0A%60%60%60%0A%0A%23%23+Flutter+Application+Metadata%0A%2A%2AType%2A%2A%3A+package%0A%2A%2AVersion%2A%2A%3A+0.0.1%0A%2A%2AMaterial%2A%2A%3A+false%0A%2A%2AAndroid+X%2A%2A%3A+false%0A%2A%2AModule%2A%2A%3A+false%0A%2A%2APlugin%2A%2A%3A+false%0A%2A%2AAndroid+package%2A%2A%3A+null%0A%2A%2AiOS+bundle+identifier%2A%2A%3A+null%0A%2A%2ACreation+channel%2A%2A%3A+stable%0A%2A%2ACreation+framework+version%2A%2A%3A+6a19cca56475dbfba1478ee68d7bd0c2ef891da1%0A%0A&labels=tool%2Csevere%3A+crash

```

### --no-version-check analyze --no-pub

工作目录：`D:/project/flutter/flutter_base`；退出码：`1`。

```text
Flutter failed to list directory at "C:\Users\luoyi\AppData\Local\Temp\flutter-example-api-fix-20261030\examples". The file or directory could not be found.
PathNotFoundException: Directory listing failed, path = 'C:\Users\luoyi\AppData\Local\Temp\flutter-example-api-fix-20261030\examples\*' (OS Error: 系统找不到指定的路径。, errno = 3)
This can sometimes happen if the file was deleted or moved while the tool was running. Try running "flutter clean" and try again.
```

### --no-version-check analyze --no-pub

工作目录：`D:/project/flutter/flutter_base`；退出码：`255`。

```text
Unhandled exception:
FileSystemException: Exists failed, path = 'C:\Users\luoyi\AppData\Local\.dartServer\.instrumentation' (OS Error: 拒绝访问。, errno = 5)
#0      _Directory.existsSync (dart:io/directory_impl.dart:97)
#1      _Directory.createSync (dart:io/directory_impl.dart:129)
#2      PhysicalResourceProvider.getStateLocation (package:analyzer/file_system/physical_file_system.dart:80)
#3      Driver._readUuid (package:analysis_server/src/server/driver.dart:766)
#4      Driver.start (package:analysis_server/src/server/driver.dart:336)
<asynchronous suspension>
Analyzing flutter_base...                                       
analysis server exited with code 255 and output:
[stderr] Unhandled exception:
[stderr] FileSystemException: Exists failed, path = 'C:\Users\luoyi\AppData\Local\.dartServer\.instrumentation' (OS Error: 拒绝访问。, errno = 5)
[stderr] #0      _Directory.existsSync (dart:io/directory_impl.dart:97)
[stderr] #1      _Directory.createSync (dart:io/directory_impl.dart:129)
[stderr] #2      PhysicalResourceProvider.getStateLocation (package:analyzer/file_system/physical_file_system.dart:80)
[stderr] #3      Driver._readUuid (package:analysis_server/src/server/driver.dart:766)
[stderr] #4      Driver.start (package:analysis_server/src/server/driver.dart:336)
[stderr] <asynchronous suspension>
```

### --no-version-check analyze --no-pub

工作目录：`D:/project/flutter/flutter_base`；退出码：`1`。

```text
Analyzing flutter_base...                                       

   info - Import of a library in the 'lib/src' directory of another package. Try importing a public library that exports this library, or removing the import - example\lib\src\pages\custom_gestures.dart:3:8 - implementation_imports

1 issue found. (ran in 40.4s)
```

### --no-version-check test test/flutter_base/sdk/binding/resampling_test.dart --no-pub --concurrency=1 --reporter=expanded

工作目录：`D:/project/flutter/flutter_base`；退出码：`1`。

```text
%PROGRAMFILES(X86)% environment variable not found.
```

## 最终验收输出原文

以下完整记录最终通过的 stdout/stderr 与退出码。

### flutter analyze --no-pub

工作目录：`D:/project/flutter/flutter_base`；退出码：`0`。

```text
Analyzing flutter_base...                                       
No issues found! (ran in 43.1s)
```

### flutter test test/flutter_base/sdk/binding/resampling_test.dart --no-pub --concurrency=1 --reporter=expanded

工作目录：`D:/project/flutter/flutter_base`；退出码：`0`。

```text
00:00 +0: loading D:/project/flutter/flutter_base/test/flutter_base/sdk/binding/resampling_test.dart
00:00 +0: 已有其他绑定时拒绝替换，原实例继续可用
00:00 +1: 采样算法 相邻样本插值，外推限于半个周期，时间戳不会伪装成更远的预测
00:00 +2: 采样算法 1ms 异常周期不用速度外推
00:00 +3: 采样算法 25ms 异常周期不用速度外推
00:00 +4: 采样算法 自适应尾随保留原周期策略和 -5ms 下限
00:00 +5: 采样算法 外推过冲不产生反向回收，真实反向超过 2px 后恢复
00:00 +6: 采样算法 外推上限不超过 8ms，停顿后不继续累积移动
00:00 +7: 采样算法 相同时间戳替换坐标，倒序输入不破坏采样
00:00 +8: 触摸生命周期 按下即时分发，短手势抬起前结清移动，结束后不再输出
00:00 +9: 触摸生命周期 逐帧合并输入，采样移动保留设备、压力与平台属性
00:00 +10: 触摸生命周期 同设备多指独立跟踪并按同一时刻输出
00:00 +11: 触摸生命周期 框架仅带 pointer 的取消能清理真实设备，取消后没有补尾移动
00:00 +12: 触摸生命周期 绑定锁定时暂停帧采样，解锁后恢复，重置取消所有帧
00:00 +13: 触摸生命周期 纯预测帧标记为合成输入，抬起不反向偿还外推过冲
00:00 +14: 触摸生命周期 让位时结清真实输入并停止后续采样，按钮变化即时分发
00:00 +15: 官方手势接入 全局采样进入官方 GestureDetector，按帧更新且抬起完整结束 (variant: TargetPlatform.android)
00:00 +16: 官方手势接入 按下和点击无需等待采样帧 (variant: TargetPlatform.android)
00:00 +17: 官方手势接入 ElEvent 接收全局采样事件，不再进行第二次输出采样 (variant: TargetPlatform.android)
00:00 +18: 官方手势接入 官方 ListView 正常滚动并保留甩出惯性 (variant: TargetPlatform.android)
00:01 +19: 官方手势接入 原始输入停顿后抬起不会因迟到采样重新产生甩动 (variant: TargetPlatform.android)
00:01 +20: 官方手势接入 官方多指缩放保持对称中心与旋转方向 (variant: TargetPlatform.android)
00:01 +21: 官方手势接入 TargetPlatform.windows 的触摸输入直接分发 (variant: TargetPlatform.windows)
00:01 +22: 官方手势接入 TargetPlatform.iOS 的触摸输入直接分发 (variant: TargetPlatform.iOS)
00:01 +23: 官方手势接入 TargetPlatform.macOS 的触摸输入直接分发 (variant: TargetPlatform.macOS)
00:01 +24: 官方手势接入 TargetPlatform.linux 的触摸输入直接分发 (variant: TargetPlatform.linux)
00:01 +25: 官方手势接入 Android 的 PointerDeviceKind.mouse 输入直接分发 (variant: TargetPlatform.android)
00:01 +26: 官方手势接入 Android 的 PointerDeviceKind.stylus 输入直接分发 (variant: TargetPlatform.android)
00:01 +27: 官方手势接入 框架 cancelPointer 正确结束采样并保留取消回调 (variant: TargetPlatform.android)
00:01 +28: 依赖边界 可选输入模块仅依赖 Flutter SDK 和自身目录
00:01 +29: 依赖边界 主入口只导出可选绑定，事件模块不引用输入模块
00:01 +30: All tests passed!
```

### flutter test test/flutter/hooks --no-pub --concurrency=1 --reporter=expanded

工作目录：`D:/project/flutter/flutter_base`；退出码：`0`。

```text
00:00 +0: loading D:/project/flutter/flutter_base/test/flutter/hooks/add_listener_test.dart
00:00 +0: D:/project/flutter/flutter_base/test/flutter/hooks/add_listener_test.dart: useAddListener 同一对象切换回调并在卸载时解绑
00:00 +1: loading D:/project/flutter/flutter_base/test/flutter/hooks/animation_status_listener_test.dart
00:01 +1: D:/project/flutter/flutter_base/test/flutter/hooks/animation_status_listener_test.dart: 动画状态监听支持同一控制器更换回调
00:01 +2: loading D:/project/flutter/flutter_base/test/flutter/hooks/curve_animation_test.dart
00:02 +2: D:/project/flutter/flutter_base/test/flutter/hooks/curve_animation_test.dart: 曲线 hook 保留实例并响应曲线变化
00:02 +3: loading D:/project/flutter/flutter_base/test/flutter/hooks/did_update_test.dart
00:03 +3: D:/project/flutter/flutter_base/test/flutter/hooks/did_update_test.dart: useDidUpdate 首次更新传递初始 widget
00:03 +4: loading D:/project/flutter/flutter_base/test/flutter/hooks/hook_state_test.dart
00:04 +4: D:/project/flutter/flutter_base/test/flutter/hooks/hook_state_test.dart: useHookState 按 keys 重建并释放旧状态
00:05 +5: loading D:/project/flutter/flutter_base/test/flutter/hooks/simple_hooks_test.dart
00:05 +5: D:/project/flutter/flutter_base/test/flutter/hooks/simple_hooks_test.dart: useObs 保留实例并在卸载时释放
00:06 +6: D:/project/flutter/flutter_base/test/flutter/hooks/simple_hooks_test.dart: useMounted 只执行一次，更新 effect 按 keys 清理
00:06 +7: D:/project/flutter/flutter_base/test/flutter/hooks/simple_hooks_test.dart: useInterval 卸载时取消定时器
00:06 +8: loading D:/project/flutter/flutter_base/test/flutter/hooks/watch_test.dart
00:07 +8: D:/project/flutter/flutter_base/test/flutter/hooks/watch_test.dart: useWatch 切换观察对象后以新对象当前值作为旧值
00:07 +9: All tests passed!
```

### flutter test test/flutter/model_value/model_value_test.dart --no-pub --concurrency=1 --reporter=expanded

工作目录：`D:/project/flutter/flutter_base`；退出码：`0`。

```text
00:00 +0: loading D:/project/flutter/flutter_base/test/flutter/model_value/model_value_test.dart
00:00 +0: ElModelValue value 回灌只刷新界面，用户操作才触发 onChanged
00:01 +1: ElModelValue modelValue: 点击开关会同步到 ValueNotifier
00:01 +2: ElModelValue modelValue: 外部更新 ValueNotifier 时界面跟随
00:01 +3: ElModelValue value + onChanged: 受控方式随外部状态变化
00:01 +4: ElModelValue 多个子组件绑定同一 modelValue 时保持同步
00:01 +5: ElModelValue modelValue 与 onChanged 同时使用时内外更新都只通知一次
00:01 +6: 与 HookWidget / useState 组合 同一路 useState 下 modelValue 与 value+onChanged 两路开关联动
00:01 +7: All tests passed!
```

### flutter analyze --no-pub

工作目录：`D:/project/flutter/flutter_base/example`；退出码：`0`。

```text
Analyzing example...                                            
No issues found! (ran in 20.4s)
```

### flutter test test/custom_gestures_page_test.dart --no-pub --concurrency=1 --reporter=expanded

工作目录：`D:/project/flutter/flutter_base/example`；退出码：`0`。

```text
00:00 +0: loading D:/project/flutter/flutter_base/example/test/custom_gestures_page_test.dart
00:00 +0: 元素范围由页面判断，范围内移动可点击而移出后主动取消
00:01 +1: 基础操作区直接显示单击、双击、三击和长按结果
00:01 +2: 鼠标右键、中键、前进和后退按钮分别计数
00:02 +3: 延迟单击保留识别窗口，双击取消待发单击
00:02 +4: El 子点击向父冒泡，开关只截断 El 传播
00:02 +5: El 内层点击获胜，外层官方 Tap 不触发
00:02 +6: 官方内层点击获胜，外层 El 不触发
00:03 +7: ListView 赢得拖拽后，行点击取消且列表真实滚动
00:03 +8: 重置清空计数并释放待发单击，下一次手势重新计数
00:03 +9: 首页自定义手势导航打开可操作页面
00:04 +10: 窄屏与放大文字下所有测试区可访问且没有布局溢出
00:04 +11: 窄屏可直接打开事件记录并查看刚才的点击
00:04 +12: 保存自定义手势测试页桌面预览
00:04 +12 ~1: All tests passed!
```

## 修改范围复核

仅修改 3 个获准页面、resampling_test.dart、7 个 hooks 测试文件和 model_value_test.dart；已写入本报告。.codex/example-fix-last.md 写入失败，详见下文。

- 对 8 个 import 清理文件逐字比对：变化严格等于删除 flutter_hooks import 一行。
- 对 4 个迁移文件搜索 ElPressGestureRecognizer / ElPressGestureCallback / ElPressGestureDetails / ElGestureCancelReason / ElEventView / ElEventCallback / context.hasTap / context.hasHover：无残留（rg 退出码 1，输出为空）。
- 397 个受保护已有文件的 SHA-256 比对一致；未修改 lib/**、test/my_ui、pubspec 或锁文件。
- 未修改 example 其他文件，未添加额外测试文件，未执行仓库 git 或 commit。测试生成的缓存位于既有 build/.dart_tool 与临时运行目录。

## 最终汇报文件写入受阻

全部代码迁移和上述验收已完成，但最后一个输出文件尚未落盘。当前沙箱将 D:/project/flutter/flutter_base/.codex 配置为只读，且不允许权限升级。Node 文件写入返回原文：

```text
EPERM: operation not permitted, open 'D:\project\flutter\flutter_base\.codex\example-fix-last.md'
```

需要环境允许写入该文件后才能完成这个指定输出路径；没有尝试绕过目录权限。预定写入 .codex/example-fix-last.md 的最终汇报完整内容保留如下：

```markdown
# example 与旧测试 API 迁移最终汇报

结果：全部完成。全仓 analyze 与 example analyze 均为 **0 error / 0 warning / 0 info**。

| 实际验收 | 结果 |
|---|---|
| 根目录 flutter analyze --no-pub | No issues found，退出码 0 |
| flutter test test/flutter_base/sdk/binding/resampling_test.dart | 30 通过 |
| flutter test test/flutter/hooks | 9 通过 |
| flutter test test/flutter/model_value/model_value_test.dart | 7 通过 |
| example 目录 flutter analyze --no-pub | No issues found，退出码 0 |
| example 目录 flutter test test/custom_gestures_page_test.dart | 12 通过，1 默认截图预览跳过 |

测试均追加 --no-pub --concurrency=1 --reporter=expanded；使用原 SDK 的 Flutter CLI 和临时可写运行缓存，完整命令、环境与原始输出见下述详细报告。

已完成：

- 自定义手势页迁为 PressRecognizer.callbacks[ElEventPhase.*]，保留全部手势、父子冒泡、越界取消、重置和释放行为。
- 两个 view 页面使用 ElStyle.bgColor，base 页通过 ElView.of(context) 读取 hasTap/hasHover。
- resampling 使用 ElEventDetails / ElView，依赖断言遍历实际的新事件目录，所有断言语义不变。
- 7 个 hooks 文件与 model_value_test.dart 严格只删除各自冗余 flutter_hooks import。

明确例外：example/lib/src/pages/custom_gestures.dart:3 有一处带原因注释的 implementation_imports 单行豁免；独立识别器没有公共导出，为保留该页演示行为而直接导入内核。没有修改全局分析配置。

范围复核：397 个受保护已有文件哈希一致；未修改 lib/**、my_ui、test/my_ui、pubspec 或锁文件，未对工作仓库执行 git 或 commit。example 有独立 pubspec，通过 path: ../ 依赖根包。

[逐项 file:line 前后对照与验收输出原文](../.claude/plan/example-api-fix-report.md)
```
