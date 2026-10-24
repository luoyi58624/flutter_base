# el 仓库开发指南

Dart / Flutter workspace 单仓库；根 `pubspec.yaml` 的 `workspace` 清单是成员包的权威来源。

## 代码规范

- 公开类必须添加 El 前缀，例如：ElApp，其他设计语言则添加自己的前缀，例如：WinApp、DocsApp
- 私有类正常编写，不需要任何前缀，例如：_ButtonState，禁止 _ElButtonState
- 编写 Render 类，应该写：ElRenderBox，禁止写：RenderElBox
- 文件命名禁止添加前缀，应该写：xxxx.dart，禁止写：el_xxxx.dart
- example 示例、test 测试避免写 const，减少诊断回归错误
- 尽可能使用 dot 点简写，但注意 copyWith 无法使用 dot 点简写
- 公开 api 尽可能写 `///` 文档注释（简洁不废话），关键的私有 api 也要写注释
- 尽可能使用 HookWidget 编写代码，代码保证简洁
- Git 提交信息必须使用中文；Conventional Commit 类型、作用域和代码标识可以保留英文
- 写完功能、修复 bug 跑自己的局部测试文件，减少测试时间，牵扯大量模块需要跑全量测试检查回归
- 运行代码生成直接执行 dart run build_runner build

## 测试与机器占用红线

- **严厉禁止编写或运行前台窗口测试**：不得写、不得跑会弹出真实窗口、抢占前台焦点或依赖人工操作的应用测试——包括 `flutter run`、`flutter drive`、以 Windows/真机设备运行的 `integration_test`、依赖截图比对的真机脚本。验证一律走无头 `flutter test`（flutter_tester），不弹窗、不抢焦点。
- **严厉禁止占用用户操作电脑**：不得为了验证而长时间吃满 CPU/内存（全量 benchmark、批量重复跑、无人值守长跑），不得与用户正在操作的会话抢资源；重负载验证先说明代价、取得同意，并放后台 + 降优先级 + 设超时兜底。
- 用户正在运行的应用实例（element_docs / flutter run 等）不得擅自 kill、重启、附加调试或注入代码；先报告现场与结论，等用户决定。
