# 旧 Flutter my_ui 审计

日期：2026-10-30。旧包根 O = D:/project/my-project/el/ui/my_ui；参照根 W = D:/project/html/my-ui。以下 O:/W: 均为绝对根的缩写，行号来自当前磁盘源码。仅有源码/测试证据，未运行旧包、未作设备截图验收，因此不把推断写成已复现视觉缺陷。

## 已实现范围

旧包 lib 共 13 个 Dart 文件（含入口），实现约 1.6 万行；5 个测试文件，另有工具和图标资源。旧 README 的 53 个组件与当前 Web 54 个导出不同，缺 ImagePreview（O:README.md:24-35；W:packages/vue/index.ts:9）。

| Web 组件 | 旧实现及证据 | 判定 |
| --- | --- | --- |
| AppBar | O:lib/src/layout.dart:1774 | 有实现；未经本轮运行/视觉验收 |
| Avatar | O:lib/src/primitives.dart:934 | 有实现；未经本轮运行/视觉验收 |
| Badge | O:lib/src/primitives.dart:1047 | 有实现；未经本轮运行/视觉验收 |
| Button | O:lib/src/primitives.dart:18 | 有实现；未经本轮运行/视觉验收 |
| Calendar | O:lib/src/picker.dart:1003 | 有实现；未经本轮运行/视觉验收 |
| Card | O:lib/src/layout.dart:4 | 有实现；未经本轮运行/视觉验收 |
| CellGroup | O:lib/src/layout.dart:409 | 有实现；未经本轮运行/视觉验收 |
| Checkbox | O:lib/src/choices.dart:84 | 有实现；未经本轮运行/视觉验收 |
| CheckboxGroup | O:lib/src/choices.dart:477 | 有实现；未经本轮运行/视觉验收 |
| Choices | O:lib/src/choices.dart:1774 | 有实现；未经本轮运行/视觉验收 |
| Collapse | O:lib/src/layout.dart:662 | 有实现；未经本轮运行/视觉验收 |
| CollapseItem | O:lib/src/layout.dart:735 | 有实现；未经本轮运行/视觉验收 |
| Combobox | O:lib/src/forms.dart:1304 | 有实现；未经本轮运行/视觉验收 |
| DatePicker | O:lib/src/picker.dart:757 | 有实现；未经本轮运行/视觉验收 |
| Dialog | O:lib/src/overlay.dart:2522 | 有实现；未经本轮运行/视觉验收 |
| Divider | O:lib/src/layout.dart:581 | 有实现；未经本轮运行/视觉验收 |
| Drawer | O:lib/src/overlay.dart:2637 | 有实现；未经本轮运行/视觉验收 |
| Empty | O:lib/src/primitives.dart:1346 | 有实现；未经本轮运行/视觉验收 |
| Floating | O:lib/src/overlay.dart:53 | 有实现；未经本轮运行/视觉验收 |
| Form | O:lib/src/forms.dart:4 | 有实现；未经本轮运行/视觉验收 |
| FormField | O:lib/src/forms.dart:105 | 有实现；未经本轮运行/视觉验收 |
| Icon | O:lib/src/icons.dart:4 | 有实现；未经本轮运行/视觉验收 |
| Image | O:lib/src/primitives.dart:706 | 有实现；未经本轮运行/视觉验收 |
| ImagePreview | O:lib/my_ui.dart:20-31 的全部part中无对应类；W:packages/vue/index.ts:9 | 缺失 |
| Input | O:lib/src/forms.dart:276 | 有实现；未经本轮运行/视觉验收 |
| ListRow | O:lib/src/layout.dart:251 | 有实现；未经本轮运行/视觉验收 |
| Loading | O:lib/src/primitives.dart:1169 | 有实现；未经本轮运行/视觉验收 |
| Menu | O:lib/src/overlay.dart:647 | 有实现；未经本轮运行/视觉验收 |
| Navigation | O:lib/src/choices.dart:621 | 有实现；未经本轮运行/视觉验收 |
| Notice | O:lib/src/layout.dart:1235 | 有实现；未经本轮运行/视觉验收 |
| Picker | O:lib/src/picker.dart:18 | 有实现；未经本轮运行/视觉验收 |
| Popover | O:lib/src/overlay.dart:519 | 有实现；未经本轮运行/视觉验收 |
| Popup | O:lib/src/overlay.dart:2339 | 有实现；未经本轮运行/视觉验收 |
| Progress | O:lib/src/layout.dart:859 | 有实现；未经本轮运行/视觉验收 |
| PullRefresh | O:lib/src/layout.dart:1997 | 有实现；未经本轮运行/视觉验收 |
| Radio | O:lib/src/choices.dart:135 | 有实现；未经本轮运行/视觉验收 |
| RadioGroup | O:lib/src/choices.dart:361 | 有实现；未经本轮运行/视觉验收 |
| Segmented | O:lib/src/choices.dart:580 | 有实现；未经本轮运行/视觉验收 |
| Select | O:lib/src/forms.dart:1176 | 有实现；未经本轮运行/视觉验收 |
| Sheet | O:lib/src/overlay.dart:2612 | 有实现；未经本轮运行/视觉验收 |
| Skeleton | O:lib/src/primitives.dart:1234 | 有实现；未经本轮运行/视觉验收 |
| Slider | O:lib/src/slider.dart:20 | 有实现；未经本轮运行/视觉验收 |
| Stepper | O:lib/src/choices.dart:1573 | 有实现；未经本轮运行/视觉验收 |
| Steps | O:lib/src/layout.dart:1460 | 有实现；未经本轮运行/视觉验收 |
| Switch | O:lib/src/choices.dart:4 | 有实现；未经本轮运行/视觉验收 |
| Tabbar | O:lib/src/choices.dart:658 | 有实现；未经本轮运行/视觉验收 |
| Tabs | O:lib/src/choices.dart:959 | 有实现；未经本轮运行/视觉验收 |
| Tag | O:lib/src/primitives.dart:436 | 有实现；未经本轮运行/视觉验收 |
| TagGroup | O:lib/src/primitives.dart:632 | 有实现；未经本轮运行/视觉验收 |
| Textarea | O:lib/src/forms.dart:1144 | 有实现；未经本轮运行/视觉验收 |
| TimePicker | O:lib/src/picker.dart:872 | 有实现；未经本轮运行/视觉验收 |
| Toast | O:lib/src/overlay.dart:3394 | 有实现；未经本轮运行/视觉验收 |
| Tooltip | O:lib/src/overlay.dart:218 | 有实现；未经本轮运行/视觉验收 |
| Upload | O:lib/src/upload.dart:182 | 有实现；未经本轮运行/视觉验收 |

