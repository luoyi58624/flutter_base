# Components

组件按用途分目录，每个目录以 `index.dart` 为入口，`README.md` 说明当前接口和组合方式。Radio 与 Checkbox 的分组实现分别位于各自目录的 `group.dart`。

只有桌面端与移动端都适用、职责一致的组件才能进入本目录；端专属组件由对应品牌目录提供，不在通用登记表中预留空实现。通用声明按品牌逐步接入，实际支持清单见各品牌目录；完整分类与服务边界见 [声明扩充范围](DECLARATIONS.md)。

## 导入与实现登记

使用组件时导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。本目录组件通过祖先 `ElComponentProvider` 中对应的 Builder 提供品牌实现；下列示例均假定已经登记所需实现。移动端由 ElMobileTheme 安装默认实现，具体组件与 Builder 不从 mobile.dart 导出。

```dart
ElComponentProvider(
  builders: ElComponentBuilders(
    textBuilder: (context, component) => Text(
      component.data,
      style: component.style,
    ),
  ),
  child: ElText('你好'),
);
```

Builder 的职责依组件而定：Input、Switch、Select 等把具体绑定与交互交给实现；Button 在公共层提供模型与激活动作；Tag、Radio、Checkbox 在公共层组织交互，Builder 提供外观。Radio、Checkbox 的 Builder 还接收各自的有效状态快照。

`ElComponentBuilders.merge` 用非空实现覆盖已有实现；`copyWith` 省略参数时保留原值，显式传 null 清空该项。`ElComponentProvider` 使用传入的完整配置，需要继承时先显式合并。

## 组件目录

| 组件 | 说明 |
| --- | --- |
| [Autocomplete](autocomplete/README.md) | 输入文本并获取异步建议 |
| [Button](button/README.md) | 普通按钮与独立布尔按钮 |
| [ButtonGroup](button_group/README.md) | 普通、单选、多选按钮组 |
| [Checkbox](checkbox/README.md) | 多选项、独立开关与多选分组 |
| [Input](input/README.md) | 单行、多行与输入连接配置 |
| [InputNumber](input_number/README.md) | 步进、范围和精度配置 |
| [InputOtp](input_otp/README.md) | 定长验证码输入 |
| [InputTag](input_tag/README.md) | 将文本确认为标签列表 |
| [ListTile](list_tile/README.md) | 普通、开关、弹窗列表行及单选、多选分组 |
| [Mention](mention/README.md) | 前缀匹配、候选项与完整提及 |
| [Radio](radio/README.md) | 单选项、独立开关与单选分组 |
| [Select](select/README.md) | 业务值与候选选项选择 |
| [Switch](switch/README.md) | 布尔开关与轨道配置 |
| [Tag](tag/README.md) | 展示、关闭与布尔切换标签 |
| [Text](text/README.md) | 文本参数声明与品牌分派 |
| [Card](card/README.md) | 卡片内容、整卡交互与加载状态，移动端已接入 |
| [LoadingIndicator](loading_indicator/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Icon](icon/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Anchor](anchor/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Affix](affix/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Steps](steps/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Avatar](avatar/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Calendar](calendar/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Carousel](carousel/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Collapse](collapse/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Countdown](countdown/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Descriptions](descriptions/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Empty](empty/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Pagination](pagination/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Progress](progress/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Rate](rate/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Segmented](segmented/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Slider](slider/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Skeleton](skeleton/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Statistic](statistic/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Tabs](tabs/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Timeline](timeline/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Alert](alert/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Result](result/README.md) | 参数与 Builder 契约，尚无默认实现 |
| [Backtop](backtop/README.md) | 参数与 Builder 契约，尚无默认实现 |

## 值绑定与生命周期

提供 `value` / `modelValue` 的构造通常要求二选一；`onChanged` 用于接收变化，是否禁用由显式禁用配置决定。`ValueNotifier`、焦点节点和控制器由调用方在 State / Hook 生命周期内持有并按各自契约释放，不要在每次 build 中重新创建。

Radio / Checkbox 的普通构造声明组内业务值，模型放在 Group；`.toggle` 使用独立 bool 模型，不接入祖先 Group 或表单。Group 也支持任意自定义 Flutter 子树，无需登记选项或继承内置组件。表单组合见 [Form](../widgets/form/README.md)。
