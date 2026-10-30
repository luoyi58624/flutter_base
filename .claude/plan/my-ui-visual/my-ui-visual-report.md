# my-ui 首批 8 组件视觉验收

日期：2026-10-30。结论：真实渲染和截图交付已完成，首批视觉验收尚未通过。Loading、Progress 存在实际图标尺寸缺陷；跨端字体基线尚未闭合。本轮只采集、测量和报告，没有修改组件实现。

[打开离线对照图库](index.html) · [截图清单与 SHA-256](screenshot-manifest.json) · [执行计划](my-ui-visual-run-plan.md)

## 1. 交付矩阵与查看方法

| 类别 | 计算 | 实际数量 | 结果 |
| --- | --- | ---: | --- |
| Web 匹配样例，实际 Vue 包组件 | 8 组件 × 2 宽 × 2 主题 | 32 | 齐全 |
| Flutter 组件真实栅格化 | 8 组件 × 2 宽 × 2 主题 | 32 | 齐全 |
| Web example 实体页面 | 8 页面 × 2 宽 × 2 主题 | 32 | 齐全 |
| hover / pressed / focus 补图 | 4 组件 × 2 条件 × 3 状态 × 2 端 | 48 | 齐全 |
| 并排对比图与状态总览 | 32 基础 + 24 状态 + 8 总览 | 64 | 齐全 |
| PNG 总计 | 144 原始截图 + 64 派生对照图 | 208 | 无缺项 |

核心矩阵是 32+32 张，而非 16+16；每侧 8×2×2=32。原始文件命名为 web-{组件}-{390或1440}-{light或dark}.png、flutter-{同键}.png；example- 前缀是实体文档页。compare- 前缀是左 Web、右 Flutter 对照图。图库可按组件、宽度、主题和状态切换，并打开原始 PNG。

所有原始 PNG 均为 390×900 或 1440×900。390 是实际运行视窗逻辑宽度，未缩小桌面截图。对照派生图在桌面截取左侧内容区以便阅读，1440 原图完整保留。统一样例容器内宽为 mobile 342、desktop 720，文档页面保留其原有布局。

| 组件 | 390 明 | 390 暗 | 1440 明 | 1440 暗 |
| --- | --- | --- | --- | --- |
| Button | [对照](compare-button-390-light.png) | [对照](compare-button-390-dark.png) | [对照](compare-button-1440-light.png) | [对照](compare-button-1440-dark.png) |
| Tag | [对照](compare-tag-390-light.png) | [对照](compare-tag-390-dark.png) | [对照](compare-tag-1440-light.png) | [对照](compare-tag-1440-dark.png) |
| Switch | [对照](compare-switch-390-light.png) | [对照](compare-switch-390-dark.png) | [对照](compare-switch-1440-light.png) | [对照](compare-switch-1440-dark.png) |
| Card | [对照](compare-card-390-light.png) | [对照](compare-card-390-dark.png) | [对照](compare-card-1440-light.png) | [对照](compare-card-1440-dark.png) |
| Divider | [对照](compare-divider-390-light.png) | [对照](compare-divider-390-dark.png) | [对照](compare-divider-1440-light.png) | [对照](compare-divider-1440-dark.png) |
| Loading | [对照](compare-loading-390-light.png) | [对照](compare-loading-390-dark.png) | [对照](compare-loading-1440-light.png) | [对照](compare-loading-1440-dark.png) |
| Progress | [对照](compare-progress-390-light.png) | [对照](compare-progress-390-dark.png) | [对照](compare-progress-1440-light.png) | [对照](compare-progress-1440-dark.png) |
| Skeleton | [对照](compare-skeleton-390-light.png) | [对照](compare-skeleton-390-dark.png) | [对照](compare-skeleton-1440-light.png) | [对照](compare-skeleton-1440-dark.png) |

## 2. 真实来源和运行条件