## 已确认偏差与首批修复目标

| 项目 | 当前证据与原因 | 本轮处理 |
| --- | --- | --- |
| Button | O:lib/src/primitives.dart:20-36 无 type；selected 默认 false，无法保留 Web undefined 的 aria-pressed 区别；MyIcon 默认20而按钮需16/19/17/14（O:lib/src/icons.dart:6、29；W:packages/core/my-ui.css:221-327）；旧默认字行高1.5为额外假定（O:lib/src/primitives.dart:132）。 | nullable selected；保留 type 与 Flutter Form submit/reset 映射；显式图标尺寸；不宣称系统字体等像素一致。 |
| Tag | O:lib/src/primitives.dart:438-449 有 onClose/icon 等扩展但无 click；W:packages/vue/components/Tag.vue:14-19 有 change 后 click，W:packages/core/my-ui.js:1323-1326。固定 height 而 Web min-height（O:lib/src/primitives.dart:493-494；W:packages/core/my-ui.css:463、503）。 | change → click；min-height；外层命中与内层缩放分开。 |
| Switch | O:lib/src/choices.dart:76 禁用 opacity .6，Web Switch CSS 无此规则（W:packages/core/my-ui.css:546-579）；O:lib/src/choices.dart:34-36 无 --switch-thumb-background 覆写。 | 保留47×28/22/3/19几何；去额外透明度；恢复 thumb token；仅 Space 切换。 |
| Card | O:lib/src/layout.dart:6-18 未暴露 delayTouchDown/Up；sample 字号/顶部间距固定10/6、标题行间距固定18（O:lib/src/layout.dart:124、150-153），漏 <=760 的7与 <=400 的9/0/10规则（W:packages/core/my-ui.css:3737-3751）。 | 添加时序参数、完整断点与交互标题隐藏规则。 |
| Divider | O:lib/src/layout.dart:640 只有 label，无 separator/orientation；竖线默认15（O:lib/src/layout.dart:612），Web 1em=13（W:packages/core/my-ui.css:4112、4141）。文本仅String，丢默认Widget插槽。 | separator语义、Widget插槽、13px默认竖线及完整变量。 |
| Loading | O:lib/src/primitives.dart:1173 size为double，Web为三档；O:lib/src/primitives.dart:1214 未声明status语义。 | size枚举与16/24/32，status/liveRegion，默认名称与可见插槽对应。 |
| Skeleton | O:lib/src/primitives.dart:1278 加载时移除child，Web隐藏body但仍保留实例（W:packages/core/my-ui.js:2215-2236）；rows=0旧版clamp成1，Web floor(rows)||3 为3；首行间距18与Web实际折叠结果一致（2026-10-30无头Edge断言，骨架默认高123），该项不是缺陷。 | 保留child状态/焦点隔离；0回退3；保留18px首行间距。 |
| Progress | O:lib/src/layout.dart:908 只接受固定child，缺W:packages/core/my-ui.js:5782的 value/max/percentage插槽scope；轨道/缓冲token未单独暴露；O:lib/src/layout.dart:960-968仅label/value，未声明progressIndicator角色。 | 类型化读数builder、全变量、归一化和语义，圆环几何及动画。 |
| Theme / 组织 | O:lib/my_ui.dart:20-31 全part共享私有域，O:README.md:20 仍宣传 vars/ElStyle.builder，但本仓库 ElStyle 构造无vars（lib/src/ui/cores/view/style/style.dart:17-98）；O:lib/src/palette.dart:120-123 部分组件token。 | 沿当前 ui 的独立导入/分层/export约定，主题提供实际类型值，不携带已失效API。 |

