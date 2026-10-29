# el_ui → flutter_base 视图 / 事件 / 选择内核迁移（脚手架）

> 状态：**脚手架完成**（T1）。`dart analyze lib` → 5 error / 0 warning / **0 未解析 import**。
> 剩余 5 个 error 全部来自 `lib/src/ui/components/list_tile/` 的语义收敛（见 §7），交给 T2/T3。
> 分支 `flutter`，基线 `441b979 删除 view、event`。

## 1. 背景与目标

`flutter_base` 在 `441b979` 把 `lib/src/ui/cores/view/`、`lib/src/ui/cores/event/` 整棵删掉了，
但 `lib/ui.dart` 仍在 export 它们、`list_tile` 仍在用它们，包因此编译不过。
本次任务把 el 仓库（`D:\project\my-project\el\packages\el_ui\lib\src`）里已经成熟的
view / event / selection 内核**机械搬运**过来填补，只做「复制 + 改 import + 最小桩」：

- 不改业务逻辑，不改公开 API 名字，不顺手美化源码；
- 允许新增的只有：`index.dart` barrel、被裁掉的符号的桩文件、必要的门面文件；
- 不新增任何 pubspec 之外的依赖。

## 2. 命名空间映射

| el 侧 | flutter_base 侧 |
| --- | --- |
| `packages/el_ui/lib/src/cores/view/**` | `lib/src/ui/cores/view/**` |
| `packages/el_ui/lib/src/cores/selection/**` | `lib/src/ui/cores/selection/**` |
| `packages/el_ui/lib/src/cores/common/{bit_mask,benchmark_probe,layout_reference}.dart` | `lib/src/ui/cores/common/**` |
| `packages/el_ui/lib/src/cores/focus/**` | `lib/src/ui/cores/focus/**` |
| `packages/el_ui/lib/src/cores/scroll/**`（受限子集） | `lib/src/ui/cores/scroll/**` |
| `packages/el_ui/lib/src/views/menu/context_menu.dart`、`menu_overlay.dart` | `lib/src/ui/cores/menu/**` |
| `packages/el_ui/lib/src/views/button/button_view.dart` | `lib/src/ui/cores/button/button_view.dart` |
| `package:el_ui/src/cores/...` | `package:flutter_base/src/ui/cores/...` |
| `package:el_ui/src/views/menu/...` | `package:flutter_base/src/ui/cores/menu/...` |
| `package:el_ui/src/views/button/...` | `package:flutter_base/src/ui/cores/button/...` |
| `package:el_dart/el_dart.dart` | `package:flutter_base/dart.dart` |
| `package:el_dart/ext.dart` | `package:collection/collection.dart` |
| `package:el_dart/el_dart.dart` `show Equatable` | `package:equatable/equatable.dart` `show Equatable` |

> `flutter_base/dart.dart` **不导出 `Equatable`**（el 的 `el_dart.dart` 导出），
> 所以凡是用到 `Equatable` 且只写了 `show Equatable` 的地方（如 `style/resolved/resolved_style.dart`）
> 都要改指 `package:equatable/equatable.dart`。

## 3. 搬运清单（新增 73 个 .dart + 1 README）

| 目录 | 文件数 | 说明 |
| --- | --- | --- |
| `cores/view/render/` | 8 | `render_view.dart` + `_intrinsics` `box_insets` `box_painter` `content_sizes` `hit_bounds` `paint_controller` `scroll_cursor_freeze`（后 7 个是 part） |
| `cores/view/style/` | 22 | `style.dart` + `style.g.dart` + `damage` `dimension` `linear_gradient` `style_context`，子目录 `animation/`(4) `cascade/`(4) `inheritance/`(3) `internal/`(2) `resolved/`(2) `state/`(1) |
| `cores/view/event/` | 5 | `event.dart` + `event.g.dart` + `dispatcher` `press` `transform` |
| `cores/view/semantics/` | 4 | `semantics.dart` + `semantics.g.dart` + `render_semantics` `semantics_frame` |
| `cores/view/text/` | 2 | `text_engine` `text_style_adapter` |
| `cores/view/element/` | 1 | `view_element.dart` |
| `cores/view/`（根） | 2 | `view.dart` + 新增 `index.dart` |
| `cores/selection/` | 22 | `selection.dart` + `index.dart`(新增) + `README.md` + `box/`(4) + `common/`(12) + `docs/`(4) |
| `cores/common/` | 3 | `bit_mask` `benchmark_probe` `layout_reference` |
| `cores/focus/` | 2 | `focus_indicator` `focus_utils` |
| `cores/scroll/` | 5 | `scroll_state.dart`、`common/viewport/`(3)、`common/pointer/scroll_touch_gate.dart`、`common/render/scroll_viewport_base.dart`(桩，见 §5) |
| `cores/menu/` | 3 | `context_menu` `menu_overlay` + 新增 `global_context_menu.dart`(门面，见 §5) |
| `cores/button/` | 1 | `button_view.dart` |