Web 真源是 D:/project/html/my-ui，实际读取 packages/vue/index.ts 导出的 8 个组件、packages/core/my-ui.css 与 my-ui.js，主题读取 example/src/commons/theme/index.js 和 example/public/theme-init.js。既运行了真实 example 页面，也在单独的匹配样例页挂载同一 Vue 包，便于使用与 Flutter 相同的 props、插槽、文案及容器。没有使用蓝图 HTML 兜底，也没有手绘 CSS 冒充原组件。

仓库当前 packageManager 为 bun@1.3.8（与任务背景中的 pnpm 描述不同）。直接用已安装的 Vite 8.3.4、Vue 3.5.43、Playwright 1.62.1 启动，未安装依赖。Chrome 156.0.8078.48 无头运行；专用 Vite 服务端口 5189，缓存位于本交付目录。为在只读源仓库运行，使用独立 Vite 配置，保留实际 example 入口，并补足本地 native 插件路径和 highlight.js alias。

Flutter 使用 Flutter 3.47.5 / Dart 3.13.4，PUB_CACHE=D:/data/pub-cache。新增 [visual_render_test.dart](../../../test/my_ui/visual_render_test.dart)，以实际 MaterialApp、MyTheme 和现有 8 组件建立真实 RenderObject 树，由 flutter_tester 执行布局、绘制，再经 RenderRepaintBoundary.toImage 写 PNG。没有用 mock 绘图替代组件，也没有创建前台 Windows 窗口。

两端均明确设置 DPR=1；因此截图 1 物理像素对应 1 逻辑 px/DIP。这是受控截图，用户桌面 175% 缩放不参与本轮测量。Web viewport 和 Flutter test view 分别设为 390×900、1440×900；Flutter MediaQuery 同步。所有尺寸结论取 DOM / RenderBox 几何值，避免把抗锯齿像素边缘当设计尺寸。

两端开启 reduced motion / disableAnimations，进行静态状态验收。Loading、Skeleton、Progress 不确定态是固定静态画面；本轮不据此确认动画速度、相位、过渡时长、帧性能或真实设备表现。

字体条件必须单列：同机 Web 实测 body 和组件继承 Times New Roman；真源 body 没有明确 font-family，并非字体资源加载失败。Flutter 测试宿主显式选用 Segoe UI，并加载 Microsoft YaHei 回退；标注文字用 Arial。此设置消除 flutter_tester 的 Ahem 测试字体，并代表一种 Windows 宿主选项，不能宣称是 MyTheme 已经规定的默认字体。Material 宿主也避免了 WidgetsApp 错误文字样式。字体差异作为未闭合项保留，没有据此豁免严格验收。

匹配样例只对测试容器设置 scrollbar-gutter:auto，消除 Web 原样例 stable 滚动条预留的 15px，使两端内容宽度可比；组件 CSS 未改。实体 example 截图保留原页面行为。Loading / Skeleton 实体页通过真实点击“重新加载”显示加载态，并暂停其 850ms 定时器以取图。

## 3. 逐组件结论

“⚠️可接受偏差”表示本轮目测下局部结构可接受，仍受公共字体问题影响；不等于整批验收通过。结论仅覆盖下表已截图的变体与状态。

