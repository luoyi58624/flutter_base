# my-ui Flutter 迁移报告

日期：2026-10-30。工作根 F = D:/project/flutter/flutter_base，真源 W = D:/project/html/my-ui，旧包 O = D:/project/my-project/el/ui/my_ui。下文相对路径默认 F；W:/O: 后的路径从各自根开始。components/、cores/缩写基于lib/src/my_ui；parity_test.dart和theme_test.dart缩写基于test/my_ui；inventory/audit/migration-plan缩写基于.claude/plan/my-ui-*文档。源码行号为本轮磁盘版本。

## 执行摘要

- 已完成全量54组件的源码规格清单、旧包审计、分阶段计划；产物分别为 .claude/plan/my-ui-inventory.md:1、my-ui-old-impl-audit.md:1、my-ui-migration-plan.md:1。旧包覆盖53组件、缺ImagePreview，不能把MyImage的前缀匹配视作预览实现（audit:7、34、90）。
- 已实现全局token/主题内核，以及Button、Tag、Switch、Card、Divider、Loading、Progress、Skeleton八组件。独立import/export，使用当前ElView/ElStyle/ElEvent，入口为 lib/src/my_ui/index.dart:5-7，八组件导出为 components/index.dart:4-11。
- 最终新模块静态检查：0 error、0 warning、0 info。新增测试 **51/51通过**，仅运行test/my_ui。测试证据入口：test/my_ui/parity_test.dart:64-923、test/my_ui/theme_test.dart:14-87；命令及范围见下文。
- 全仓flutter analyze已执行，但未达到全仓0 error：**31 error、0 warning、8 info**，39项全部在白名单外示例/既有测试。逐项列于本报告诊断表，未擅自修复。
- 八组件均为「部分对齐」：props/事件映射已实现并经自动化验证，默认静态规格已有断言；存在 **4个TODO(parity)**，未做同平台字体/栅格和设备读屏验收，不能声明1:1完成。其余46组件未开工。

## 交付与责任划分

| 层 | 文件及证据 | 责任 |
| --- | --- | --- |
| 主题值 | lib/src/my_ui/cores/theme_data.dart:11-537 | 全量明暗根颜色、五组阴影、overlay、四档字重，以及首批组件变量；nullable override可显式清除 |
| 主题宿主 | lib/src/my_ui/cores/theme.dart:13-82 | 系统亮暗/显式局部主题、默认文字与ElThemeMode同步 |
| 内部桥接 | lib/src/my_ui/cores/common.dart:11-406 | 内容、断点、焦点/键盘、触摸反馈、普通事件冒泡、整卡内部控件过滤、单值/Notifier生命周期 |
| 内部SVG | lib/src/my_ui/cores/glyph.dart:8 | Web内置路径与spinner绘制，读取ElView当前文字色；未公开导出为第九个组件 |
| 组件 | lib/src/my_ui/components/index.dart:4-11 | 八个独立文件，结构性props/事件/插槽的Flutter适配 |
| 测试 | test/my_ui/parity_test.dart:64；theme_test.dart:14 | 几何、状态、键鼠/触摸、表单、语义、主题与生命周期 |

本轮只迁移packages/core的全局主题和首批组件相关内核；日期、选择、上传、浮层等算法属于后续阶段，不能称packages/core全部迁移完毕。分期依据：my-ui-migration-plan.md:24-55。

## Web → Flutter 契约映射

所有 *.dart 顶部library doc均标注HTML真源。跨平台参数采用强类型，CSS px对应Flutter逻辑像素；未测量Windows截图，不涉及175%反算。

