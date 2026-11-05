# Desktop

Element Plus 桌面品牌实现，源码来自 `D:/project/my-project/el/ui/element_plus`。通用声明、值绑定基类、视图与编辑内核仍使用 flutter_base，品牌目录保留源组件的布局、配色、动效和交互实现。

## 目录约定

对应通用组件接口的实现直接放在 `components/<组件名>/index.dart`，不再按 basic、form、data 分类。组件内部的辅助文件与 README.md 保留在各自目录中；测试按相同组件层级组织。

桌面预设集中在 `components/index.dart`。端专属组件放在 `components/others/<组件名>/`。

## 安装

```dart
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

ElComponentProvider(
  components: el.desktopComponents,
  child: Column(children: [
    ElButton(onPressed: () {}, type: ElThemeType.primary, child: '保存'),
    ElInput(value: '', placeholder: '请输入名称'),
  ]),
);
```

桌面预设提供组件实现和明暗 token。应用提供键盘遍历、Overlay、输入和导航环境。

## 已接入的接口

| 通用接口 | 品牌实现目录 |
| --- | --- |
| Button | [button](components/button/README.md) |
| ButtonGroup | [button_group](components/button_group/README.md) |
| Tag | [tag](components/tag/README.md) |
| Switch | [switch](components/switch/README.md) |
| Input | [input](components/input/README.md) |
| InputNumber | [input_number](components/input_number/README.md) |
| InputOtp | [input_otp](components/input_otp/README.md) |
| InputTag | [input_tag](components/input_tag/README.md) |
| Select | [select](components/select/README.md) |
| Autocomplete | [autocomplete](components/autocomplete/README.md) |
| Mention | [mention](components/mention/README.md) |
| FormItem | [桌面预设](components/index.dart)，沿用源品牌的表单项实现 |
| TableStyle | [table](components/table/README.md)，仅提供表格皮肤 |

Element 图标及内容归一化作为上述实现的内部依赖迁入，尚未安装通用 iconBuilder。图标字体 family 仍为 element，字体包归属改为 flutter_base。

## 主题与覆盖

`context.elTheme` 从 ElView 的级联变量按键读取实际值。局部可以通过 `ElStyle.vars` 覆写 token 或桌面密度。

```dart
ElComponentProvider(
  components: el.desktopComponents,
  child: ElView(
    style: ElStyle(
      vars: {ElTokens.$primary: Color(0xff2454c6), ElementPlusThemeData.$compact: true},
      onDark: ElStyle(vars: {ElTokens.$primary: Color(0xffaac8ff)}),
    ),
    child: ElButton(child: '紧凑按钮'),
  ),
);
```

普通／紧凑默认高度分别为：按钮与输入框 36／32、Tag 与 Switch 26／24、表格行高 40／36。数字输入框及 OTP 保留自身的 32／24 几何。显式 style、height、padding 或 fontSize 继续覆盖预设。

## 等待接口的组件

- Radio、Checkbox：State 已声明可空 isLast，但当前宿主尚未提供实际末项信息；两个品牌 Builder 继续保持 null，不用默认布尔值伪造布局状态。
- 两端通用组件的准入、注入与参数规范见[组件接口规范](../../flutter/components/README.md)；桌面专属组件留在本目录。消息、提示、对话框等服务 API 另行处理。

迁移只调整包与文件引用、字体归属和 Portal 阶段枚举名称（ElPresencePhase → ElPortalPhase）；不依赖旧 element_plus、el_ui、el_flutter 或 el_dart 包。源许可见 [LICENSE](LICENSE)。

## 验证范围

迁入 14 份源局部回归测试，目标目录共 170 项通过，覆盖主题登记、按钮与按钮组、Tag、Switch、输入控制器、Select、Autocomplete、InputNumber、InputTag、OTP、Mention 和表格皮肤。

源仓库 5 个具名失败用例在迁移前基线中同样失败：测试未提供标准应用焦点环境、把局部尺寸主题放在应用安装器外，以及仍用已排除的逐格语义判断 OTP active。迁入测试补齐应用环境、调整主题注入层级，并保留几何与选区断言；生产组件没有为此改写行为。

以上是无头局部验证，不包含源库完整回归或真实窗口视觉验收。