| 组件 | 结论 | 已验证范围及差异 | 参照依据 |
| --- | --- | --- | --- |
| Button | ⚠️可接受偏差 | 44 高、13 圆角，primary / outline / text、icon / bare / round、selected、disabled、loading，以及焦点/悬浮/按下形态基本一致。英文衬线形态和文本宽度不同；390 主按钮 Web 90.922、Flutter 92.739，差约 1.817。 | core 按钮 CSS、实际 Vue Button、四组对照和状态补图 |
| Tag | ⚠️可接受偏差 | 展示标签 28 高、内横距 12、字号 13，五种颜色及 selectable 32 高 / radius 11、选中与禁用态一致。文本宽度受字体影响；Blue 蓝为 66.813 对 67.317。 | core Tag CSS、实际 Vue Tag、四组对照和状态补图 |
| Switch | ⚠️可接受偏差 | 47×28、thumb 22、3 内距与 19 位移、明暗开关及 disabled 外观一致。Web input 保留 UA margin:3px 3px 3px 4px，额外占布局空间；Flutter 没有该外边距，非轨道尺寸错误。 | core Switch CSS、DOM computed margin、47×28 实测和状态补图 |
| Card | ⚠️可接受偏差 | desktop radius30 / padding28 29 29，mobile radius26 / padding24 22 25，与当前真源响应式规则一致。边框、标题/说明间距与交互态一致；浅色 Flutter 阴影较集中，Web 更弥散；字体形态不同。 | core Card / surface CSS、实际 Vue Card、四组对照和状态补图 |
| Divider | ⚠️可接受偏差 | 1px 线、20 上下边距、13 字号、12 标签间隙、start/end 24 固定段、竖线 1×13 基本一致。虚线栅格与文字抗锯齿略异；布局高度有不足 1px 的舍入差。 | core Divider CSS、实际 Vue Divider、四组对照 |
| Loading | ❌需修 | small16、medium24 正确；large 外框32，但 Flutter 实际 MyGlyph 仍24，弧线明显偏小且靠左上。详见缺陷 L1。 | Web SVG 与 Flutter glyph RenderBox、四组对照、像素覆盖测量 |
| Progress | ❌需修 | line 高21 / 轨道6、40进度与70 buffer、success / warning / error、圆环96及隐藏读数形态基本一致；圆环成功/失败标记应26.88，实际24且偏心。详见缺陷 P1。 | core Progress SVG/CSS、Flutter glyph RenderBox、四组对照 |
| Skeleton | ✅一致（加载占位态） | 标题42%×18、正文13高、首间距18 / 后续12、末行66%、radius6、avatar42、gap14、纵 padding12，三行123高 / 两行98高，明暗一致。loaded 插槽文字仍受字体问题影响，Web20高 / Flutter22高。 | core Skeleton CSS、四组占位截图及 DOM / RenderBox 几何 |
| 主题内核 | ❌需先闭合字体基线；已测颜色一致 | 明暗背景、卡片、文字、主色、状态色一致；MyTheme 未规定与 Web 相同的字体族。字体形态、宽度、基线不能称为一致。自定义配色未纳入本轮。 | example applyTheme / theme-init、MyTheme 及两端真实截图 |

几何明细见 [Web DOM / computed styles](web-metrics.json)、[Flutter RenderBox](flutter-metrics.json) 和 [精简测量](measured-summary.json)。Card mobile 默认高度 174.781 对175，desktop183.141 对183；交互卡 mobile99、desktop107 两端相同。Card padding 为 CSS 内容 padding，不含1px边框；Flutter 对应内距实现包含边框补偿，不能只比较字段字面值。

题中 Input 的44高 / radius12 是后续参照，Input 不属于本批8组件，未截图亦未给通过结论。

## 4. 明确需修的问题

### L1：Loading large 内部图标没有随32外框放大

[390 明色证据](compare-loading-390-light.png) · [1440 暗色证据](compare-loading-1440-dark.png)

Web small / medium / large 的图标分别16、24、32。Flutter 外框确实为16、24、32，但实际 MyGlyph 为16、24、24。large 的24图标落在32外框左上，而不是32图标。

根因定位：[glyph.dart](../../../lib/src/my_ui/cores/glyph.dart) 第42–46行将松约束下默认尺寸固定为24×24，并按实际尺寸缩放画布；[loading.dart](../../../lib/src/my_ui/components/loading.dart) 第63–81行只设置外层宽高，内部 MyGlyph 没拿到32的紧约束。

在 large 的32×32裁剪区，深色弧线像素覆盖 Web 为28×28，Flutter为20×20（DPR1、阈值 max(R,G,B)<120，含端点范围分别[2,2,29,29]与[2,2,21,21]）。这项是绘制覆盖测量，不将28或20当作设计尺寸。完整数据见 [glyph-pixel-coverage.json](glyph-pixel-coverage.json)。

应修：让 glyph 获取明确目标尺寸或在调用处传递紧约束，保留16/24形态，确保32规格的实际图形与中心对齐；回归必须同时检查外框和实际 glyph/绘制结果。本轮未修改。