| 组件 | Web结构性props → Flutter | 事件与插槽 | 双向证据 |
| --- | --- | --- | --- |
| Button | variant七值→MyButtonVariant；icon同名；disabled/loading；selected保持nullable；delayTouchDown/Up→Duration；type三值→MyButtonType | click→onClick(ElEventDetails)，支持preventDefault；default→Object?/Widget child；submit/reset映射最近Flutter Form | W:packages/vue/components/Button.vue:6-28；lib/src/my_ui/components/button.dart:51-109、251-293 |
| Tag | modelValue→bool? value或互斥ValueNotifier<bool> modelValue；tone五值；disabled；null保留展示语义 | update:modelValue→onChanged；change先于onClick；default→child | W:packages/vue/components/Tag.vue:6-20；components/tag.dart:31-69、167-170 |
| Switch | modelValue→value或互斥Notifier，label、disabled | update:modelValue→onChanged；Space切换、Enter不切换；外部赋值不反射回调 | W:packages/vue/components/Switch.vue:6-18；components/switch.dart:13-40、52-60 |
| Card | title/description/sample/interactive；两个触摸Duration参数 | activate→onActivate；default→child；交互卡隐藏默认标题区，title作辅助名称 | W:packages/vue/components/Card.vue:6-24；components/card.dart:13-55、104-182 |
| Divider | vertical、align三值、dashed | 无业务事件；default→Object?/Widget child，竖向不显示插槽 | W:packages/vue/components/Divider.vue:6-17；components/divider.dart:27-45、83-113 |
| Loading | size三值→MyLoadingSize；label | 无业务事件；default→child；无可见插槽时label供播报 | W:packages/vue/components/Loading.vue:6-17；components/loading.dart:30-44、47-90 |
| Progress | value/buffer/max、type两值、status四值、label/showText | 无业务事件；default scoped slot→textBuilder(context, MyProgressValue)，提供归一化value/max/percentage | W:packages/vue/components/Progress.vue:6-25；components/progress.dart:63-97、102-156 |
| Skeleton | loading、rows、avatar、label | 无业务事件；default→child，隐藏但保留State，加载中退出焦点/语义 | W:packages/vue/components/Skeleton.vue:6-20；components/skeleton.dart:14-42、109-117 |

Flutter没有任意DOM attributes/id/aria-labelledby挂载语义；本轮采用明确label、ElSemantics和Flutter Form映射。浏览器原生表单提交/导航不是Flutter Form.save的等价实现，需在未来MyForm阶段扩展应用级处理；不能声称HTML平台API逐项相同（W:packages/core/my-ui.js:1290-1307；button.dart:264-274）。

## Parity checklist 当前进度

[x] 表示本轮结构/事件契约已实现且对应自动化覆盖；视觉[ ]表示尚未完成完整视觉验收。事件为“—”的组件无Web业务事件，其事件栏[x]仅表示未新增伪事件。每个组件的初始全unchecked表保留于migration-plan.md:57-116。

