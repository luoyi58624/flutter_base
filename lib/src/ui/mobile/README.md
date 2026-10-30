# Mobile

my-ui 移动端品牌实现，入口为 `package:flutter_base/mobile.dart`。`MyTheme` 提供 CSS 对应的明暗颜色、字体和阴影，并安装通用组件实现。

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

既有 MyButton、MyTag、MySwitch、MyCard、MyDivider、MyLoading、MyProgress、MySkeleton 均迁入各自目录的 `index.dart`，已有 My* 参数和行为保留。后五项缺少对应通用组件声明或 Builder 插槽，因此只保留品牌 API，不为适配新增公共接口。

MyThemeData、外部 notifier 与焦点节点仍按原有生命周期管理。现有颜色、几何、事件测试保留；本次验证为无头测试，不代表手机视觉和输入设备验收。