### P1：Progress 圆环成功/失败 glyph 偏小且偏心

[390 明色证据](compare-progress-390-light.png) · [1440 暗色证据](compare-progress-1440-dark.png)

96圆环状态图标外框为96×0.28=26.88；Web SVG跟随外框，Flutter内部 MyGlyph 实测仍24×24。成功和失败标记相对预期中心向左上各偏1.44，并且约小10.7%。line 状态 glyph 为18×18，受较小约束限制，未出现同样的24上限问题。

根因与 L1 共用 glyph 的默认24尺寸：[progress.dart](../../../lib/src/my_ui/components/progress.dart) 第193–197行只规定包装层26.88。应统一解决大于24图标的约束传播，并复验不同 circle size 下的比例与居中，避免只修96这个特例。本轮未修改。

### T1：字体策略没有形成共同基线

[Button](compare-button-390-light.png) · [Card](compare-card-390-light.png) · [Divider](compare-divider-1440-dark.png)

Web实测Times New Roman，Flutter本轮宿主为Segoe UI；差异贯穿按钮、标签、卡片、分割线和进度文字。例：390按钮 Save 保存 宽90.921875对92.73876953125，Cancel宽69.65625对71.8134765625；1440仅因响应式padding各多8宽，文字差异仍存在。Skeleton loaded 插槽行高20对22。

[theme.dart](../../../lib/src/my_ui/cores/theme.dart) 第49行已留字体验收TODO，当前主题未提供可作为跨端真源的字体族契约。因此，这次可确认具体宿主下有差异，不能把Segoe UI样例当作未经配置的默认表现，也不能推断Times New Roman是所有平台的默认。

应修/决策：为迁移库明确共同 font-family / fallback / 行高及继承规则；若目标是复刻当前同机 Web，就以其实际字体配置建立同条件样例；若产品决定采用系统字体，应记录为明确设计变更并统一参照。确定后重拍有文字的全部组件，确认换行、固有宽度和基线。无需先改业务组件尺寸来补偿字体宽度。

## 5. 状态、色彩和可接受差异

状态补图覆盖 Button primary、Tag selectable off、Switch off、Card interactive，在390明色与1440暗色下的 keyboard focus / mouse hover / pressed，共每端24张。已用真实鼠标悬浮/按下，以及Tab导航事件触发焦点态；Flutter焦点判断依据导航键状态，不能以单纯requestFocus替代。最终补图可见2px焦点环及3px外距，未发现焦点环缺失的组件缺陷。

[Button 明色状态](states-review-button-390-light.png) · [Tag 明色状态](states-review-tag-390-light.png) · [Switch 暗色状态](states-review-switch-1440-dark.png) · [Card 暗色状态](states-review-card-1440-dark.png)

按钮按下scale .95与卡片按下scale .96、明暗覆盖层和颜色目测匹配。普通样例同时包含disabled、selected、loading等状态；补充三态没有扩展到全部变体和所有主题宽度组合。[Web状态几何及样式](web-state-metrics.json) 保留原始测量。

| token | 明色 | 暗色 |
| --- | --- | --- |
| background | #f2f3f5 | #121419 |
| card-background | #ffffff | #252931 |
| primary / primary-text | #2454c6 / #ffffff | #aac8ff / #000000 |
| text / text-secondary | #17191e / #626874 | #f4f6fa / #c4cbd6 |
| fill / border | #f1f2f4 / #dde0e5 | #333944 / #596576 |
| success / warning / danger | #176b3c / #805500 / #b5283c | #a4dfb4 / #f3db82 / #ffacae |

Switch UA外边距导致Web第一项从(28,123)开始、Flutter从(24,120)开始，第二项分别x94与83。这是UA布局占位的累积差，47×28本体和22thumb相同。本轮判为可接受的宿主差异；若未来要求整页流式布局逐项对齐，需明确是否复现该外边距。