| 组件 | Props对齐 | 事件对齐 | 视觉对齐 | 判定与验收证据 |
| --- | --- | --- | --- | --- |
| Button | [x] | [x] | [ ] | 部分对齐；parity_test.dart:111、145、177、209、575、602、783、882 |
| Tag | [x] | [x] | [ ] | 部分对齐；parity_test.dart:245、650 |
| Switch | [x] | [x] | [ ] | 部分对齐；parity_test.dart:284、324 |
| Card | [x] | [x] | [ ] | 部分对齐；parity_test.dart:352、391、612、856、902 |
| Divider | [x] | [x]（—） | [ ] | 部分对齐；parity_test.dart:421、433；语义TODO |
| Loading | [x] | [x]（—） | [ ] | 部分对齐；parity_test.dart:446、562 |
| Progress | [x] | [x]（—） | [ ] | 部分对齐；parity_test.dart:510、538、764、917；角色/opacity TODO |
| Skeleton | [x] | [x]（—） | [ ] | 部分对齐；parity_test.dart:459、483、492、738 |
| AppBar | [ ] | [ ] | [ ] | 未开工；规格见inventory的AppBar节 |
| Avatar | [ ] | [ ] | [ ] | 未开工；规格见inventory的Avatar节 |
| Badge | [ ] | [ ] | [ ] | 未开工；规格见inventory的Badge节 |
| Calendar | [ ] | [ ] | [ ] | 未开工；规格见inventory的Calendar节 |
| CellGroup | [ ] | [ ] | [ ] | 未开工；规格见inventory的CellGroup节 |
| Checkbox | [ ] | [ ] | [ ] | 未开工；规格见inventory的Checkbox节 |
| CheckboxGroup | [ ] | [ ] | [ ] | 未开工；规格见inventory的CheckboxGroup节 |
| Choices | [ ] | [ ] | [ ] | 未开工；规格见inventory的Choices节 |
| Collapse | [ ] | [ ] | [ ] | 未开工；规格见inventory的Collapse节 |
| CollapseItem | [ ] | [ ] | [ ] | 未开工；规格见inventory的CollapseItem节 |
| Combobox | [ ] | [ ] | [ ] | 未开工；规格见inventory的Combobox节 |
| DatePicker | [ ] | [ ] | [ ] | 未开工；规格见inventory的DatePicker节 |
| Dialog | [ ] | [ ] | [ ] | 未开工；规格见inventory的Dialog节 |
| Drawer | [ ] | [ ] | [ ] | 未开工；规格见inventory的Drawer节 |
| Empty | [ ] | [ ] | [ ] | 未开工；规格见inventory的Empty节 |
| Floating | [ ] | [ ] | [ ] | 未开工；规格见inventory的Floating节 |
| Form | [ ] | [ ] | [ ] | 未开工；规格见inventory的Form节 |
| FormField | [ ] | [ ] | [ ] | 未开工；规格见inventory的FormField节 |
| Icon | [ ] | [ ] | [ ] | 未开工；规格见inventory的Icon节 |
| Image | [ ] | [ ] | [ ] | 未开工；规格见inventory的Image节 |
| ImagePreview | [ ] | [ ] | [ ] | 未开工；规格见inventory的ImagePreview节 |
| Input | [ ] | [ ] | [ ] | 未开工；规格见inventory的Input节 |
| ListRow | [ ] | [ ] | [ ] | 未开工；规格见inventory的ListRow节 |
| Menu | [ ] | [ ] | [ ] | 未开工；规格见inventory的Menu节 |
| Navigation | [ ] | [ ] | [ ] | 未开工；规格见inventory的Navigation节 |
| Notice | [ ] | [ ] | [ ] | 未开工；规格见inventory的Notice节 |
| Picker | [ ] | [ ] | [ ] | 未开工；规格见inventory的Picker节 |
| Popover | [ ] | [ ] | [ ] | 未开工；规格见inventory的Popover节 |
| Popup | [ ] | [ ] | [ ] | 未开工；规格见inventory的Popup节 |
| PullRefresh | [ ] | [ ] | [ ] | 未开工；规格见inventory的PullRefresh节 |
| Radio | [ ] | [ ] | [ ] | 未开工；规格见inventory的Radio节 |
| RadioGroup | [ ] | [ ] | [ ] | 未开工；规格见inventory的RadioGroup节 |
| Segmented | [ ] | [ ] | [ ] | 未开工；规格见inventory的Segmented节 |
| Select | [ ] | [ ] | [ ] | 未开工；规格见inventory的Select节 |
| Sheet | [ ] | [ ] | [ ] | 未开工；规格见inventory的Sheet节 |
| Slider | [ ] | [ ] | [ ] | 未开工；规格见inventory的Slider节 |
| Stepper | [ ] | [ ] | [ ] | 未开工；规格见inventory的Stepper节 |
| Steps | [ ] | [ ] | [ ] | 未开工；规格见inventory的Steps节 |
| Tabbar | [ ] | [ ] | [ ] | 未开工；规格见inventory的Tabbar节 |
| Tabs | [ ] | [ ] | [ ] | 未开工；规格见inventory的Tabs节 |
| TagGroup | [ ] | [ ] | [ ] | 未开工；规格见inventory的TagGroup节 |
| Textarea | [ ] | [ ] | [ ] | 未开工；规格见inventory的Textarea节 |
| TimePicker | [ ] | [ ] | [ ] | 未开工；规格见inventory的TimePicker节 |
| Toast | [ ] | [ ] | [ ] | 未开工；规格见inventory的Toast节 |
| Tooltip | [ ] | [ ] | [ ] | 未开工；规格见inventory的Tooltip节 |
| Upload | [ ] | [ ] | [ ] | 未开工；规格见inventory的Upload节 |

