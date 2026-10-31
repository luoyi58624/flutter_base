# Desktop

Element Plus 桌面品牌实现，源码来自 `D:/project/my-project/el/ui/element_plus`。通用声明、值绑定基类、视图与编辑内核仍使用 flutter_base，品牌目录保留源组件的布局、配色、动效和交互实现。

## 安装

```dart
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

ElDesktopTheme(
  size: ElLevelType.md,
  child: Column(children: [
    ElButton(onPressed: () {}, type: ElThemeType.primary, child: '保存'),
    ElInput(value: '', placeholder: '请输入名称'),
  ]),
);
```

`ElDesktopTheme` 安装明暗主题、根样式、通用组件 Builder 和输入候选层需要的官方 Overlay。它负责品牌安装；源 ElApp 的消息、通知、对话框、抽屉服务以及平台菜单注册没有迁入，也不通过应用根隐式创建。

主题宿主放在 MaterialApp / WidgetsApp 的内容树中，由 Flutter 应用提供默认键盘遍历、输入与导航环境。

## 已接入的接口

| 通用接口 | 品牌实现目录 |
| --- | --- |
| Button | [basic/button](components/basic/button/README.md) |
| ButtonGroup | [basic/button_group](components/basic/button_group/README.md) |
| Tag | [basic/tag](components/basic/tag/README.md) |
| Switch | [form/switch](components/form/switch/README.md) |
| Input | [form/input](components/form/input/README.md) |
| InputNumber | [form/input_number](components/form/input_number/README.md) |
| InputOtp | [form/input_otp](components/form/input_otp/README.md) |
| InputTag | [form/input_tag](components/form/input_tag/README.md) |
| Select | [form/select](components/form/select/README.md) |
| Autocomplete | [form/autocomplete](components/form/autocomplete/README.md) |
| Mention | [form/mention](components/form/mention/README.md) |
| Text / FormItem | [主题登记](components/app/README.md)，透传源品牌的文本和表单项实现 |
| TableStyle | [data/table](components/data/table/README.md)，仅提供表格皮肤 |

Element 图标及内容归一化作为上述实现的内部依赖迁入，不增加新的通用组件声明。图标字体 family 仍为 element，字体包归属改为 flutter_base。

## 主题与覆盖

`ElThemeData` 保留源主题的实际类型值和明暗默认表，`ElTheme` 用于局部主题或尺寸覆盖。`ElementPlusThemeData` 是可直接传给 ElComponentProvider 的实现预设；ElDesktopTheme.componentBuilders 在品牌预设上合并非空实现。组件的显式 style 沿源实现的合并顺序覆盖默认外观。

```dart
ElDesktopTheme(
  theme: ElThemeData(primary: Color(0xff2454c6)),
  darkTheme: ElThemeData.dark().copyWith(primary: Color(0xffaac8ff)),
  child: ElTheme(size: ElLevelType.sm, child: ElButton(child: '紧凑按钮')),
);
```

## 等待接口的组件

- Radio、Checkbox：State 已声明可空 isLast，但当前宿主尚未提供实际末项信息；两个品牌 Builder 继续保持 null，不用默认布尔值伪造布局状态。
- Card、Avatar、Pagination、Tabs 等两端通用组件的声明已补齐，当前仍未安装相应品牌实现。端专属导航与布局不再进入通用登记表，筛选范围见[通用声明说明](../../flutter/components/DECLARATIONS.md)。消息、提示、对话框等服务 API 另行处理。

迁移只调整包与文件引用、字体归属和 Portal 阶段枚举名称（ElPresencePhase → ElPortalPhase）；不依赖旧 element_plus、el_ui、el_flutter 或 el_dart 包。源许可见 [LICENSE](LICENSE)。

## 验证范围

迁入 14 份源局部回归测试，目标目录共 170 项通过，覆盖主题登记、按钮与按钮组、Tag、Switch、输入控制器、Select、Autocomplete、InputNumber、InputTag、OTP、Mention 和表格皮肤。

源仓库 5 个具名失败用例在迁移前基线中同样失败：测试未提供标准应用焦点环境、把局部尺寸主题放在应用安装器外，以及仍用已排除的逐格语义判断 OTP active。迁入测试补齐应用环境、调整主题注入层级，并保留几何与选区断言；生产组件没有为此改写行为。

以上是无头局部验证，不包含源库完整回归或真实窗口视觉验收。