Card浅色阴影的扩散范围、Divider虚线栅格和少于1px的行高舍入判为可接受绘制差异。Divider裸线Web border-box高1加上下margin20，Flutter记录的是含外距41；带字Web20.796875加40，Flutter约61，不能误报为41倍粗线。

[Pillow像素差统计](pixel-comparison.json) 对同内容区域记录RGB平均绝对误差和阈值差异占比。它包含字体、阴影和抗锯齿影响，也可能被大片背景稀释，未用单一分数代替目测判定。

## 6. 检查结果与修改边界

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| Flutter真实渲染 | 4/4矩阵测试通过，每测试8组件，并输出补充状态；无布局/绘制异常 | [最终日志](run/flutter-render-keyboard.log) |
| 新文件分析 | 新增test文件0诊断；最终全仓分析亦没有新文件诊断 | [定向分析日志](run/analyze-new.txt)、[前后差异](analyze-comparison.json) |
| 全仓flutter analyze | 前39项，后39项：31 error / 0 warning / 8 info；新增0、减少0 | [之前](run/analyze-before.txt)、[最终](run/analyze-final.txt) |
| 截图矩阵 | 核心32+32，example32，状态24+24，208张PNG全部解码通过；报告链接无缺失 | [清单](screenshot-manifest.json)、[最终自查](final-validation.json) |
| Web最终采集 | metrics64项，failures为空，页面脚本无最终未处理错误 | [Web记录](web-metrics.json) |
| 保护文件比对 | 471文件SHA-256复核，changed=[]；包含全部389个lib文件、根pubspec与lock、80个Web源/清单文件 | [保护验证](protected-verification.json) |

全仓 analyze 不是0 error：现有31个error涉及在途旧API引用等，本任务开始时已存在，最终集合完全相同。该事实保留原始日志，不将其写成全仓通过。没有因其他会话编译错误阻断本次截图，也未启动重试等待。没有额外重跑既有51项组件测试或全量测试；这次运行的是新增视觉采集文件。

所有写入仅位于 test/my_ui/visual_render_test.dart 和本交付目录。未改任何lib、pubspec.yaml、pubspec.lock或Web真源文件；未执行git及commit，未添加dev_dependencies、flutter_driver或integration_test。私有SDK与项目副本的缓存写入均在run目录，没有改全局SDK，也没有执行pub get。

## 7. 运行障碍与复现

已处理的障碍：shell执行器启动时报setup refresh had errors，改用Node REPL的fs与child_process；.codex创建返回EPERM，改用已授权的.claude/plan输出目录；Flutter全局lock风险通过私有SDK缓存/锁及隔离运行目录规避；已有Playwright浏览器缓存不可用，直接选本机Chrome，无下载；Vite导入及原example本地依赖路径通过专用启动脚本处理。初次宿主Ahem字体、Material文字样式、15px滚动条预留和程序化焦点采集问题均已修正并重拍，不能把早期尝试日志中的问题算作当前组件缺陷。

最终矩阵没有跑不动的项。边界：本轮是Flutter无头真实渲染，不是Windows原生窗口截图；未验收动画全时序、触屏设备、性能、语义和未列出的全部API组合（例如Button link）。这不影响确认上述静态尺寸缺陷，但不能外推完整交互/性能通过。

复现入口：[run/replay.ps1](run/replay.ps1)。它先运行setup-runtime.mjs建立私有SDK/项目缓存，再启动只属于本任务的无头Vite服务，采集Web、example及状态，执行Flutter测试并生成对照图。脚本中各阶段等价命令均已实际成功运行；未把整段PowerShell脚本另行完整复跑。需要机器现有Node、Chrome、Python/Pillow、源仓库node_modules、Flutter3.47.5及D:/data/pub-cache。

对应脚本： [Web服务](run/web-server.mjs)、[匹配样例](run/fixture.js)、[Web采集](run/web-capture.mjs)、[真实加载态采集](run/web-loading-capture.mjs)、[Web状态](run/web-states.mjs)、[隔离SDK设置](run/setup-runtime.mjs)、[对照图](run/compare.py)。静态图库可离线打开，PNG和报告不依赖仍运行的服务。

