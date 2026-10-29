# el_ui → flutter_base 全量迁移记录

> 状态：**完成**。`dart analyze lib` → `No issues found!`
> 分支 `flutter`，最终提交 `8479e85 feat(ui): 全量迁移 el_ui 到 lib/src/ui`（未 push）。
> 上游：`D:\project\my-project\el` @ `new_view` / `fcbe48439`，源目录 `packages/el_ui/lib/src`。

## 1. 背景

`flutter_base` 在 `441b979 删除 view、event` 里删掉了 `lib/src/ui/cores/view/`、`lib/src/ui/cores/event/`（11,150 行），
但 `lib/ui.dart` 仍 export 它们、`components/list_tile` 仍在用它们，整包编译不过。

迁移范围分两步扩大：

1. 最初：只搬 view / event / selection 内核（T1 脚手架 `1a3a5fd`）。
2. 最终：用户决定 **整个 el_ui 全量迁移**（`lib/src` 下 cores / components / views / widgets / testing 全部）。

## 2. 目录映射

| el_ui 侧 | flutter_base 侧 |
| --- | --- |
| `lib/src/cores/**` | `lib/src/ui/cores/**` |
| `lib/src/components/**` | `lib/src/ui/components/**` |
| `lib/src/views/**` | `lib/src/ui/views/**` |
| `lib/src/widgets/**` | `lib/src/ui/widgets/**` |
| `lib/src/testing/**` | `lib/src/ui/testing/**` |
| `lib/el_ui.dart` | `lib/ui.dart`（公共入口 barrel，247 行 export） |

包名映射（全库字符串替换）：

| 上游 | flutter_base |
| --- | --- |
| `package:el_ui/src/` | `package:flutter_base/src/ui/` |
| `package:el_ui/el_ui.dart` | `package:flutter_base/ui.dart` |
| `package:el_flutter/el_flutter.dart` | `package:flutter_base/flutter.dart` |
| `package:el_dart/el_dart.dart` | `package:flutter_base/dart.dart` |
| `package:el_dart/ext.dart` | `package:collection/collection.dart` |
| `$elAbsent`（生成代码哨兵） | `$absent` |
| 相对 `'../.../el_ui.dart'` | `'package:flutter_base/ui.dart'` |

## 3. 执行方式

- **机械搬运**用 Lead 写的 `PowerShell 7` 脚本 `.migrate-all3.ps1`（robocopy `/E /IS` 强制覆盖 → 目录合并 → 全量 import 映射 → 重建 `lib/ui.dart`），
  理由：确定性、秒级、不烧 token；语义判断留给 codex/GPT。
- **代码修正**交给 `codex exec`（`gpt-6.1-sol`，`model_reasoning_effort=xhigh`，`service_tier=priority`，`-s danger-full-access`），
  任务走 stdin（`.codex-task-*.txt`），后台 `.bat` + `Start-Process -WindowStyle Hidden`，日志 `.codex-log-*.txt`。

## 4. 两个踩坑（重要）

1. **相对 import 错位**：`el_ui/lib/src/X` → `flutter_base/lib/src/ui/X` 等于整体插进一级目录，
   所有 `'../../el_ui.dart'` 相对引用全部失效 → 288 文件级联报 **8,482 error**。
   修法：正则改写成 `package:flutter_base/ui.dart`，并把 `el_ui.dart` 的完整 export 清单重写进 `lib/ui.dart`。
2. **中文注释被写坏**：用 Windows PowerShell 5.1 + `Set-Content` 写回 UTF-8 无 BOM 文件，把中文写成 `�`（76 个文件损坏）。
   修法：`git checkout -- lib; git clean -fdq lib` 回滚，改用 **PowerShell 7 + `[IO.File]::ReadAllText/WriteAllText` + `UTF8Encoding($false)`** 重跑。
   **教训：写脚本一律用 pwsh 7 + .NET UTF-8 API，不要用 `powershell` + `Set-Content`。**

## 5. 代码收敛点

- `components/list_tile`：旧自研 API（`Builder` + `context.hasTap`/`hasHover`、`ElEventView` 直接挂载）不符合 el 版语义，
  改为 `ElStyle` 的 `onHover` / `onTap` **状态变体**，并把 `ElEventView(event: ...)` 挂到 `ElView(event: ...)`。
  注意：`ElStyle` 的背景字段是 **`bgColor`**，`color` 是文字色。
- `Equatable` 从 `package:equatable/equatable.dart` 导入（`package:flutter_base/dart.dart` 不导出它）。
- `el` 单例（`const el = El._()`，`lib/src/dart/commons/index.dart`）使用处补 `package:flutter_base/dart.dart` 导入。
- `lib/ui.dart` 删掉重复的 `library;`。
- 新增直接依赖：`url_launcher: ^6.3.3`（widgets/link）、`characters: 1.4.1`（cores/editable），用 `dart pub add` 添加。

## 6. 生成代码

`.g.dart`（`view/style/style.g.dart`、`view/semantics/semantics.g.dart`、`view/event/event.g.dart`）**沿用上游产物**，
只把哨兵 `$elAbsent` 替换成 `$absent`；未用 `flutter_base|model` 重跑 build_runner
（上游 `el_gen|model` 与本地生成器族不等价，重生成风险大）。
如需重生成，先确认 `build.yaml` 的 `generate_for` / `build_extensions` 覆盖到 `lib/src/ui/cores/view/**`。

## 7. 已知遗留

- `test/` 侧仍是旧导入路径（`package:flutter_base/src/ui/cores/event/index.dart` 等 6 类，约 40 个文件），本次未迁测试。
- 迁移只做静态分析级正确（`dart analyze lib` 干净），**未做运行期验证**（未见启动示例 app / 未跑 widget test）。
- 上游 `example/` 未迁。

## 8. 验证

```powershell
cd D:\project\flutter\flutter_base
dart analyze lib     # => No issues found!
git log --oneline -3
```
