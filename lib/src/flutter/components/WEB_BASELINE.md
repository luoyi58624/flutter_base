# my-ui Web 接口基准

公开行为以 `D:/project/html/my-ui/packages/vue/components/` 的参数声明、`packages/core/my-ui.js` 的实际交互和对应测试为基准。Vue 是薄封装，不能仅凭组件名搬接口；桌面、移动共用职责和业务值，布局与外观分别由品牌实现。

## 共用语义与 Flutter 对应

| Web | Flutter 对应 | 边界 |
| --- | --- | --- |
| Button / Tag / Switch | ElButton / ElTag / ElSwitch | 复用既有值绑定、事件、禁用和加载语义 |
| Input / Textarea | ElInput | 多行属于输入配置；表单说明不重复放进每个控件 |
| Form / FormField | ElForm / ElFormItem | 复用现有表单，不复制 DOM 的 id/name/aria 协议 |
| Radio / Checkbox / 各自 Group | 现有单选、多选接口及 Group | 自由 child，不增加选项注册协议 |
| Choices | Radio、Checkbox、ElListTileGroup 组合 | 不另造同职责的综合组件 |
| Stepper / Combobox | ElInputNumber / ElAutocomplete | 对齐步骤数值和搜索选择职责，保留既有桌面实现 |
| Select / Segmented | ElSelect / ElSegmented | 保留业务泛型，不限制 String |
| ListRow / CellGroup | ElListTile / ElListTileGroup | 保留已审定的直接 children 与完整模型绑定 |
| Popover | ElListTile.popup 的单选菜单 | 树选项、定位、键盘、层叠和收起时序由内部菜单承担 |
| Menu / Floating | 菜单行为与 ElPortal / ElOverlayAnchor | 菜单模式和浮层机制分开，不为列表行加入右键、多选等参数 |
| Card / Loading / Progress / Skeleton | 对应 El* 共用接口 | 直接复用已有 mobile 皮肤；不保留 Web 没有的空形态 |
| Avatar / Icon / Empty / Notice | ElAvatar / ElIcon / ElEmpty / ElAlert | Notice 不另造名称；错误空态不再由 Result 重复表达 |
| Tabs | ElTabs / ElTabBar / ElTabView | 值、禁用、滑动和内容共用，去掉增删页及侧栏形态 |
| Steps / Collapse | ElSteps / ElStep、ElCollapse / ElCollapseItem | 步骤用固定下标，折叠组使用完整单值或 List 模型 |
| Calendar / Slider | ElCalendar / ElSlider | 单值和范围使用完整模型，删除 Material 专属皮肤参数 |
| Image / ImagePreview | 现有 ElImageView、ElPreviewView、ElZoomView | 复用图片、预览和缩放机制，不再创建一套占位声明 |
| Badge / Divider | 现有 ElBadge / ElDivider | 品牌旧皮肤与通用基元的参数差异须实际适配，不能直接等同 |
| TagGroup / Tooltip / Upload | 后续按真实使用补齐 | Web 职责可跨端，但当前缺完整 Flutter 适配，不以空实现登记为已支持 |

已有 InputOtp、InputTag、Mention 等实际桌面实现继续保留；本轮删除针对新增的额外空声明，不回退已有能力。

## 不进入共同组件接口

- AppBar、Navigation、Tabbar 属于各端应用导航和页面骨架，独立的 ElBottomTabbar 保留移动端公开入口。
- PullRefresh 复用滚动与 Refresher 机制，不要求桌面端提供触屏同形态皮肤。
- Picker、DatePicker、TimePicker 当前 Web 实现是惯性滚轮；滚轮形态留在移动端，不借日期选择的名字强塞共同接口。
- Dialog、Drawer、Sheet、Toast、Popup 按反馈服务和宿主职责组织，不混入选项菜单或普通组件 Builder。Sheet 的底部交互形态与动作选择语义需要分别处理。
- Anchor、Affix、Backtop、Carousel、Countdown、Descriptions、Pagination、Rate、Statistic、Timeline、Result 在 Web 无对应且原来没有品牌实现，本轮移除声明、导出和登记；这不表示同名功能在所有产品中都不能跨端。

## 实现约束

- 模型只由已有 ElModelValue 或表单机制持有，品牌不能另绑一份；多选泛型表示完整 List 模型，业务值可以是枚举、数字或值对象。
- 同一接口不要求两端提供同一种导航、尺寸或鼠标交互。桌面尺寸使用 compact，mobile 默认只提供触屏按压外观。
- 共用接口只有实际接通的品牌 Builder 才登记；不能忽略参数、填空 Widget 或借用另一端皮肤来声称支持。
- mobile 的当前支持状态以 [Mobile](../../ui/mobile/README.md) 为准，通用接口存在不等于品牌已经实现。