清理状态：本任务Chrome与5189专用Vite服务均已关闭，私有SDK、项目副本及Vite缓存已删除，脚本与截图完整保留。run/runtime/local/Dart/perf/230824 清理时lstat返回EACCES，运行时缓存残留保留；未尝试更改权限或触碰全局缓存。该残留不影响截图与源码验证，复现时由setup-runtime重建所需缓存。详见[清理记录](run/cleanup-summary.json)。

## 8. 修复顺序与放行条件

1. 修复MyGlyph大于24时的实际尺寸传播，一并覆盖Loading large与Progress circle成功/失败；复验16、18、24、26.88、32及其他circle size，检查实际绘制与居中。
2. 明确跨端字体基线，统一参照与Flutter宿主后重拍全部文字样例，核对固有宽度、基线和换行。
3. 保留Card阴影、Switch UA外距与Divider栅格差异为已记录的可接受项；如产品要求更严整页复刻，再单独调整并复验。
4. 上述阻断项复验通过后再开始下一批，避免把glyph与字体问题扩散到46组件。

需先修首批，暂不允许进入下一批46组件。


## 9. 修复复验（round 2：glyph 尺寸 + Times New Roman）

日期：2026-10-30。**L1 / P1 尺寸缺陷已修复，字体契约和回归检查已落地；严格视觉验收仍未全面通过，不放行下一批 46 组件。** 原第1–8节是首轮历史结论，完整保留；本节以修复后的实际渲染为准。

[最新离线图库](round2/index.html) · [修复后测量](round2/measured-summary.json) · [190张PNG清单](round2/screenshot-manifest.json) · [源码差异](round2/source-changes.diff) · [本轮重放](run/round2-replay.ps1)

### 9.1 实现及检查结果

| 修复项 | 结果 | 实现与证据 |
| --- | --- | --- |
| Fix-1 / L1 | 尺寸与居中通过 | MyGlyph增加目标边长size，默认24；Loading明确传16/24/32。实际RenderBox和画布按同一尺寸缩放，尺寸更新会重新布局。 |
| Fix-2 / P1 | 尺寸与居中通过 | circle传size×0.28，line传18。覆盖40/64/96/128成功和失败，以及标准进度矩阵；实际glyph中心相对圆环中心误差小于1e-6逻辑像素。 |
| Fix-3 / T1 | 字体契约通过，严格文字视觉仍有残差 | MyThemeData增加fontFamily、不可变fontFamilyFallback和copyWith；MyTheme同步Flutter Text与ElView。保留9.4节的行盒/基线差，不能据此宣布整批通过。 |
| Fix-4 | 回归检查通过 | 新增5项组件glyph测试、2项主题测试；原有明暗token测试增加默认字体断言。实际glyph、包装层、圆环中心均有断言，没有只测包装层。 |
| 定向分析 | **0 error / 0 warning / 0 info** | [修复前](run/round2-analyze-before.log)、[修复后](run/round2-analyze-final-clean.log)，两次均No issues found。 |
| my_ui测试 | **62/62通过** | 原有51 + 新增7 + 现有视觉矩阵4。[最终测试日志](run/round2-tests-verified.log)。没有跑全仓测试。 |

源码只修改glyph、loading、progress、theme、theme_data五个lib文件。test/my_ui内新增glyph_size_test.dart，修改theme_test.dart和visual_render_test.dart。未执行git或commit，未改依赖声明、lock、lib/src/ui、lib/src/scroll或Web源。

本轮没有重跑全仓analyze；首轮记录的31个全仓存量error不是本轮重新测得的数值。本轮定向分析前后均为0诊断。[471文件保护复核](round2/protected-verification.json)显示变化仅为上述五个允许的lib文件，其余受保护文件一致。

### 9.2 字体与文字继承契约

默认主体为 **Times New Roman**；缺字时依次回退 **Microsoft YaHei、SimSun**。Chrome CDP实际字体取证表明，Save 保存的英文/空格使用Times New Roman，中文使用Microsoft YaHei；Cancel仅使用Times New Roman，见[实际字体记录](round2/web-fonts.json)。Web body仍未设置font-family，没有修改Web来迎合Flutter。