统计：结构性props 8/54、事件契约8/54（含4个无业务事件组件）、完整视觉验收0/54；已对齐组件0，部分对齐8，未开工46。阶段1全局token与主题自动化DoD已通过；阶段2代码/测试已交付，完整1:1验收未关闭。

## 与旧包相比已修复的已证实问题

| 问题 | 本轮结果与证据 |
| --- | --- |
| Button缺type/nullable selected、图标通用20px | 提供Form默认动作和nullable状态；七variant图标16/19/17/14，44/46px盒；button.dart:37-109、229-246；parity_test.dart:111、209、602 |
| Tag缺click、固定高度 | change→click；28/32 min-height；命中外层不缩放；tag.dart:88-170；parity_test.dart:245 |
| Switch额外disabled透明度、缺thumb变量 | 不额外降低透明度；47×28/22/3/19及thumb颜色变量；switch.dart:61-103；parity_test.dart:284、324、688 |
| Card漏时序和移动断点 | <=1100/760/400完整padding、标题/sample间距；card.dart:58-76、104-163；parity_test.dart:352、612 |
| Divider竖高15、只支持String说明 | 13px默认高、1px线宽、Widget插槽；divider.dart:75-109；parity_test.dart:421、433；separator角色仍未对齐 |
| Loading数字size/缺status | 三档16/24/32、spinner/liveRegion；loading.dart:12-24、47-80；parity_test.dart:446 |
| Skeleton rows=0变1，loading销毁child | 0/NaN回退3，1..10归一化；Offstage保留实例，ExcludeFocus；skeleton.dart:36-42、109-117；parity_test.dart:483、492、738 |
| Progress缺scope builder和轨道/缓冲变量 | MyProgressValue/textBuilder、完整首批变量、归一化、缓冲下限、200ms弧长/宽度变化；progress.dart:40-97、102-156；parity_test.dart:510、688、764 |
| 旧part结构和陈旧vars API | 独立文件/显式export，实际类型token和ElStyle；index.dart:5-7、components/index.dart:4-11；旧证据见audit:78 |

没有把旧包所有组件统称为“效果差”。源码偏差、尚未运行的旧测试和未验收设备视觉已分开；完整审计见my-ui-old-impl-audit.md:66-94。

本轮测试还修复了新实现中发现的布局和事件缺陷：按钮按内容收缩，圆环维持96px，loading保留尺寸/名称/焦点，普通祖先事件继续冒泡，禁用子按钮不再激活整卡。回归证据：parity_test.dart:111、145、538、602、882、902。

## 验证结果与可复现命令

环境：Flutter3.47.5、Dart3.13.4，PUB_CACHE=D:/data/pub-cache。未使用load_workspace_dependencies；未启动flutter run、应用窗口、真机或示例服务。

| 检查 | 本轮实际结果 |
| --- | --- |
| dart pub get --offline --enforce-lockfile --no-example | exit0；根包依赖解析完成；未增加依赖或修改pubspec/lock |
| flutter analyze --no-pub lib/src/my_ui test/my_ui/parity_test.dart test/my_ui/theme_test.dart | exit0，No issues found；最终13.9s；0 error/warning/info |
| flutter test test/my_ui --no-pub --concurrency=1 --reporter expanded | exit0，51 passed；两测试文件，未跑全仓测试 |
| flutter analyze --no-pub | exit1，31 error/0 warning/8 info；39处白名单外诊断见下表 |
| dart format 显式新Dart文件列表 | exit0；没有格式化其他模块 |
| 无头Edge原CSS几何 | skeleton标题到首行gap18、总高123；对应Flutter断言见parity_test.dart:459；没有生成截图或启动窗口 |

正常有权限的PowerShell环境可运行：

~~~powershell
Set-Location 'D:\project\flutter\flutter_base'
$env:PUB_CACHE = 'D:\data\pub-cache'
dart pub get --offline --enforce-lockfile --no-example
flutter analyze --no-pub lib/src/my_ui test/my_ui
flutter test test/my_ui --no-pub --concurrency=1 --reporter expanded
~~~

