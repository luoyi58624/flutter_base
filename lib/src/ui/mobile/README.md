# Mobile

my-ui 移动端品牌实现，入口为 `package:flutter_base/mobile.dart`。`ElMobileTheme` 提供明暗颜色和阴影，并安装通用组件实现；字体沿用 Flutter／平台默认，不预设字体族、回退列表或可变字体轴。

默认外观只提供手机按压反馈，不附带鼠标悬停、键盘焦点环或宽屏桌面尺寸。需要这些外观时可由调用方显式声明 `ElStyle` 变体；键盘动作、焦点节点与辅助技术语义仍保留。

## 目录约定

对应通用接口的组件直接放在 `components/<组件名>/index.dart`，辅助文件与 README.md 留在组件目录。具体组件、Builder 和辅助函数采用普通内部命名，不从 mobile.dart 导出；用户调用通用 El* 接口。

没有通用品牌接口的组件放在 `components/others/<组件名>/`。独立的 ElBottomTabbar 保留公开入口；[Divider](components/others/divider/README.md) 的旧皮肤留在内部，不向独立的 ElDivider 基元添加品牌 Builder。

```dart
ElMobileTheme(
  child: Column(children: [
    ElButton(child: '保存', onPressed: () {}),
    ElTag(child: '进行中'),
    ElSwitch(value: false, semanticLabel: '通知'),
    ElText('移动端文本'),
  ]),
);
```

## 通用组件

| 通用声明 | 状态 | 实现边界 |
| --- | --- | --- |
| ElButton | 已接入 | 公共模型、动作只执行一次，内部实现提供移动端外观与反馈 |
| ElTag | 已接入 | 公共宿主持有切换；纯视觉 Builder 提供标签和独立关闭入口 |
| ElSwitch | 已接入 | bool / notifier / 表单字段绑定，以及尺寸、颜色、内容、加载与事件 |
| ElText | 已接入 | 全部 Text 参数原样转交，继承 ElMobileTheme 默认字体 |
| ElCard | 已接入 | 标题、说明、正文、整卡交互、加载状态与辅助名称 |
| ElListTile | 已接入 | 普通、开关、弹窗行，默认图标按 App 类型选择，模型只绑定一次 |
| ElListTileGroup | 已接入 | 默认、单选、多选，沿用索引分隔线与圆角容器，leading 控制标记位置 |
| ElLoadingIndicator | 已接入 | 数值尺寸、可见说明、根样式与加载语义 |
| ElProgress | 已接入 | Web 直线／圆环、完成量、缓冲量、不确定状态与读数插槽 |
| ElSkeleton | 已接入 | Web 行数及头像占位、减少动画与正文实例保留 |
| ButtonGroup / Checkbox / Radio / Input / InputNumber / InputOtp / InputTag / Select / Autocomplete / Mention | 等待实现 | 当前没有对应移动端 Flutter 实现，未登记 Builder |
| Avatar / Icon / Empty / Alert / Steps / Segmented / Collapse / Tabs / Calendar / Slider | 等待实现 | 仅提供已收敛的共同接口，未登记占位布局 |

`ElMobileTheme.componentBuilders` 在内部默认配置上合并非空覆写。每个 ElMobileTheme 安装自己的完整品牌配置，未实现项不会隐式借用祖先桌面实现。

## 内部实现

既有皮肤留在各自目录的 `index.dart`，用于通用接口实现及内部回归。LoadingIndicator、Progress、Skeleton 通过公共接口接入，具体实现不从移动端入口导出；现有通用 ElDivider 不增加无效参数。共用接口的逐项来源和待适配缺口见 [Web 接口基准](../../flutter/components/WEB_BASELINE.md)。

列表由通用声明与 [mobile 列表实现](components/list_tile/README.md) 组成，示例直接使用 ElListTile / ElListTileGroup。

主题通过 `ElMobileTheme(style: ElStyle(vars: {ElTheme.$primary: color}))` 注入，后代通过 `context.elTheme.primary` 按键读取；局部覆写直接使用 ElView.vars。外部 notifier 与焦点节点仍按原有生命周期管理。现有颜色、几何、事件测试保留；本次验证为无头测试，不代表手机视觉和输入设备验收。
