# Mobile

my-ui 移动端品牌实现，入口为 `package:flutter_base/mobile.dart`。`MyTheme` 提供 CSS 对应的明暗颜色、字体和阴影，并安装通用组件实现。

## 目录约定

对应通用接口的组件直接放在 `components/<组件名>/index.dart`，辅助文件与 README.md 留在组件目录。Card、LoadingIndicator、Progress、Skeleton 等已有通用声明但尚未适配的组件也保留在这一层；MyLoading 对应 LoadingIndicator 的加载指示职责。

没有通用品牌接口的组件放在 `components/others/<组件名>/`。MyDivider 位于 [others/divider](components/others/divider/README.md)，公共导出与原有行为保持不变，不向独立的 ElDivider 基元添加品牌 Builder。

```dart
MyTheme(
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
| ElButton | 已接入 | 公共模型、动作只执行一次，MyButton 提供移动端外观与反馈 |
| ElTag | 已接入 | 公共宿主持有切换；纯视觉 Builder 提供标签和独立关闭入口 |
| ElSwitch | 已接入 | bool / notifier / 表单字段绑定，以及尺寸、颜色、内容、加载与事件 |
| ElText | 已接入 | 全部 Text 参数原样转交，继承 MyTheme 默认字体 |
| ButtonGroup / Checkbox / Radio / Input / InputNumber / InputOtp / InputTag / Select / Autocomplete / Mention | 等待实现 | 当前没有对应移动端 Flutter 实现，未登记 Builder |

`MyTheme.componentBuilders` 在默认的 `myComponentBuilders` 上合并非空覆写。每个 MyTheme 安装自己的完整品牌配置，未实现项不会隐式借用祖先桌面实现。

## 保留的品牌组件

既有 MyButton、MyTag、MySwitch、MyCard、MyDivider、MyLoading、MyProgress、MySkeleton 均迁入各自目录的 `index.dart`，已有 My* 参数和行为保留。Card、LoadingIndicator、Progress、Skeleton 的通用声明现已补齐，品牌适配尚未接入；MyDivider 继续保留其品牌接口，现有通用 ElDivider 不增加无效参数。

MyThemeData、外部 notifier 与焦点节点仍按原有生命周期管理。现有颜色、几何、事件测试保留；本次验证为无头测试，不代表手机视觉和输入设备验收。