本轮环境限制与处理：
1. 进程命令工具的环境刷新报“setup refresh had errors”，通过Node child_process执行同一CLI；不把未启动命令当成功。
2. SDK D:/app/fvm/default为只读，flutter.bat需要写共享缓存/锁；直接原snapshot也因lockfile拒绝访问。临时在test/my_ui/.sdk创建私有bin/cache，使用同版本flutter_tools.snapshot，SDK packages/dev/examples/engine artifacts等只读目录通过junction引用；没有修改原SDK或绕过其共享锁。
3. analyzer默认 C:/Users/luoyi/AppData/Local/.dartServer 不可写，LOCALAPPDATA/APPDATA定向到test/my_ui/.runtime；同时补ProgramFiles(x86)变量供Windows工具探测。实际Flutter命令形式为“dart.exe <私有SDK>/bin/cache/flutter_tools.snapshot --no-version-check analyze/test …”。
4. 初次pub get因默认Pub缓存位置错误失败，指定真实PUB_CACHE后解决；带example时其现有锁文件与pubspec不匹配，改用--no-example验证本次根包。此限制没有通过修改example/pubspec.lock绕过。
5. 所有验证进程已退出；已逐个unlink临时SDK中的junction，再删除本次私有.sdk和.runtime目录，未递归进入原SDK。test/my_ui最终只保留两个Dart测试文件。

以上是验证环境适配，不是生产依赖；本轮没有将SDK/日志/缓存作为交付源码。CLI常规自动生成的.dart_tool/build文件未手工编辑。

### 全仓诊断逐项解释

这些诊断不涉及my_ui。示例仍使用已不可用的手势/视图名称；既有测试含旧类型或重复导入。由于用户只允许写白名单，保留现场并报告，不能将其修复混入本次迁移。定向51项测试没有受到其它会话编译错误阻碍，因此没有启动30/60/120秒重试流程。

