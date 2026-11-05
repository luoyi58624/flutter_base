# 临时 Material 实现

现有组件声明保持不变。桌面、移动预设先安装这套内部替代，再用各自已有的品牌实现覆盖；业务仍只使用公开的 `El*` 组件，不导出新的组件接口。

| 现有接口 | 官方替代 |
| --- | --- |
| Input / Select / Autocomplete | TextField / DropdownMenu / Autocomplete |
| Checkbox / Radio | 只提供官方视觉，选择、语义和分组继续由公共声明负责 |
| Card / LoadingIndicator | Card / CircularProgressIndicator |
| ListTile / ListGroup | ListTile / Switch / PopupMenuButton / Checkbox / Radio |
| Progress / Slider | LinearProgressIndicator、CircularProgressIndicator / Slider、RangeSlider |
| Avatar / Calendar | CircleAvatar、ClipRRect / CalendarDatePicker、showDateRangePicker |
| Collapse / CollapseItem | ExpansionTile |
| Segmented / Steps / Step | SegmentedButton / Stepper、ListTile |
| Tabs / TabBar | TabBar、TabBarView；独立标签栏适配现有 ElTabController |
| Alert | MaterialBanner |

这里只承接基础显示、常用值绑定、禁用、选择和关闭，不宣称完成品牌迁移。已有品牌实现始终优先，输入之外的移动替代默认排除键盘焦点。

临时边界：输入不适配 ElEditable 专属控制器和底层平台回调；选择器与自动补全的候选布局、浮层锚点和高级键盘配置使用官方默认；日历首日取官方本地化设置，范围选择使用对话框；独立标签栏的自定义指示器和文字 ElStyle 使用官方默认；滑块自定义刻度与交互事件取消语义不在这次临时包装中补造。需要这些能力时继续实现对应品牌，不向公共声明添加兼容参数。

没有直接官方对应的 Empty 保持未实现；移动端 InputNumber、InputOtp、InputTag、Mention，以及桌面端 Skeleton 继续保留已有缺口。示例按当前预设检查实现，缺失时保留空白页。