MyTheme在DefaultTextStyle与根ElView同时设置这组字体、15px主体字号与对应字重。根行高采用字体自身normal度量（kTextHeightNone），避免普通Text插槽继承Material宿主行高。组件显式行高继续优先；子级显式字体优先；嵌套MyTheme重新建立自己的主题契约。调用方可以通过MyThemeData / copyWith显式覆写字体。没有设置固定行高来掩盖混排度量差，也没有修改业务组件宽度或padding补偿文字。

字体名称声明不携带字体文件。运行宿主须提供所选字体；本轮同机Windows复验从C:/Windows/Fonts显式加载Times New Roman常规、粗体、斜体、粗斜体及中文回退，避免flutter_tester的Ahem。采集宿主已移除原Segoe UI覆写，实际字体来自MyTheme，不再由测试容器模拟主题默认值。

两端依然为DPR1、390/1440×900；截图物理像素与逻辑px/DIP一一对应。用户桌面175%缩放不参与这些受控截图。布局几何来自DOM/RenderBox，不把抗锯齿覆盖值当作标称设计尺寸。

### 9.3 glyph 实际绘制复验

[Loading修复前后放大图](round2/fix-proof-loading.png) · [Progress修复前后放大图](round2/fix-proof-progress.png) · [笔画覆盖记录](round2/glyph-pixel-coverage.json)

| 规格 | Flutter实际glyph | Web / Flutter笔画覆盖 | 居中 |
| --- | ---: | --- | --- |
| Loading small | 16×16 | 14×14 / 14×14 | 与16外框重合 |
| Loading medium | 24×24 | 20×20 / 20×20 | 与24外框重合 |
| Loading large | 32×32 | 28×28 / 28×28 | 与32外框重合；首轮实际24/笔画20缺陷已消除 |
| Progress line ✓ / ✗ | 18×18 | 标准矩阵保留真实绘制图 | 与18包装层同心 |
| Progress circle96 ✓ / ✗ | 26.88×26.88 | 比例绘制，见尺寸矩阵 | 与圆环同心；首轮1.44偏移已消除 |

Loading明暗均复测；浅色large笔画覆盖包含端点为[2,2,29,29]，与Web相同。28是物理笔画覆盖，标称尺寸仍是32。

| circle标称尺寸 | Flutter实际状态glyph | Web DOM实际状态SVG | 中心结论 |
| ---: | ---: | ---: | --- |
| 40 | 11.2 | 11.1875 | 两端均居中 |
| 64 | 17.92 | 17.90625 | 两端均居中 |
| 96 | 26.88 | 26.875 | 两端均居中 |
| 128 | 35.84 | 35.828125 | 两端均居中 |

DOM尺寸差均小于1/64px，符合浏览器布局量化粒度；这是对舍入来源的解释，不声称两端数值完全相同。回归测试包含同一挂载子树在这些尺寸间来回切换，验证size更新确实进入实际RenderBox。

### 9.4 字体复验数据与未达标项

Button完整原矩阵（primary / outline / text、icon / bare / round、selected、disabled、loading）已重拍四个宽度/主题条件；原有focus / hover / pressed补图也已重拍。Button link未在首轮截图矩阵内，本轮未扩展该视觉结论。

| Button（390明暗相同） | Web宽 | Flutter宽 | Flutter − Web |
| --- | ---: | ---: | ---: |
| Save 保存 | 90.921875 | 90.907714844 | −0.014160156 |
| Cancel | 69.656250 | 69.645507813 | −0.010742188 |

1440条件的两侧宽度各增加8px，字体宽度差保持不变。衬线字体形态已与同机Web同源；此前约1.8/2.16px的宽度差消除至小于0.015px。普通Skeleton loaded正文高度由首轮Flutter22变为20，与Web20一致。Tag、Card、Divider、Loading说明、Progress文字和Skeleton正文均有新图及真实字体记录。