| 级别 | file:line | 原因/处理 |
| --- | --- | --- |
| error | example/lib/src/pages/custom_gestures.dart:25:8 | 示例使用旧手势/视图API；未修改（undefined_class） |
| error | example/lib/src/pages/custom_gestures.dart:26:8 | 示例使用旧手势/视图API；未修改（undefined_class） |
| error | example/lib/src/pages/custom_gestures.dart:27:8 | 示例使用旧手势/视图API；未修改（undefined_class） |
| error | example/lib/src/pages/custom_gestures.dart:28:8 | 示例使用旧手势/视图API；未修改（undefined_class） |
| error | example/lib/src/pages/custom_gestures.dart:29:8 | 示例使用旧手势/视图API；未修改（undefined_class） |
| error | example/lib/src/pages/custom_gestures.dart:30:8 | 示例使用旧手势/视图API；未修改（undefined_class） |
| error | example/lib/src/pages/custom_gestures.dart:53:3 | 示例使用旧手势/视图API；未修改（undefined_class） |
| error | example/lib/src/pages/custom_gestures.dart:56:5 | 示例使用旧手势/视图API；未修改（undefined_class） |
| error | example/lib/src/pages/custom_gestures.dart:59:12 | 示例使用旧手势/视图API；未修改（undefined_method） |
| error | example/lib/src/pages/custom_gestures.dart:72:3 | 示例使用旧手势/视图API；未修改（undefined_class） |
| error | example/lib/src/pages/custom_gestures.dart:121:12 | 示例使用旧手势/视图API；未修改（non_type_as_type_argument） |
| error | example/lib/src/pages/custom_gestures.dart:132:5 | 示例使用旧手势/视图API；未修改（undefined_class） |
| error | example/lib/src/pages/custom_gestures.dart:143:7 | 示例使用旧手势/视图API；未修改（undefined_identifier） |
| error | example/lib/src/pages/custom_gestures.dart:144:7 | 示例使用旧手势/视图API；未修改（undefined_identifier） |
| error | example/lib/src/pages/custom_gestures.dart:145:7 | 示例使用旧手势/视图API；未修改（undefined_identifier） |
| error | example/lib/src/pages/custom_gestures.dart:146:7 | 示例使用旧手势/视图API；未修改（undefined_identifier） |
| error | example/lib/src/pages/custom_gestures.dart:147:7 | 示例使用旧手势/视图API；未修改（undefined_identifier） |
| error | example/lib/src/pages/custom_gestures.dart:148:7 | 示例使用旧手势/视图API；未修改（undefined_identifier） |
| error | example/lib/src/pages/custom_gestures.dart:515:5 | 示例使用旧手势/视图API；未修改（undefined_class） |
| error | example/lib/src/pages/custom_gestures.dart:529:5 | 示例使用旧手势/视图API；未修改（undefined_class） |
| error | example/lib/src/pages/view.dart:32:27 | 旧backgroundColor参数不再存在；未修改示例（undefined_named_parameter） |
| error | example/lib/src/pages/view.dart:53:33 | 旧backgroundColor参数不再存在；未修改示例（undefined_named_parameter） |
| error | example/lib/src/pages/view/base.dart:17:17 | 示例使用旧手势/视图API；未修改（undefined_method） |
| error | example/lib/src/pages/view/base.dart:25:27 | 旧backgroundColor参数不再存在；未修改示例（undefined_named_parameter） |
| error | example/lib/src/pages/view/base.dart:25:52 | 旧BuildContext.hasTap/hasHover入口失效；未修改示例（undefined_getter） |
| error | example/lib/src/pages/view/base.dart:27:41 | 旧BuildContext.hasTap/hasHover入口失效；未修改示例（undefined_getter） |
| error | example/lib/src/pages/view/base.dart:32:37 | 旧BuildContext.hasTap/hasHover入口失效；未修改示例（undefined_getter） |
| error | example/lib/src/pages/view/base.dart:34:43 | 旧BuildContext.hasTap/hasHover入口失效；未修改示例（undefined_getter） |
| error | example/lib/src/pages/view/base.dart:38:54 | 旧BuildContext.hasTap/hasHover入口失效；未修改示例（undefined_getter） |
| info | test/flutter/hooks/add_listener_test.dart:3:8 | 重复导入flutter_hooks；保留白名单外文件（unnecessary_import） |
| info | test/flutter/hooks/animation_status_listener_test.dart:3:8 | 重复导入flutter_hooks；保留白名单外文件（unnecessary_import） |
| info | test/flutter/hooks/curve_animation_test.dart:3:8 | 重复导入flutter_hooks；保留白名单外文件（unnecessary_import） |
| info | test/flutter/hooks/did_update_test.dart:3:8 | 重复导入flutter_hooks；保留白名单外文件（unnecessary_import） |
| info | test/flutter/hooks/hook_state_test.dart:3:8 | 重复导入flutter_hooks；保留白名单外文件（unnecessary_import） |
| info | test/flutter/hooks/simple_hooks_test.dart:3:8 | 重复导入flutter_hooks；保留白名单外文件（unnecessary_import） |
| info | test/flutter/hooks/watch_test.dart:3:8 | 重复导入flutter_hooks；保留白名单外文件（unnecessary_import） |
| info | test/flutter/model_value/model_value_test.dart:5:8 | 重复导入flutter_hooks；保留白名单外文件（unnecessary_import） |
| error | test/flutter_base/sdk/binding/resampling_test.dart:402:22 | 既有测试使用旧ElEvent类型/宿主；未修改（non_type_as_type_argument） |
| error | test/flutter_base/sdk/binding/resampling_test.dart:408:18 | 既有测试使用旧ElEvent类型/宿主；未修改（undefined_function） |

## 未关闭的 parity 与风险

