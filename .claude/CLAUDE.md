# flutter_base 开发指南

当前为单个 Flutter 包，`example/` 是独立示例应用；依赖与包边界以各自 `pubspec.yaml` 为准。通用规范沿用 el，旧项目的包路径和已移除 API 不直接套用。

## 代码规范

- 对外导出的类添加 El 前缀，例如：ElMobileTheme、ElButton；具体实现不从公共入口导出，内部使用普通命名，能私有的类保持私有
- 私有类正常编写，不需要任何前缀，例如：_ButtonState，禁止 _ElButtonState
- 编写 Render 类，应该写：ElRenderBox，禁止写：RenderElBox
- 文件命名禁止添加前缀，应该写：xxxx.dart，禁止写：el_xxxx.dart
- example 示例、test 测试避免写 const，减少诊断回归错误
- 尽可能使用 dot 简写；ElStyle.copyWith 等生成方法的参数是 Object?，无法推断目标类型时显式写构造类型，不能机械地对所有 copyWith 禁用简写
- 对外 API 使用中文 `///` 文档注释，一句话说明用途，关键决策解释原因；私有 API 只注释重要逻辑
- 尽可能使用 HookWidget 编写代码，代码保证简洁
- API 权威来源是当前源码；文档与源码冲突时以源码为准并同步修正文档，不引用旧项目才有的 API
- 外观优先由 ElStyle 声明，状态变体、级联、过渡和变量交给现有引擎承担；能由引擎处理的纯样式变化，不额外触发 Widget.build
- 样式确实决定 Widget 结构或行为，或现有引擎无法承接派生值时，才在 Widget 层订阅，并说明原因；主题变量在最近消费点通过 context.elTheme 或 ElView.of(context).getVar 按键读取，不提前订阅后层层下传
- 当前 ElStyle 没有 builder，ElView 没有 copyWith，不为照搬旧规范增设不存在的接口或兼容层；若以后提供样式计算回调，依赖须在回调自己的 context 读取
- 上层页面与示例中的独立局部区域（内容分组、面板、示例舞台、卡片）使用 ElCardView 建立容器语义；ElCard 负责品牌外观并复用它，文字、装饰和布局辅助仍按职责使用 ElView，交互叶子保留按钮、链接等行为基元
- 组件保持公共接口与品牌实现分离，复用已有模型、事件、焦点和弹层机制，不额外设计同职责的协议、选项类型或状态通道
- 用户 style 在默认样式之后合并；载荷中的 Widget 保留原实例，其他内容交给现有内容桥接；保留各组件既有的 disabled、loading 和空回调语义，避免迁移时把空回调或加载状态机械地等同禁用
- Git 提交信息必须使用中文；Conventional Commit 类型、作用域和代码标识可以保留英文
- 写完功能、修复 bug 默认只跑本次改动覆盖的局部测试，全量测试仅在用户明确要求时执行
- 运行代码生成直接执行 dart run build_runner build

## 格式化

- 根目录与 example/ 的 analysis_options.yaml 均配置 formatter.page_width: 120，沿用 el 的 Dart formatter；不要混用默认 80 列或临时指定其他行宽
- 使用 dart format <本次涉及的 Dart 文件>，让 formatter 自动读取最近的项目配置；不手动压行，也不为单次修改格式化无关文件或生成产物
- 格式调整保留文件中的在途业务修改，只提交本次确实修改的文件

## 目录与组件边界

- lib/src/flutter/ 承担通用组件声明、视图、事件、焦点、滚动、布局等机制；lib/src/ui/desktop/ 与 lib/src/ui/mobile/ 承担各端具体外观
- 用户通过 flutter_base.dart、desktop.dart、mobile.dart 等公共入口使用接口；具体组件、Builder 和辅助函数留在 src 内部，生产示例不依赖具体实现
- 主题入口为 ElDesktopTheme / ElMobileTheme，两端共用通用颜色、阴影等 token，后代统一使用 context.elTheme；通过 ElView 变量表及样式级联覆写，不另建一套主题继承协议
- 变量键不限制 String 或 -- 前缀，使用能区分身份的 Object 键；暗色等变体由 ElStyle 级联覆写
- 桌面组件只处理桌面默认样式，尺寸使用 compact 布尔模式；移动组件只处理移动默认样式，不默认附带鼠标悬停、键盘焦点环或桌面尺寸，调用方显式提供的样式变体仍生效
- 桌面默认焦点环使用 onFocusVisible，避免指针点击出现键盘焦点环；两端保留必要的键盘操作、外借焦点节点和辅助技术语义
- 多子布局与官方机制按职责复用 Flutter Row / Column / Wrap / Stack、RadioGroup、Overlay 等，不重复实现已有能力

## 文本编辑 API 边界

flutter_base 导出 ElEditableView、ElEditableController、ElEditableStyle，负责内容、光标、滚动与选区；语法高亮、代码折叠、搜索、多光标、编辑命令与事务扩展属于独立的编辑器扩展层。普通 Input / OTP 不依赖编辑器扩展，不把上层编辑能力反向塞入基础编辑视图。

## 测试与机器占用红线

- **严厉禁止编写或运行前台窗口测试**：不得写、不得跑会弹出真实窗口、抢占前台焦点或依赖人工操作的应用测试——包括 `flutter run`、`flutter drive`、以 Windows/真机设备运行的 `integration_test`、依赖截图比对的真机脚本。验证一律走无头 `flutter test`（flutter_tester），不弹窗、不抢焦点。
- **严厉禁止占用用户操作电脑**：不得为了验证而长时间吃满 CPU/内存（全量 benchmark、批量重复跑、无人值守长跑），不得与用户正在操作的会话抢资源；重负载验证先说明代价、取得同意，并放后台 + 降优先级 + 设超时兜底。
- 用户正在运行的应用实例（element_docs / flutter run 等）不得擅自 kill、重启、附加调试或注入代码；先报告现场与结论，等用户决定。