**仍保留以下差异，不能把字体族对齐等同于严格视觉全面通过：**

| 残差 | 实测 | 判断与建议 |
| --- | --- | --- |
| Button文字基线 | Save：Web148、Flutter147.871582，差−0.128418px；Cancel：Web146.5、Flutter147.185303，差+0.685303px；四条件一致 | 小于1px但并非完全相同。Web用零尺寸baseline探针，非空文字探针前后布局变化为0；Flutter读取实际TextEngine基线。下一次在首批范围核对混排ascent/descent与组件显式行高，不用按钮宽度/padding补差。 |
| 默认Card高度 | mobile：174.78125 vs 177，Flutter高2.21875；desktop：183.140625 vs 185，高1.859375；明暗一致 | **未达到严格复刻。** 换字体后，不能沿用首轮不足1px的可接受描述。标题/说明的显式倍率行高及混排字体度量存在差异；这部分是后续定位方向，尚未证明单一原因。建议先做行盒与基线的独立对照，再决定最小修法。未修改Card或其padding。 |
| 字体度量与栅格 | Button宽差小于0.015px；圆环SVG尺寸差小于1/64px；抗锯齿、Divider标签行盒/虚线栅格仍非逐像素相同 | 记录为剩余绘制/量化差，不用RGB平均误差宣布通过；若要求逐像素一致，仍须后续验收。 |
| 既有宿主/绘制差 | Switch的Web UA外边距、Card阴影扩散、Divider虚线栅格 | 保留首轮已记录结论，本轮没有扩大修改范围。 |

[Web文字基线探针](round2/web-baselines.json) · [Flutter文字、实际glyph及普通Text继承](round2/flutter-metrics.json) · [Web DOM和文字](round2/web-metrics.json) · [全部精简数值](round2/measured-summary.json)

### 9.5 新图矩阵、执行与放行

| 新交付 | 数量 |
| --- | ---: |
| Web / Flutter基础截图：原8组件×4 + 圆环尺寸组×4，每侧36 | 72 |
| 原4交互组件的focus / hover / pressed补图，每侧24 | 48 |
| 并排对照：36基础 + 24状态 | 60 |
| 状态总览 | 8 |
| glyph修复前后放大证据 | 2 |
| 本轮PNG合计（全部解码、SHA-256留档） | **190** |

首轮208张PNG和原结论保留。最新图放round2/，原图库增加最新入口。没有重新采集未受修改影响的example实体页，首轮实体页原图仍可查看。这里的“全矩阵”指本轮已列出的原变体、宽度、主题矩阵，不外推未采集API组合或动画全时序。

沿用私有SDK/项目缓存，PUB_CACHE=D:/data/pub-cache，命令均使用--no-pub、--no-version-check、测试concurrency=1。命令执行器setup refresh仍不可用，使用Node fs/child_process执行既有方案。隔离环境缺少ProgramFiles(x86)的首轮启动错误已通过进程环境变量处理。所有应用渲染均为无头；没有操作用户现有应用、安装依赖或修改全局SDK。

重放入口为[round2-replay.ps1](run/round2-replay.ps1)。各阶段命令已分别实际运行成功；没有再把整段脚本整体重复执行。私有SDK和运行缓存留在run/，便于复现；本任务专用Vite服务在交付前关闭。

**放行结论：L1/P1已关闭；T1字体契约已固定，但Card行盒与Button基线仍有上述残差。整批严格视觉验收继续保留，不启动下一批46组件。**

交付路径限制：指定的 `.codex/my-ui-fix-last.md` 写入返回 `EPERM`，未更改权限；同内容汇报保存为 [my-ui-fix-last.md](my-ui-fix-last.md)。[最终自查](round2/final-validation.json)同时记录路径限制、分析/测试结果和首轮208张PNG未变的哈希复核。

图库运行复核：[60对图片切换与缩放检查](round2/gallery-validation.json)通过，pageErrors与failures均为空；验证使用专用临时静态服务与无头Chrome，结束后均已关闭。