`cores/selection` 的 `box/`、`common/`、`docs/` 是**完整搬运**，没有裁剪。

## 4. 刻意排除的文件（及其原因）

| 排除项 | 原因 |
| --- | --- |
| `el_ui/src/cores/view/provider.dart` | 它把 view 内核接到 scroll 引擎上，会连带拖进 `scroll_viewport_base.dart` 的 virtual/smooth 全家桶；本次任务范围不含 scroll 引擎，故留空，后续按需再接。 |
| `el_ui/src/cores/scroll/common/render/scroll_viewport_base.dart`（88,341 bytes） | 同上：它 `part` 了 virtual / smooth 滚动实现，搬过来即等于搬运整个滚动引擎。改为最小桩（§5）。 |
| `el_ui/src/cores/common/global.dart`、`models.dart`、`gutter.dart` | `global.dart` 是 el 的全局上下文菜单注册表（依赖 el 的 `el` 单例 + `ElBuildContext`），直接用会牵扯 el 的应用壳；`models.dart`/`gutter.dart` 与 view 内核无关。`global.dart` 的接口以最小门面替代（§5）。 |

## 5. 桩 / 裁剪 / 门面（逐处记录）

1. **`lib/src/ui/cores/menu/global_context_menu.dart`（新增门面）**
   - 内容：`ElViewExt on El`（`globalContextMenus` 表）+ `showContextMenu(...)`。
   - 裁剪：正文复制自 el `cores/common/global.dart`，只保留上下文菜单注册表与 `showContextMenu`；
     `showContextMenu` 在 flutter_base 里**没有 overlay 宿主**，实现为 `return null;` + `debugPrint` 告警。
   - 因由：`context_menu.dart` / `menu_overlay.dart` 的 import 从 `../../common/global.dart` 改指本文件，
     避免把 el 的 `ElBuildContext` / 应用壳拖进来。
   - 后续：谁接入 overlay 宿主，谁把 `showContextMenu` 换成真实实现（签名不变）。
2. **`lib/src/ui/cores/scroll/common/render/scroll_viewport_base.dart`（桩）**
   - 内容：`abstract interface class RenderScrollViewportBase implements ScrollViewport`，
     只声明 `ScrollPosition? get horizontalPosition;`、`AxisDirection get horizontalAxisDirection;`。
   - 裁剪：真实实现里的 virtual / smooth 滚动、`performLayout` 重排逻辑全部不要。
   - 因由：`selection/box/box_selection_view.dart:436-437` 只有

     ```dart
     viewport is RenderScrollViewportBase && viewport.horizontalPosition != null
     ```

     这种 is-类型提升；Dart 要求被测类型必须是声明类型（`ScrollViewport`）的子类型，
     所以桩必须 `implements ScrollViewport`（第一版没写，换来 `undefined_class` + 类型提升失败）。
   - 后续：接入真实滚动引擎时整文件替换，`box_selection_view.dart` 无需改动。
3. **`cores/view/index.dart` 用 `hide sameViewTextPayload`**
   - `view.dart:131` 的 `@internal bool sameViewTextPayload(...)` 经 barrel 泄露到 `lib/ui.dart`
     公开面，触发 `invalid_export_of_internal_element`×2。barrel 里 `export 'view.dart' hide sameViewTextPayload;` 解决；
     库内使用方（`render/render_view.dart:658`）走相对 import，不受影响。
4. **生成代码哨兵名改写**（不是桩，是必须的机械改写）
   - el 的生成器输出 `$elAbsent`（`event.g.dart` 152 处、`style.g.dart` 144 处、`semantics.g.dart` 4 处），
     flutter_base 的 `lib/src/dart/gen/sentinel.dart` 提供的是 `const $absent = _A();`，
     且 `lib/src/dart/gen/model_generator.dart:464/473` 生成的就是 `$absent`。
   - 处理：三份 `.g.dart` 里 `$elAbsent` → `$absent` 全量替换。三个 avid 文件已 import `package:flutter_base/dart.dart`（导出 sentinel），故名字可见。
   - 未 `dart run build_runner build` 重生成：el 的生成器全家桶与 flutter_base 的 `elModelBuilder` 不完全等价，重生成风险大于收益。

## 6. 入口与构建配置改动

- `lib/ui.dart`：

  ```dart
  export 'src/ui/components/list_tile/index.dart';
  export 'src/ui/cores/selection/index.dart';
  export 'src/ui/cores/view/index.dart';
  ```

  删掉了指向已不存在的 `cores/event/index.dart` 与旧 `cores/view/index.dart` 的两行。