## 其他模块：现状与后续检查点

- Input/Textarea：真实ElEditableView/FormField集成已存在，不应判为占位。O:lib/src/forms.dart:276-420、835-1011；868-869 含 `|| null != null` 无意义分支，需重建布局条件；Web label/id/autocomplete 为完整浏览器契约（W:packages/vue/components/Input.vue:6-38），Flutter需逐项映射而非复制DOM属性。
- 选择/导航：Radio/Checkbox/组、Tabs、Navigation/Tabbar、Stepper均有实现和键盘逻辑（O:lib/src/choices.dart:84-1866）；须跟W:tests/selection-collapse.browser.html、tabbar.browser.html核对跳过禁用、焦点和节点保留。旧有测试存在，不证明当前Flutter内核兼容。
- Slider：O:lib/src/slider.dart:20-140 分拆单/范围API、额外预览事件；valueLabelFormat只收value（129），Web收value,index（W:packages/vue/components/Slider.vue:22-24）。后续必须补索引契约与全部轨道/拇指变量。
- Picker/Date/Time/Calendar：O:lib/src/picker.dart:18-1646 有滚轮、惯性、级联、年月修正、范围日历；W:tests/date-time.test.mjs、picker-value.test.mjs是纯值真源，先移植它们的边界再迁移UI。
- Floating：O:lib/src/overlay.dart:53-113 用controller而非modelValue/anchor，未公开positioned事件；W:packages/vue/components/Floating.vue:7-24。因此属于平台适配差异，不能直接认定props对齐。
- Menu/Tooltip/Popover：O:lib/src/overlay.dart:218-2216 有悬停/长按/级联/离场，不是空壳；需W:tests/menu-pointer.browser.html、menu-cascade.browser.html、feedback-primitives.browser.html验证焦点与事件顺序。
- Dialog/Sheet/Drawer/Popup/Toast：O:lib/src/overlay.dart:2217-3924 包含异步句柄、生命周期和模态宿主；不能删除退场完成语义或改为立即返回（W:packages/core/my-ui.d.ts:82-106、147-156）。
- Upload：O:upload.dart:182-264 属性/回调/控制器较完整；依赖desktop_drop/file_selector/unorm等仅存在旧包（O:lib/my_ui.dart:7-16）；新模块基础阶段无需引入。后续核对AbortSignal与task.onCancel的平台映射、迟到结果与URL释放（W:README.md:166-185）。
- Avatar/Image/Badge/Empty/Icon：O:lib/src/primitives.dart:706-1167、1346-1440、icons.dart:1-296 有本地图标路径和图片生命周期；缺ImagePreview，不应把Image加载验收当预览缩放验收。

## 阅读覆盖与证据限制

已通过只读工具载入所有 lib/test/tool 源码、pubspec、README，建立逐类入口索引；本审计只对上述明确可定位的差异下结论。旧测试未在本轮运行，未证实其当前通过；未收集屏幕/设备观测，“可能视觉不一致”不等于已复现。

