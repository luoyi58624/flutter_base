# Mobile

my-ui 移动端品牌实现，入口为 `package:flutter_base/mobile.dart`。`el.mobileComponents` 提供组件实现和明暗 token，应用自行配置原生字体及主题。

除输入框外，移动组件默认只提供指针与辅助技术交互，不创建可聚焦落点、不抢占焦点、不参与键盘导航。用户传入 `focusNode` 或声明 `onFocus` / `onFocusVisible` 焦点变体时，才通过 `ElView` 启用焦点与对应的键盘操作。默认外观提供手机按压反馈，鼠标悬停、键盘焦点环与宽屏桌面尺寸由调用方显式配置。

## 目录约定

对应通用接口的组件直接放在 `components/<组件名>/index.dart`，辅助文件与 README.md 留在组件目录。具体组件、Builder 和辅助函数采用普通内部命名，不从 mobile.dart 导出；用户调用通用 El* 接口。

没有通用品牌接口的组件放在 `components/others/<组件名>/`。独立的 ElBottomTabbar 保留公开入口；[Divider](components/others/divider/README.md) 的旧皮肤留在内部，不向独立的 ElDivider 基元添加品牌 Builder。

```dart
ElComponentProvider(
  components: el.mobileComponents,
  child: Column(children: [
    ElButton(child: '保存', onPressed: () {}),
    ElTag(child: '进行中'),
    ElSwitch(value: false, semanticLabel: '通知'),
    Text('移动端文本'),
  ]),
);
```

## 通用组件

| 通用声明 | 状态 | 实现边界 |
| --- | --- | --- |
| ElButton | 已接入 | 公共模型、动作只执行一次，内部实现提供移动端外观与反馈 |
| ElTag | 已接入 | 公共宿主持有切换；纯视觉 Builder 提供标签和独立关闭入口 |
| ElSwitch | 已接入 | bool / notifier / 表单字段绑定，以及尺寸、颜色、内容、加载与事件 |
| ElIcon | 已接入 | 字体图标的颜色、尺寸、状态和主题过渡均走 ElStyle 继承，不读取 IconTheme |
| ElCard | 已接入 | Widget 正文、style 外观、阴影档位、整卡点击、详细事件和加载状态 |
| ElListTile | 已接入 | 普通、开关、弹窗行，默认图标按 App 类型选择，模型只绑定一次 |
| ElListGroup | 已接入 | 默认、单选、多选，沿用索引分隔线与圆角容器，leading 控制标记位置 |
| ElLoadingIndicator | 已接入 | 数值尺寸、可见说明、根样式与加载语义 |
| ElProgress | 已接入 | Web 直线／圆环、完成量、缓冲量、不确定状态与读数插槽 |
| ElSkeleton | 已接入 | Web 行数及头像占位、减少动画与正文实例保留 |
| ElSlider | 已接入 | 连续跟手与离散业务值分离，触屏抬起提交、范围交叉、刻度与键盘操作 |
| ButtonGroup / Checkbox / Radio / Input / InputNumber / InputOtp / InputTag / Select / Autocomplete / Mention | 等待实现 | 当前没有对应移动端 Flutter 实现，未登记 Builder |
| Avatar / Empty / Alert / Steps / Segmented / Collapse / Tabs / Calendar / Slider | 等待实现 | 仅提供已收敛的共同接口，未登记占位布局 |

完整移动预设使用同一套组件表和 token。要单独覆写一项，可以嵌套 `ElComponentProvider(components: ElComponents(...))`。

## 内部实现

既有皮肤留在各自目录的 `index.dart`，用于通用接口实现及内部回归。LoadingIndicator、Progress、Skeleton 通过公共接口接入，具体实现不从移动端入口导出；现有通用 ElDivider 不增加无效参数。共用接口的准入与参数规范见[组件接口规范](../../flutter/components/README.md)。

列表由通用声明与 [mobile 列表实现](components/list_tile/README.md) 组成，示例直接使用 ElListTile / ElListGroup。

后代通过 `context.elTheme.primary` 按键读取主色。仅局部覆写 token 时，直接使用 `ElView(style: ElStyle(vars: {ElTokens.$primary: color}))`。

背景颜色按用途独立：`bgColor` 为页面背景（浅色 `#EEEEEE`），`cardColor` 为卡片与列表组背景（浅色白色），`cardPressColor` 为卡片、列表行和菜单项的按压背景（浅色 `#E0E0E0`），`dividerColor` 为分隔线（浅色 `#E0E0E0`）。`borderColor` 仅控制控件边框；`press` 继续用于其他控件。各 token 均可独立级联覆写，暗色表分别声明默认值。

五档阴影 `shadowXs / Sm / Md / Lg / Xl` 使用柔和漫射投影，以卡片和背景同色为校准基准。xs 为淡淡的单层小范围阴影，sm 稍重；md 是卡片档位，用近层 `0 1 / blur 5 / 6.5%` 支撑轮廓，远层 `0 4 / blur 14 / spread -1 / 6.5%` 柔和散开。浅色沿用原型冷灰 `#314669`，暗色独立使用黑色。lg 用于菜单和小弹窗，xl 用于模态窗口，逐步增加悬浮距离，不添加硬轮廓或白色描边。阴影示例背景跟随 cardColor，浅色为白底白卡、暗色为同色暗底暗卡。ElCard 默认无边框、无阴影，通过 `shadowLevel: .md` 使用卡片档位，用户仍可通过 style 覆写。