| 位置 | 当前行为/缺口 | 后续验收 |
| --- | --- | --- |
| lib/src/my_ui/cores/theme.dart:49 | TODO：Web未指定统一font-family，Flutter和浏览器的平台字体、字形、行盒/栅格尚未同平台核对 | 先固定同一平台和字体条件；未验收前所有文字组件视觉栏保持unchecked |
| lib/src/my_ui/components/divider.dart:61 | TODO：当前SDK没有separator/orientation角色，用中文hint表达方向 | 平台读屏检查；不能把hint称作原生separator等价物 |
| lib/src/my_ui/components/progress.dart:224 | TODO：不确定进度采用Flutter官方loadingSpinner映射，Web保持progressbar | 平台读屏检查；官方约束证据 D:/app/fvm/default/packages/flutter/lib/src/material/progress_indicator.dart:146-159、src/semantics/semantics.dart:214-258 |
| lib/src/my_ui/components/progress.dart:283 | TODO：确定值弧长已插值200ms，0值/缓冲隐藏时缺独立opacity淡出 | 对照W:packages/core/my-ui.css:1711-1716、W:packages/core/my-ui.js:5773-5779补齐并验证轨迹 |
| 全部组件 | 默认色值/几何已断言，设备字体、SVG/阴影边缘、不同DPR/读屏未做人工验收 | 本轮按“不起窗口”约束停止在自动化证据；不声称设备像素一致 |
| Button/Form | Flutter Form校验/保存/重置是已实现的默认动作映射，浏览器提交地址/导航无对应宿主 | 阶段3设计MyForm时完成应用级提交契约，保留preventDefault |
| 模块入口 | 只能从package:flutter_base/src/my_ui/index.dart导入 | 顶层lib/my_ui.dart不在白名单，后续需扩大范围后再加 |

## 剩余阶段与暂停/续作

- 阶段1：全局token与首批变量/主题宿主已交付；不要把未公开的MyGlyph或内部MyAction当新公共组件。阶段2：八组件已交付，先关闭上述4个TODO及平台视觉验收，再把视觉栏改为[x]。
- 阶段3：先Icon/Avatar/Image/Badge/Empty，再Input/Textarea/Form/FormField，最后Radio/Checkbox/选择组等；按inventory逐条建props/事件/视觉测试，不整体复制旧part文件。阶段4/5的DoD见migration-plan.md:45-55。
- 暂停点：当前源码和测试已落盘，无待提交/切分支步骤；本任务没有执行任何git命令。外部可停止本轮，再用codex exec resume续同会话。
- 续作先读局部CLAUDE规范、四份my-ui计划文档及本报告，核对真源指纹；然后执行上面的定向analyze/test。全仓31 error需另获白名单外修复范围，不能为其改动ui/scroll或example。
- 本轮未修改pubspec.yaml、pubspec.lock；未新增依赖。源码快照核验：开始时记录的375个既有lib文件和2个pubspec文件共377项，收尾哈希全部一致；新写源码仅lib/src/my_ui，测试仅test/my_ui。没有git状态/差异查询，也没有改动lib/src/ui或lib/src/scroll。

### 真源指纹（SHA-256，续作先核对是否漂移）

| 文件（W根） | SHA-256 |
| --- | --- |
| packages/core/my-ui.css | 4466f13f484697183a22390bb848eae9c2a039506e9f243b1117446dc3c4624a |
| packages/core/my-ui.js | 27b44d2678f8026a8f7f5a1e0c9fa0d4674e046abe150bc676a8764c3e237cd5 |
| packages/vue/index.ts | 7abfbd08ddfb741b66d1a891ed3aced358a38b412e258134b57819ae660758ef |
| packages/vue/components/Button.vue | 50e527f2a7ba4ad59a9a514aab725a68c56c8e1cc6a207c2e9cab1f885d1c8e1 |
| packages/vue/components/Tag.vue | 4bf579e119d364a40a49b9b23dbc717443b610709abe01572a22780877fe42aa |
| packages/vue/components/Switch.vue | d911d48d2af3499566c0c33b9bfe425e535e791e70dfef07b6d1518f28aa301e |
| packages/vue/components/Card.vue | ac75b37630d3056a207dfc046bcd40d09a680babf2c1d3eed4b9aba08384c649 |
| packages/vue/components/Divider.vue | 18af6f1d58e271a8437ba645587197d33f2765b4062bd1d0ad0dee89e45578d1 |
| packages/vue/components/Loading.vue | 0860abf0ebc9a938bb8aee9a65738111c1883987c60bad4175407087f54327ec |
| packages/vue/components/Progress.vue | 761ceabc2eb8c67cf1e419460c2d22f5eb4607f9be3f614078271ad791fb4a15 |
| packages/vue/components/Skeleton.vue | 0810cb81c3b4dad82745a8a10a99372d76dea76293f10dd85e75063ce93732ef |