| 旧文件 | 行数 | 责任 |
| --- | --- | --- |
| O:lib/my_ui.dart:1 | 32 | 入口/模型/工具/契约测试 |
| O:lib/src/choices.dart:1 | 1866 | MySwitch、MyCheckbox、MyRadio、_ChoiceControl、MyRadioGroup、_RadioGroupState、MyCheckboxGroup、_ChoiceGroup、MySegmented、MyNavigation、MyTabbar、_NavigationOptions、_NavigationState、MyTabs、_TabsState、_TabHeightCache、_TabViewportSizer、_TabViewportSizerRender、_NaturalTabPage、_NaturalTabPageRender、_TabIndicator、_TabStrip、_TabStripParentData、_TabStripRender、MyStepper、_StepperState、MyChoices |
| O:lib/src/forms.dart:1 | 1968 | MyForm、_InlineFormFields、_FormScope、MyFormField、MyInput、MyInputState、_TextareaGrip、_TextareaGripRender、_InputAction、MyTextarea、MySelect、MyCombobox、_SelectState、_SelectOption |
| O:lib/src/icons.dart:1 | 296 | MyIcon、_VectorGlyph、_VectorGlyphRender |
| O:lib/src/layout.dart:1 | 2205 | MyCard、_ListItemScope、_ListSurface、MyListRow、MyCellGroup、_CellGroupState、MyDivider、MyCollapse、_CollapseScope、MyCollapseItem、MyProgress、_ProgressArc、_ArcClipper、MyNotice、_NoticeState、MySteps、_StepsState、MyAppBar、_AppBarState、_AppBarLayoutView、_AppBarParentData、_AppBarRender、MyPullRefresh、MyPullRefreshState、_RefreshIndicator、_MyRefresher |
| O:lib/src/models.dart:1 | 121 | MyOption、MyMenuOption、MyStepOption |
| O:lib/src/overlay.dart:1 | 3924 | MyFloating、_FloatingSurface、_FloatingSurfaceState、MyTooltip、_TooltipState、_TooltipClipper、MyPopover、_PopoverState、_MenuSession、_MenuStackGeometry、_MenuStackLayout、MyMenuController、MyMenu、_MenuState、_MenuPanel、_MenuPanelState、_MenuMotion、_MenuMotionState、_MenuSizeObserver、_MenuSizeRender、_MenuCascadeClipper、MyPopupHandle、MyPopupActions、MyPopup、MyDialog、MySheet、MyDrawer、_DialogState、_ModalFrame、_ModalFrameState、_ModalSurface、_ModalSurfaceState、_ModalMotion、_ModalMotionState、MyToast、_PopupOverlay、_PopupOverlayState、_PopupPhase、_PopupRoute、_MenuEntry、_MenuLayers、_MenuLayersHost、_MenuLayersHostState、_CoordinateMenu、_CoordinateMenuState、_ToastEntry、_ToastLifetime、_ToastLifetimeState |
| O:lib/src/palette.dart:1 | 378 | MyThemeData、_MyThemeScope |
| O:lib/src/picker.dart:1 | 1646 | MyPickerOption、MyPicker、_PickerState、_PickerWheel、_WheelState、_WheelPosition、_WheelPositionRender、MyDatePicker、_DatePickerState、MyTimePicker、_TimePickerState、MyCalendar、_CalendarState |
| O:lib/src/primitives.dart:1 | 1440 | MyButton、_Pressable、_PressableState、MyTag、MyTagGroup、MyImage、MyImageState、MyAvatar、MyBadge、MyLoading、MySkeleton、MyEmpty |
| O:lib/src/slider.dart:1 | 929 | MySliderMark、MySlider、_SliderState、_SliderTooltipClipper |
| O:lib/src/theme.dart:1 | 101 | MyApp |
| O:lib/src/upload.dart:1 | 1009 | MyUploadFile、MyUploadRejection、MyUploadRequestContext、MyUploadController、MyUpload、_UploadState、_UploadPreview、_UploadPreviewState |
| O:test/controls_contract_test.dart:1 | 764 | 入口/模型/工具/契约测试 |
| O:test/interaction_test.dart:1 | 597 | 入口/模型/工具/契约测试 |
| O:test/navigation_test.dart:1 | 290 | 入口/模型/工具/契约测试 |
| O:test/overlay_upload_contract_test.dart:1 | 480 | 入口/模型/工具/契约测试 |
| O:test/visual_forms_contract_test.dart:1 | 572 | 入口/模型/工具/契约测试 |
| O:tool/build_icons.py:1 | 139 | FlattenPen、MyIcon |
| O:tool/icons.json:1 | 36 | 入口/模型/工具/契约测试 |