- 新增 barrel：
  - `lib/src/ui/cores/view/index.dart` → `event/event.dart`、`semantics/semantics.dart`、`style/style.dart`、`view.dart`（hide 见 §5.3）。
  - `lib/src/ui/cores/selection/index.dart` → 选择内核公开面。
- `build.yaml`（**未做运行期验证**，见 §8）：`source_gen:combining_builder` 的 `build_extensions`
  第一条改为 `'^lib/src/ui/cores/view/{{}}.dart': 'lib/src/ui/cores/view/{{}}.g.dart'`，
  删掉旧的 `style/index.dart` 与 `event/{{}}.dart` 两条；`flutter_base|model` 的 `generate_for` 改为
  `lib/src/ui/cores/view/style/style.dart`、`lib/src/ui/cores/view/event/event.dart`、
  `lib/src/ui/cores/view/semantics/semantics.dart` + `test/generator/models/**`。

## 7. 当前 `dart analyze lib` 状态

`5 issues`，全部 `error`，全部在 `lib/src/ui/components/list_tile/`（**迁移前就坏**，不是搬运行引入的）：

| 位置 | 错误码 | 一句话原因 |
| --- | --- | --- |
| `group.dart:13:21` | `undefined_named_parameter` | `ElStyle(backgroundColor: ...)`：旧 flutter_base 的 `ElStyle` 有 `final Color? backgroundColor;`，el 的 `ElStyle`（`style/style.dart:19`）叫 `color` |
| `index.dart:28:21` | `undefined_method` | `ElEventView(...)` 是旧 `cores/view/event/index.dart` 的自研 widget，el_ui 全库无此符号 |
| `index.dart:38:13` | `undefined_named_parameter` | 同上 `backgroundColor` |
| `index.dart:38:38` | `undefined_getter` | `context.hasTap`：旧 `ElEventContextExt` 扩展方法 |
| `index.dart:40:27` | `undefined_getter` | `context.hasHover`：同上 |

收敛方向（给 T2/T3，仅供参考，不在本任务范围）：

- `backgroundColor` → el 的 `ElStyle.color`（或给 `ElStyle` 加别名参数，二选一，需产品决策）。
- `ElEventView(...)` → el 的事件接入方式是 `ElView(event: ElEvent(...))`（`view.dart:43` `final ElEvent? event;`），
  即事件挂在 view 上，而不是包一层专用 widget。
- `context.hasTap` / `context.hasHover` → 对应 el 的事件状态变体（`onHover` / `onPress` 等 style 变体），
  或由调用方自带状态。

## 8. Follow-up（未验证 / 未完成，交接给后续任务）

1. `build.yaml` 的 `generate_for` / `build_extensions` 改动**没有跑过 `build_runner`**，
   首次真正生成时需要确认产物路径就是 `lib/src/ui/cores/view/**/*.g.dart`。
2. `test/` 侧还有旧导入路径没迁（`lib/` 侧已自查干净）：

   | 旧路径 | 引用文件数 |
   | --- | --- |
   | `package:flutter_base/src/ui/cores/event/index.dart` | 17 |
   | `package:flutter_base/src/ui/cores/view/render/index.dart` | 7 |
   | `package:flutter_base/src/ui/cores/view/style/index.dart` | 7 |
   | `package:flutter_base/src/ui/cores/event/recognizers/index.dart` | 3 |
   | `package:flutter_base/src/ui/cores/event/event.dart` | 2 |
   | `package:flutter_base/src/ui/cores/view/index.dart` | 1（已可用 ✓） |

   说明：el 侧对应物是 `cores/view/event/event.dart`（没有 `cores/event/` 这一层）、
   `cores/view/style/style.dart`（没有 `style/index.dart`）、`cores/view/render/*.dart`（没有 `render/index.dart`，
   且其中 7 个是 part 文件，不能直接 export）；`recognizers/` 在 el 里不存在，按下/变换手势分别在 `event/press.dart`、`event/transform.dart`。
3. `cores/view/provider.dart` 与滚动引擎未搬入，`scroll_viewport_base.dart` 仍是桩（§5.2）。
4. `showContextMenu` 仍返回 `null`（§5.1）。

## 9. 环境约束（沿用 `.claude/CLAUDE.md`）

- 禁止 `flutter run` / 前台窗口测试 / 长时间吃满 CPU；验证一律用 `cd D:\project\flutter\flutter_base; dart analyze lib`。
- 不新增 pubspec 之外的依赖（现有已有 `equatable`、`collection`、`meta`、`logger`、`path` 等）。
- 提交信息中文，Conventional Commit 类型保留英文；只在 analyze 达标后提交一次；不建新分支、不 push。
